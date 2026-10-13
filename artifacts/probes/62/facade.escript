#!/usr/bin/env escript
%% Ticket 62 P5: a generated Elixir-facing facade. Module atom 'Elixir.Shop' (what the Elixir token `Shop` resolves to),
%% snake_case functions, each forwarding to the B# module's PascalCase export. Built from the .abstr exports only.
%% usage: OUT=dir facade.escript path/to/Shop.abstr
main([Abstr]) ->
    {ok, Forms} = file:consult(Abstr),
    [Mod] = [M || {attribute, _, module, M} <- Forms],
    Exports = [{N, A} || {attribute, _, export, L} <- Forms, {N, A} <- L, N =/= 'bs@type_atoms'],
    Facade = list_to_atom("Elixir." ++ atom_to_list(Mod)),
    Funs = [begin
                Vs = [{var, 1, list_to_atom("V" ++ integer_to_list(I))} || I <- lists:seq(1, A)],
                {function, 1, snake(N), A, [{clause, 1, Vs, [], [{call, 1, {remote, 1, {atom, 1, Mod}, {atom, 1, N}}, Vs}]}]}
            end || {N, A} <- Exports],
    All = [{attribute, 1, module, Facade}, {attribute, 1, export, [{snake(N), A} || {N, A} <- Exports]}] ++ Funs ++ [{eof, 1}],
    {ok, _, Bin} = compile:forms(All, [binary, return_errors]),
    ok = file:write_file(filename:join(os:getenv("OUT", "."), atom_to_list(Facade) ++ ".beam"), Bin),
    io:format("facade ~s: ~p functions, ~p bytes (B# module beam: ~p bytes)~n",
              [Facade, length(Funs), byte_size(Bin), filelib:file_size(filename:rootname(Abstr) ++ ".beam")]).
snake(N) ->
    S = atom_to_list(N),
    list_to_atom(string:lowercase(re:replace(re:replace(S, "([A-Z]+)([A-Z][a-z])", "\\1_\\2", [global, {return, list}]),
                                              "([a-z0-9])([A-Z])", "\\1_\\2", [global, {return, list}]))).
