#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib.sh"
PLAIN=$(build_bsc plain) || exit 1
ALIAS=$(BS_PATCH_ALIAS=1 build_bsc alias) || exit 1
echo "scratch diff applied for the alias build (bs_emit.erl only):"; diff <(cat "$REPO/compiler/src/bs_emit.erl") "$SCRATCH/alias/src/bs_emit.erl" | grep -c '^>' | sed 's/^/  lines added: /'
mkdir -p "$SCRATCH/cwd"; cd "$SCRATCH/cwd"
for v in plain alias; do
  B=$PLAIN; [ $v = alias ] && B=$ALIAS
  OUT="$SCRATCH/cost-$v"; rm -rf "$OUT"; mkdir -p "$OUT"
  for d in "$EX"/*/; do d=$(basename "$d"); [ "$d" = exemplars -o "$d" = Signalbox ] && continue; "$B" --src-root "$EX" -o "$OUT" "$EX/$d" >/dev/null 2>&1; done
done
echo; echo "== per-module .beam bytes and export count (plain vs alias)"
cat > "$SCRATCH/sz.erl" <<'ERL'
-module(sz).
-export([main/1]).
main([P, A]) ->
    Fs = [filename:basename(F) || F <- filelib:wildcard(P ++ "/*.beam")],
    {TP, TA, EP, EA, FP, FA} = lists:foldl(fun(F, {TP0,TA0,EP0,EA0,FP0,FA0}) ->
        BP = element(2, file:read_file(P ++ "/" ++ F)), BA = element(2, file:read_file(A ++ "/" ++ F)),
        {ok, {_, [{exports, XP}]}} = beam_lib:chunks(P ++ "/" ++ F, [exports]),
        {ok, {_, [{exports, XA}]}} = beam_lib:chunks(A ++ "/" ++ F, [exports]),
        {ok, {_, [{abstract_code, {_, CP}}]}} = beam_lib:chunks(P ++ "/" ++ F, [abstract_code]),
        {ok, {_, [{abstract_code, {_, CA}}]}} = beam_lib:chunks(A ++ "/" ++ F, [abstract_code]),
        FuncsP = length([x || {function,_,_,_,_} <- CP]), FuncsA = length([x || {function,_,_,_,_} <- CA]),
        {TP0+byte_size(BP), TA0+byte_size(BA), EP0+length(XP), EA0+length(XA), FP0+FuncsP, FA0+FuncsA}
      end, {0,0,0,0,0,0}, Fs),
    io:format("modules=~p~nbeam bytes   plain=~p alias=~p (+~.1f%)~nexports      plain=~p alias=~p~nfunctions    plain=~p alias=~p~n",
              [length(Fs), TP, TA, (TA-TP)*100/TP, EP, EA, FP, FA]),
    halt().
ERL
erlc -o "$SCRATCH" "$SCRATCH/sz.erl" && erl -noshell -pa "$SCRATCH" -run sz main "$SCRATCH/cost-plain" "$SCRATCH/cost-alias"
echo; echo "== flat_size of the exports list as term (what module_info(exports) hands a caller), Shop"
for v in plain alias; do erl -noshell -pa "$SCRATCH/cost-$v" -eval "io:format(\"$v Shop exports: ~p entries, flat_size ~p words~n\",[length('Shop':module_info(exports)), erts_debug:flat_size('Shop':module_info(exports))]),halt()."; done
echo; echo "== compile time of the whole example corpus (wall clock, 3 runs each)"
for v in plain alias; do B=$PLAIN; [ $v = alias ] && B=$ALIAS
  for i in 1 2 3; do s=$(date +%s%N); for d in "$EX"/*/; do d=$(basename "$d"); [ "$d" = exemplars -o "$d" = Signalbox ] && continue; "$B" --src-root "$EX" -o "$SCRATCH/t-$v" "$EX/$d" >/dev/null 2>&1; done; e=$(date +%s%N); echo "$v run$i: $(( (e-s)/1000000 )) ms"; done; done
echo; echo "== Elixir against the ALIAS build of Shop"
BS_EBIN="$SCRATCH/cost-alias" elixir "$HERE/probe.exs" 2>&1
echo; echo "== behaviour module Counter (GenServer; callbacks already lowercase via the bs_otp table): exports plain vs alias"
for v in plain alias; do erl -noshell -pa "$SCRATCH/cost-$v" -eval "io:format(\"$v: ~p~n\",[lists:sort([E || {N,_}=E <- 'Counter':module_info(exports), N =/= module_info, N =/= 'bs@type_atoms'])]),halt()."; done
