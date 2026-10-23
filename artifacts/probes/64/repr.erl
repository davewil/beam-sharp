%% Probe 64d — what does an always-tagged option cost on the BEAM, against the bare one?
%% Bare:   option<int> = Int | nothing          (what B# emits today)
%% Tagged: option<int> = {some, Int} | nothing  (what option (c) would emit)
%% Everything printed is measured here, in this run.
-module(repr).
-export([run/0, bare_sum/1, tagged_sum/1, bare_mk/1, tagged_mk/1]).

%% --- the code the two pattern-match shapes compile to (see asm.txt) ---
bare_sum(L)   -> bare_sum(L, 0).
bare_sum([], A) -> A;
bare_sum([nothing | T], A) -> bare_sum(T, A);
bare_sum([V | T], A) -> bare_sum(T, A + V).

tagged_sum(L)   -> tagged_sum(L, 0).
tagged_sum([], A) -> A;
tagged_sum([nothing | T], A) -> tagged_sum(T, A);
tagged_sum([{some, V} | T], A) -> tagged_sum(T, A + V).

bare_mk(N)   -> [case I rem 4 of 0 -> nothing; _ -> I end || I <- lists:seq(1, N)].
tagged_mk(N) -> [case I rem 4 of 0 -> nothing; _ -> {some, I} end || I <- lists:seq(1, N)].

words(T) -> erts_debug:flat_size(T).
bytes(T) -> byte_size(term_to_binary(T)).

time(F, Reps) ->
    F(), F(),                                   % warm-up, JIT
    Ts = [element(1, timer:tc(F)) || _ <- lists:seq(1, Reps)],
    S = lists:sort(Ts),
    {hd(S), lists:nth((Reps + 1) div 2, S), lists:last(S)}.

run() ->
    io:format("OTP ~s, erts ~s, arch ~s~n",
              [erlang:system_info(otp_release), erlang:system_info(version),
               erlang:system_info(system_architecture)]),
    io:format("~n== one value ==~n"),
    [io:format("  ~-28s flat_size=~p words  term_to_binary=~p bytes~n", [D, words(T), bytes(T)])
     || {D, T} <- [{"bare 5", 5}, {"tagged {some,5}", {some, 5}},
                   {"absent (both): nothing", nothing},
                   {"bare big-ish 2^70", 1 bsl 70}, {"tagged {some,2^70}", {some, 1 bsl 70}},
                   {"bare binary <<\"hello\">>", <<"hello">>}, {"tagged {some,<<hello>>}", {some, <<"hello">>}}]],
    N = 1000000,
    B = bare_mk(N), T = tagged_mk(N),
    io:format("~n== list of ~p options, 3/4 present ==~n", [N]),
    io:format("  bare   flat_size=~p words  term_to_binary=~p bytes~n", [words(B), bytes(B)]),
    io:format("  tagged flat_size=~p words  term_to_binary=~p bytes~n", [words(T), bytes(T)]),
    io:format("  delta  ~p words (~.1f%)  ~p bytes (~.1f%)~n",
              [words(T) - words(B), 100 * (words(T) - words(B)) / words(B),
               bytes(T) - bytes(B), 100 * (bytes(T) - bytes(B)) / bytes(B)]),
    io:format("  sum agrees: ~p ~p~n", [bare_sum(B), tagged_sum(T)]),
    Reps = 25,
    {Bmin, Bmed, Bmax} = time(fun() -> bare_sum(B) end, Reps),
    {Tmin, Tmed, Tmax} = time(fun() -> tagged_sum(T) end, Reps),
    io:format("~n== consume (pattern-match every element), ~p reps, usec per 1e6 elements ==~n", [Reps]),
    io:format("  bare    min=~p med=~p max=~p~n", [Bmin, Bmed, Bmax]),
    io:format("  tagged  min=~p med=~p max=~p~n", [Tmin, Tmed, Tmax]),
    {BMmin, BMmed, BMmax} = time(fun() -> bare_mk(N) end, Reps),
    {TMmin, TMmed, TMmax} = time(fun() -> tagged_mk(N) end, Reps),
    io:format("~n== produce ~p options, ~p reps, usec ==~n", [N, Reps]),
    io:format("  bare    min=~p med=~p max=~p~n", [BMmin, BMmed, BMmax]),
    io:format("  tagged  min=~p med=~p max=~p~n", [TMmin, TMmed, TMmax]),
    io:format("~nResolution note: timings on a shared cloud VM; read spread (min..max) before median.~n"),
    ok.
