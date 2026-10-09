#!/usr/bin/env escript
%% P11: how much does a bare application NAME say? Transitive closure of `applications` read from installed .app files.
%% A source that declares one name (`in :ssl`) names 1 node; what actually has to be present is the closure.
%% Control: `lists` (module in stdlib) -> closure of stdlib is {kernel, stdlib} only.
main(_) ->
    code:add_pathz("/usr/lib/elixir/lib/elixir/ebin"),
    [code:add_pathz(D) || D <- filelib:wildcard("/usr/lib/elixir/lib/*/ebin")],
    [show(A) || A <- [stdlib, ssl, inets, elixir, logger, mix]].
show(A) ->
    C = closure([A], []),
    io:format("~-8w declares 1 name; closure = ~p apps: ~w~n", [A, length(C), lists:sort(C)]).
closure([], Seen) -> Seen;
closure([A | R], Seen) ->
    case lists:member(A, Seen) of
        true -> closure(R, Seen);
        false ->
            Deps = case code:where_is_file(atom_to_list(A) ++ ".app") of
                non_existing -> [];
                F -> {ok, [{application, A, P}]} = file:consult(F), proplists:get_value(applications, P, [])
            end,
            closure(Deps ++ R, [A | Seen])
    end.
