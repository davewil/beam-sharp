#!/usr/bin/env bash
# Patches the SCRATCH copy (arg 1) of bs_emit.erl so every public function also exports a snake_case forwarder.
# Rule used: the acronym-aware rule S2 from probe 04. NOT the repo; this is the "compiler delta" being costed.
D="$1"; F="$D/src/bs_emit.erl"
python3 -I - "$F" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
old="""     {attribute, ?A, export, [{name(F, Behaviours), A} || {F, A} <- Exports]
                             ++ [{type_atoms_name(), 0}]}]"""
new="""     {attribute, ?A, export, [{name(F, Behaviours), A} || {F, A} <- Exports]
                             ++ [{AN, A} || {AN, A, _} <- alias_list(Exports, Behaviours)]
                             ++ [{type_atoms_name(), 0}]}]"""
assert old in s; s=s.replace(old,new)
old2="    ++ validator_forms(Validators)\n    ++ reserved_forms(Fns)."
new2="    ++ validator_forms(Validators)\n    ++ alias_forms(alias_list(Exports, Behaviours))\n    ++ reserved_forms(Fns)."
assert old2 in s; s=s.replace(old2,new2)
s+='''

%%% ---- ticket 62 scratch patch: snake_case forwarders ------------------------
%%% One forwarder per exported function whose derived name differs from its
%%% emitted name and does not collide with an existing export of that arity.
alias_list(Exports, Behaviours) ->
    Taken = sets:from_list([{name(F, Behaviours), A} || {F, A} <- Exports]),
    lists:usort([{AN, A, name(F, Behaviours)}
                 || {F, A} <- Exports,
                    AN <- [snake(atom_to_list(element(2, F)))],
                    AN =/= name(F, Behaviours),
                    not sets:is_element({AN, A}, Taken)]).

alias_forms(Aliases) ->
    [{function, ?A, AN, A,
      [{clause, ?A, Vs, [], [{call, ?A, {atom, ?A, Target}, Vs}]}]}
     || {AN, A, Target} <- Aliases,
        Vs <- [[{var, ?A, list_to_atom("V" ++ integer_to_list(I))} || I <- lists:seq(1, A)]]].

snake(S) -> list_to_atom(snake(S, [], $a)).
snake([], Acc, _) -> lists:reverse(Acc);
snake([C | T], Acc, Prev) ->
    Up = C >= $A andalso C =< $Z,
    Next = case T of [N | _] -> N; [] -> $A end,
    PrevLow = (Prev >= $a andalso Prev =< $z) orelse (Prev >= $0 andalso Prev =< $9),
    PrevUp = Prev >= $A andalso Prev =< $Z,
    NextLow = Next >= $a andalso Next =< $z,
    Sep = Up andalso Acc =/= [] andalso (PrevLow orelse (PrevUp andalso NextLow)),
    L = case Up of true -> C + 32; false -> C end,
    snake(T, [L | case Sep of true -> [$_ | Acc]; false -> Acc end], C).
'''
open(p,'w').write(s)
PY
