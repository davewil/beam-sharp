#!/usr/bin/env escript
%% Run: escript p5_beam_size_and_attr_read.escript [N=1000]
%% Measures: (a) bytes added to a .beam by persisting the restriction as a module attribute,
%% (b) compile time with/without it, (c) time to read it back from N beams (the cost a separately
%% built dependency would pay), (d) that a PER-FUNCTION marker (list attribute) scales with fn count.
main(A) ->
    N = case A of [X|_] -> list_to_integer(X); _ -> 1000 end,
    Mk = fun(I, Extra) ->
        Name = list_to_atom("m" ++ integer_to_list(I)),
        Fns = [{function, 1, list_to_atom("f" ++ integer_to_list(K)), 0,
                [{clause, 1, [], [], [{call, 1, {remote, 1, {atom,1,lists}, {atom,1,reverse}}, [{nil,1}]}]}]} || K <- lists:seq(1, 10)],
        [{attribute,1,module,Name}, {attribute,1,export,[{list_to_atom("f"++integer_to_list(K)),0} || K <- lists:seq(1,10)]}]
          ++ Extra(Name) ++ Fns
    end,
    Comp = fun(Extra) -> timer:tc(fun() -> [begin {ok,_,B} = compile:forms(Mk(I, Extra), [binary]), byte_size(B) end || I <- lists:seq(1, N)] end) end,
    {T0, S0} = Comp(fun(_) -> [] end),
    {T1, S1} = Comp(fun(_) -> [{attribute,1,bs_internal_to,['Shop']}] end),
    {T2, S2} = Comp(fun(_) -> [{attribute,1,bs_internal_fns,[{list_to_atom("f"++integer_to_list(K)),0,['Shop']} || K <- lists:seq(1,10)]}] end),
    P = fun(L) -> lists:sum(L) / length(L) end,
    io:format("N=~p modules x 10 fns~n", [N]),
    io:format("baseline        avg ~.1f bytes/beam, compile ~.1f ms total~n", [P(S0), T0/1000]),
    io:format("module-level attr  +~.1f bytes/beam, compile ~.1f ms total~n", [P(S1)-P(S0), T1/1000]),
    io:format("per-fn attr (10 fns) +~.1f bytes/beam, compile ~.1f ms total~n", [P(S2)-P(S0), T2/1000]),
    %% read-back cost
    Bins = [begin {ok,_,B} = compile:forms(Mk(I, fun(_) -> [{attribute,1,bs_internal_to,['Shop']}] end), [binary]), B end || I <- lists:seq(1, N)],
    {TR, Rs} = timer:tc(fun() -> [begin {ok,{_,[{attributes,As}]}} = beam_lib:chunks(B, [attributes]), proplists:get_value(bs_internal_to, As) end || B <- Bins] end),
    io:format("read attribute back from ~p beams: ~.1f ms (~.1f us each)~n", [N, TR/1000, TR/N]),
    %% assertions
    true = lists:all(fun(R) -> R =:= ['Shop'] end, Rs),
    case P(S1) > P(S0) andalso P(S2) > P(S1) of true -> ok; false -> io:format("FAIL: size ordering unexpected~n"), halt(1) end.
