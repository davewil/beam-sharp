#!/usr/bin/env escript
%% usage: 05_alias_cost.escript DIR_WITH_.abstr_FILES
%% For every bsc-emitted module, three beams built from the SAME abstract forms with the SAME options:
%%   base  = as emitted
%%   wrap  = base + one snake_case alias per exported author function, alias = tiny wrapper calling 'PascalName'
%%   copy  = base + one snake_case alias per export, alias = full copy of the function (clauses + spec), upper bound
%% Options mirror bsc.erl:843 (debug_info). The alias derivation here is Elixir's Macro.underscore-style (see 06_name_table); it only affects atom lengths.
-mode(compile).

main([Dir, "emit", Out]) ->
    %% write the wrapper-alias beams so an Elixir process can call them (06)
    [begin
         {ok, Forms} = file:consult(F),
         Ex = lists:append([L || {attribute, _, export, L} <- Forms]),
         Au = [E || {N, _} = E <- Ex, not lists:prefix("bs@", atom_to_list(N))],
         [{attribute, _, module, M}] = [A || A = {attribute, _, module, _} <- Forms],
         ok = file:write_file(filename:join(Out, atom_to_list(M) ++ ".beam"), comp(add_aliases(Forms, Au, wrap)))
     end || F <- filelib:wildcard(filename:join(Dir, "*.abstr"))],
    ok;
main([Dir]) ->
    Files = lists:sort(filelib:wildcard(filename:join(Dir, "*.abstr"))),
    Rs = [R || F <- Files, R <- [row(F)], R =/= skip],
    io:format("~-24s ~4s ~7s ~7s ~7s ~5s ~5s ~7s ~7s~n",
              ["module", "fns", "base_B", "wrap_B", "copy_B", "exp0", "exp1", "ext0", "ext1"]),
    [io:format("~-24s ~4w ~7w ~7w ~7w ~5w ~5w ~7w ~7w~n",
               [maps:get(mod, R), maps:get(fns, R), maps:get(base, R), maps:get(wrap, R), maps:get(copy, R),
                maps:get(exp0, R), maps:get(exp1, R), maps:get(ext0, R), maps:get(ext1, R)]) || R <- Rs],
    S = fun(K) -> lists:sum([maps:get(K, R) || R <- Rs]) end,
    io:format("TOTAL ~w modules, ~w exported fns~n", [length(Rs), S(fns)]),
    io:format("  beam bytes: base ~w | wrapper ~w (+~.1f%) | full copy ~w (+~.1f%)~n",
              [S(base), S(wrap), pct(S(wrap), S(base)), S(copy), pct(S(copy), S(base))]),
    io:format("  export entries ~w -> ~w ; external_size(module_info(exports)) ~w -> ~w bytes (+~.1f%)~n",
              [S(exp0), S(exp1), S(ext0), S(ext1), pct(S(ext1), S(ext0))]),
    io:format("  atom-table entries (beam_lib atoms chunk): ~w -> ~w~n", [S(at0), S(at1)]),
    %% load cost on the biggest module
    {_, Big} = lists:last(lists:sort([{maps:get(fns, R), R} || R <- Rs])),
    io:format("~nload cost on ~s (~w fns), 300 x (purge+load_binary), microseconds min/median/max:~n",
              [maps:get(mod, Big), maps:get(fns, Big)]),
    [begin
         Ts = lists:sort([load_us(Mod, Bin) || _ <- lists:seq(1, 300)]),
         io:format("  ~-5s ~w / ~w / ~w~n", [Name, hd(Ts), lists:nth(150, Ts), lists:last(Ts)])
     end || {Name, Mod, Bin} <- [{"base", maps:get(modname, Big), maps:get(base_bin, Big)},
                                 {"wrap", maps:get(modname, Big), maps:get(wrap_bin, Big)},
                                 {"copy", maps:get(modname, Big), maps:get(copy_bin, Big)}]],
    ok.

pct(A, B) -> (A - B) * 100 / B.

load_us(Mod, Bin) ->
    code:purge(Mod), code:delete(Mod), code:purge(Mod),
    {T, {module, Mod}} = timer:tc(code, load_binary, [Mod, "x.beam", Bin]),
    T.

row(F) ->
    {ok, Forms} = file:consult(F),
    [{attribute, _, module, Mod}] = [A || A = {attribute, _, module, _} <- Forms],
    Exports = lists:append([L || {attribute, _, export, L} <- Forms]),
    Author = [E || {N, _} = E <- Exports, not lists:prefix("bs@", atom_to_list(N))],
    case Author of
        [] -> skip;
        _ ->
            Base = comp(Forms),
            Wrap = comp(add_aliases(Forms, Author, wrap)),
            Copy = comp(add_aliases(Forms, Author, copy)),
            #{mod := _} = #{mod => Mod},
            Ex0 = exports_of(Mod, Base), Ex1 = exports_of(Mod, Wrap),
            #{mod => Mod, modname => Mod, fns => length(Author),
              base => byte_size(Base), wrap => byte_size(Wrap), copy => byte_size(Copy),
              base_bin => Base, wrap_bin => Wrap, copy_bin => Copy,
              exp0 => length(Ex0), exp1 => length(Ex1),
              ext0 => erlang:external_size(Ex0), ext1 => erlang:external_size(Ex1),
              at0 => atoms(Base), at1 => atoms(Wrap)}
    end.

comp(Forms) ->
    {ok, _, Bin} = compile:forms(Forms, [binary, debug_info, return_errors, no_spawn_compiler_process]),
    Bin.

exports_of(Mod, Bin) ->
    code:purge(Mod), code:delete(Mod), code:purge(Mod),
    {module, Mod} = code:load_binary(Mod, "x.beam", Bin),
    Mod:module_info(exports).

atoms(Bin) ->
    {ok, {_, [{atoms, As}]}} = beam_lib:chunks(Bin, [atoms]), length(As).

%% Elixir Macro.underscore, as a pure function (verified against Elixir in 06_name_table.exs)
snake(Atom) ->
    S = atom_to_list(Atom),
    list_to_atom(under(S, none)).
under([], _) -> [];
under([C | T], Prev) when C >= $A, C =< $Z ->
    Next = case T of [N | _] -> N; [] -> $\s end,
    Lead = case Prev of
               none -> [];
               lower -> "_";
               upper -> case (Next >= $a andalso Next =< $z) of true -> "_"; false -> [] end;
               other -> []
           end,
    Lead ++ [C + 32] ++ under(T, upper);
under([C | T], _) when C >= $a, C =< $z -> [C | under(T, lower)];
under([C | T], _) -> [C | under(T, other)].

add_aliases(Forms, Author, Mode) ->
    Taken = [N || {N, _} <- Author],
    Als = [{N, A, snake(N)} || {N, A} <- Author, snake(N) =/= N, not lists:member(snake(N), Taken)],
    Seen = lists:usort([{S, A} || {_, A, S} <- Als]),
    Fns = [F || F = {function, _, _, _, _} <- Forms],
    Specs = [S || S = {attribute, _, spec, _} <- Forms],
    NewFns = lists:append([mk(Mode, N, A, S, Fns) || {S, A} <- Seen, {N, A2, S2} <- Als, S2 =:= S, A2 =:= A, true]),
    lists:append([ [case F of
                        {attribute, L, export, E} -> {attribute, L, export, E ++ [{S, A} || {S, A} <- Seen]};
                        _ -> F
                    end] || F <- Forms ]) ++ NewFns ++ copy_specs(Mode, Als, Specs).

mk(wrap, N, A, S, _Fns) ->
    Vs = [{var, 0, list_to_atom("A" ++ integer_to_list(I))} || I <- lists:seq(1, A)],
    [{function, 0, S, A, [{clause, 0, Vs, [], [{call, 0, {atom, 0, N}, Vs}]}]}];
mk(copy, N, A, S, Fns) ->
    [{function, L, S, A, Cl} || {function, L, N0, A0, Cl} <- Fns, N0 =:= N, A0 =:= A].

copy_specs(wrap, _, _) -> [];
copy_specs(copy, Als, Specs) ->
    [{attribute, L, spec, {{S, A}, T}}
     || {N, A, S} <- Als, {attribute, L, spec, {{N0, A0}, T}} <- Specs, N0 =:= N, A0 =:= A].
