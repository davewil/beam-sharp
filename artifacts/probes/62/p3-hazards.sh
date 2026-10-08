#!/usr/bin/env bash
# Probe 3: derivation-rule hazards. Synthetic names a B# author can write (uident = [A-Z][a-zA-Z0-9_]*, bs_lexer.xrl:150)
# run through three candidate rules; then reserved-word / BIF aliases are tried in real Erlang compile + Elixir parse.
. "$(dirname "$0")/common.sh"
cp $(dirname "$0")/p2-rules.erl $SCR/p3.erl 2>/dev/null
cat > $SCR/p3.erl <<'ERL'
-module(p3).
-export([main/0]).
r1(A) -> L = atom_to_list(A), list_to_atom(lists:flatten(r1s(L, true))).
r1s([], _) -> [];
r1s([C|T], First) when C >= $A, C =< $Z -> [[$_ || not First], C + 32 | r1s(T, false)];
r1s([C|T], _) -> [C | r1s(T, false)].
r2(A) -> list_to_atom(r2s(atom_to_list(A), [], undefined)).
r2s([], Acc, _) -> lists:reverse(Acc);
r2s([C|T], Acc, Prev) ->
    Up = C >= $A andalso C =< $Z,
    Nxt = case T of [N|_] -> N; [] -> $\s end,
    NxtLow = Nxt >= $a andalso Nxt =< $z,
    PrevLow = Prev =/= undefined andalso ((Prev >= $a andalso Prev =< $z) orelse (Prev >= $0 andalso Prev =< $9)),
    PrevUp = Prev =/= undefined andalso (Prev >= $A andalso Prev =< $Z),
    Sep = Up andalso (PrevLow orelse (PrevUp andalso NxtLow)),
    Low = if Up -> C + 32; true -> C end,
    r2s(T, [Low | (if Sep -> [$_|Acc]; true -> Acc end)], C).
r3(A) -> [C|T] = atom_to_list(A), list_to_atom([string:to_lower(C)|T]) .  % first-letter downcase only
names() -> ['New','HTTPServer','GetXML','GetXml','Totals2','Totals_2','ParseURL','ParseUrl','IOList','ToJSON','ToJson','A','AB','Ab','OAuth','X509Cert','Get_Xml','Foo','FOO','NameOf','Length','Apply','Spawn','Node','Self','Send','Exit','If','End','And','Not','Rem','Div','Do','Fn','Nil','True','When','In','Case','Try','Receive','After','Band','OrElse', 'Init','HandleCall','Handle_Call','XY','X_y'].
main() ->
    io:format("~-14s ~-16s ~-16s ~-14s~n", ["B# name","R1 insert_","R2 acronym-aware","R3 first-lower"]),
    [io:format("~-14s ~-16s ~-16s ~-14s~n", [N, r1(N), r2(N), r3(N)]) || N <- names()],
    [begin
       Groups = lists:foldl(fun(N, Acc) -> maps:update_with(R(N), fun(L) -> [N|L] end, [N], Acc) end, #{}, names()),
       io:format("~ncollisions under ~s (distinct B# names -> same alias): ~p~n", [Tag, [{K, lists:sort(V)} || {K, V} <- maps:to_list(Groups), length(V) > 1]])
     end || {Tag, R} <- [{"R1", fun r1/1}, {"R2", fun r2/1}, {"R3", fun r3/1}]],
    %% control: the rules must at least differ on something, else the table proves nothing
    io:format("~ncontrol: names where R1 =/= R2: ~p~n", [[N || N <- names(), r1(N) =/= r2(N)]]).
ERL
(cd $SCR && erlc p3.erl) && erl -noshell -pa $SCR -eval 'p3:main(), halt().'
echo; echo "== reserved words / BIFs as alias names: does Erlang accept them as local DEFINITIONS (export, no local call)? =="
cat > $SCR/bifs.erl <<'ERL'
-module(bifs).
-export([length/1, now/0, apply/2, spawn/1, node/0, self/0, send/2, exit/1, size/1, 'if'/1, 'end'/1, 'and'/1, 'not'/1, 'rem'/1, 'div'/1, 'fun'/1, 'case'/1, 'band'/1, 'receive'/1, 'try'/1, 'after'/1, 'when'/1, 'of'/1, 'catch'/1, 'begin'/1]).
-export(['Length'/1, 'Now'/0, 'Apply'/2, 'Spawn'/1, 'Node'/0, 'Self'/0, 'Send'/2, 'Exit'/1, 'Size'/1]).
'Length'(X) -> {pascal_length, X}. 'Now'() -> now_p. 'Apply'(F, A) -> {F, A}. 'Spawn'(X) -> X. 'Node'() -> n. 'Self'() -> s. 'Send'(A, B) -> {A, B}. 'Exit'(X) -> X. 'Size'(X) -> X.
length(X) -> 'Length'(X).  now() -> 'Now'().  apply(F, A) -> 'Apply'(F, A).  spawn(X) -> 'Spawn'(X).  node() -> 'Node'().
self() -> 'Self'().  send(A, B) -> 'Send'(A, B).  exit(X) -> 'Exit'(X). size(X) -> 'Size'(X).
'if'(X) -> X. 'end'(X) -> X. 'and'(X) -> X. 'not'(X) -> X. 'rem'(X) -> X. 'div'(X) -> X. 'fun'(X) -> X. 'case'(X) -> X. 'band'(X) -> X. 'receive'(X) -> X. 'try'(X) -> X. 'after'(X) -> X. 'when'(X) -> X. 'of'(X) -> X. 'catch'(X) -> X. 'begin'(X) -> X.
ERL
(cd $SCR && erlc +debug_info bifs.erl 2>&1 | head -20; echo "erlc exit: ${PIPESTATUS[0]}")
echo "-- CONTROL: same file but one alias CALLS a BIF-named local function unqualified (must be refused) --"
cat > $SCR/bifs2.erl <<'ERL'
-module(bifs2).
-export([length/1, f/1]).
length(X) -> {mine, X}.
f(X) -> length(X).
ERL
(cd $SCR && erlc bifs2.erl 2>&1 | head -6)
echo; echo "== Elixir: can each alias spelling be written with dot syntax? (parse; control new/1 parses) =="
cat > $SCR/p3.exs <<'EXS'
for n <- ~w(new length now apply spawn node self send exit size if end and not rem div fn nil true false when in case try receive after band do else catch rescue or xor of begin cond unless import) do
  s = ":Shop." <> n <> "(1)"
  r = case Code.string_to_quoted(s) do {:ok, _} -> :parses; {:error, {_, m, _}} -> {:SYNTAX_ERROR, m |> to_string |> String.split(". ") |> hd} end
  IO.puts(String.pad_trailing(s, 22) <> inspect(r))
end
EXS
elixir $SCR/p3.exs 2>&1
echo "== Elixir: a CALL to a BIF-named export: :Shop.length([1]) vs Kernel.length ambiguity? (needs module on disk: bifs) =="
cat > $SCR/p3b.exs <<'EXS'
Code.prepend_path(System.get_env("SCR"))
IO.inspect(:bifs.length([1,2,3]), label: ":bifs.length([1,2,3]) (alias, Elixir dot syntax)")
IO.inspect(Kernel.length([1,2,3]), label: "Kernel.length (control)")
EXS
echo "(control: Erlang-side result of the same call) $(erl -noshell -pa $SCR -eval 'io:format("~p",[bifs:length([1])]),halt().')"; SCR=$SCR elixir $SCR/p3b.exs 2>&1 | head -5
echo "== Erlang: unquoted call of a reserved-word alias (must be syntax error); control new =="
for s in "f() -> shop:and(1)." "f() -> shop:'and'(1)." "f() -> shop:new(1)." "f() -> shop:'New'(1)."; do
  erl -noshell -eval "{ok,T,_}=erl_scan:string(\"$s\"), R=erl_parse:parse_form(T), io:format(\"~-28s ~p~n\",[\"$s\", element(1,R)]), halt()."
done
