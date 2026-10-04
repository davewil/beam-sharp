#!/bin/bash
# Probe 13 (c, e): what would each scope change do to the REAL corpus (compiler/examples, 74 .bs files)?
# Compile every module directory with each compiler variant; count, over the emitted Erlang, the
# functions whose guard text changed vs base, the guard tests added/removed, and the Code-chunk byte delta
# (which is net of whatever beam_ssa_type elides).
cd "$(dirname "$0")"; . ./lib.sh
EX=/home/user/beam-sharp/compiler/examples
W=$(mktemp -d)
DIRS=$(cd $EX && find . -name '*.bs' -printf '%h\n' | sed 's|^\./||' | sort -u | grep -v '^exemplars')   # the exemplars are aspirational programs and do not compile (checked: 7/7 fail on every variant)
echo "module dirs: $(echo "$DIRS" | wc -l)"
for v in base narrow wide; do
  mkdir -p $W/$v; ok=0; bad=0
  for d in $DIRS; do
    mkdir -p $W/$v/$d
    if /tmp/p59/bin/bsc-$v -o $W/$v/$d --src-root $EX $EX/$d >/dev/null 2>$W/$v/$d/err; then ok=$((ok+1)); else bad=$((bad+1)); echo "  $v: $d failed: $(head -c 150 $W/$v/$d/err)"; fi
  done
  for d in $(cd /home/user/beam-sharp && find aoc -name '*.bs' -printf '%h\n' | sort -u); do mkdir -p $W/$v/$d; /tmp/p59/bin/bsc-$v -o $W/$v/$d /home/user/beam-sharp/$d >/dev/null 2>&1 && ok=$((ok+1)) || { bad=$((bad+1)); echo "  $v: $d failed"; }; done   # + the aoc programs
  echo "$v: compiled $ok dirs, $bad failed"
done
cat > $W/cmp.erl <<'ERL'
-module(cmp).
-export([main/1]).
%% for every beam in base, find the same in V; compare printed functions and Code size
main([W, V]) ->
    Beams = [B || {_, B} <- lists:ukeysort(1, [{filename:basename(B0), B0} || B0 <- filelib:wildcard(W ++ "/base/**/*.beam")])],   %% one per module: a nested dir is compiled again as part of its parent
    Rows = [row(B, W, V) || B <- Beams],
    Rows1 = [R || R <- Rows, R =/= skip],
    Changed = [R || {_, _, D, _, _} = R <- Rows1, D =/= 0 orelse element(4, R) =/= []],
    TotBase = lists:sum([Bb || {_, Bb, _, _, _} <- Rows1]),
    TotDelta = lists:sum([D || {_, _, D, _, _} <- Rows1]),
    Fns = lists:sum([length(Fs) || {_, _, _, Fs, _} <- Rows1]),
    Tests = lists:sum([T || {_, _, _, _, T} <- Rows1]),
    io:format("~s vs base: ~w modules, ~w with a changed function, ~w functions changed, net guard-text tests ~s~w, Code bytes total ~w (delta ~s~w, ~.2f%)~n",
        [V, length(Rows1), length(Changed), Fns, sgn(Tests), Tests, TotBase, sgn(TotDelta), TotDelta, 100 * TotDelta / max(1, TotBase)]),
    [io:format("    ~-34s Code ~s~w B, functions: ~p~n", [filename:basename(M), sgn(D), D, Fs]) || {M, _, D, Fs, _} <- Changed],
    halt().
sgn(X) when X > 0 -> "+"; sgn(_) -> "".
row(B, _W, V) ->
    B2 = re:replace(B, "/base/", "/" ++ V ++ "/", [{return, list}]),
    case filelib:is_file(B2) of
        false -> skip;
        true ->
            {Fa, Ca} = info(B), {Fb, Cb} = info(B2),
            Changed = [N || {N, T} <- Fa, lists:keyfind(N, 1, Fb) =/= {N, T}],
            Tests = lists:sum([cnt(T) || {_, T} <- Fb]) - lists:sum([cnt(T) || {_, T} <- Fa]),
            {B, Ca, Cb - Ca, Changed, Tests}
    end.
cnt(T) -> length(re:split(T, "is_integer|is_float|map_get\\('Kind'", [{return, list}])) - 1.
info(B) ->
    {ok, {_, [{abstract_code, {_, F}}]}} = beam_lib:chunks(B, [abstract_code]),
    {ok, _, Cs} = beam_lib:all_chunks(B), {"Code", Code} = lists:keyfind("Code", 1, Cs),
    {[{{N, A}, lists:flatten(erl_pp:function(X))} || X = {function, _, N, A, _} <- F], byte_size(Code)}.
ERL
erlc -o $W $W/cmp.erl
for v in narrow wide; do erl -noshell -pa $W -eval "cmp:main([\"$W\",\"$v\"])"; done
