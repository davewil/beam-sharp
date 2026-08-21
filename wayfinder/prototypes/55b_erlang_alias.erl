#!/usr/bin/env escript
%%% 55b — Erlang: the target language, and the one whose node beam-sharp already
%%% emits. `p_alias` in bs_emit.erl IS this construct.
%%%
%%% Measured:
%%%   1. Where does the binder go?  `F = #frame{...}` — binder on the LEFT of `=`.
%%%   2. Does the RIGHT-hand form work too — `#frame{...} = F`? (In Erlang `=` in
%%%      a pattern is symmetric-looking but is it?)
%%%   3. Is the record name mandatory in the pattern? (Erlang records are sugar
%%%      over tagged tuples, so there is no bare record pattern.)
%%%   4. Does the alias survive into a function head, not just a case?
%%%
%%% Run:  escript 55b_erlang_alias.erl

-record(frame, {type, channel, payload}).

%% (1) binder on the LEFT, in a case.
left_binder(X) ->
    case X of
        F = #frame{type = method} -> {method, F#frame.channel};
        F = #frame{type = header} -> {header, F#frame.channel};
        _ -> other
    end.

%% (2) binder on the RIGHT of the same `=`.
right_binder(X) ->
    case X of
        #frame{type = body} = F -> {body, F#frame.channel};
        _ -> other
    end.

%% (4) the same alias in a FUNCTION HEAD, which is beam-sharp's clause position.
head_alias(F = #frame{type = heartbeat}, Rest) -> {heartbeat, F#frame.channel, Rest};
head_alias(_, Rest) -> {other, Rest}.

%% The nested case exemplar 25c actually writes: an aliased record inside a tuple.
nested(X) ->
    case X of
        {F = #frame{type = method}, Rest} -> {nested_method, F#frame.channel, Rest};
        _ -> other
    end.

main(_) ->
    M = #frame{type = method,    channel = 7,  payload = <<"hello">>},
    H = #frame{type = header,    channel = 9,  payload = <<>>},
    B = #frame{type = body,      channel = 11, payload = <<"x">>},
    Hb = #frame{type = heartbeat, channel = 0, payload = <<>>},

    io:format("1 binder on the LEFT      : ~p~n", [left_binder(M)]),
    io:format("1 binder on the LEFT      : ~p~n", [left_binder(H)]),
    io:format("2 binder on the RIGHT     : ~p~n", [right_binder(B)]),
    io:format("4 alias in a FUNCTION HEAD: ~p~n", [head_alias(Hb, rest)]),
    io:format("  nested in a tuple (25c) : ~p~n", [nested({M, rest})]),
    ok.
