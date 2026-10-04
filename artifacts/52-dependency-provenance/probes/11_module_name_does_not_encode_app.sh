#!/bin/sh
# Could the compiler DERIVE the application from the module atom, so the source need not say it?
# Counted over every installed .app: Elixir 1.14's six apps and all OTP 28 apps.
. "$(dirname "$0")/env.sh"
cat > $W/p11.escript <<'E'
#!/usr/bin/env escript
main(_) ->
    ElixirApps = filelib:wildcard("/usr/lib/elixir/lib/*/ebin/*.app"),
    OtpApps = filelib:wildcard("/opt/otp28/lib/erlang/lib/*/ebin/*.app"),
    {E, Ex} = count(ElixirApps, fun ex_guess/2),
    {O, Ox} = count(OtpApps, fun erl_guess/2),
    io:format("Elixir 1.14 installed apps: ~p apps, ~p modules; first-segment guess right for ~p (~.1f%)~n",
              [length(ElixirApps), tot(E), hits(E), pct(E)]),
    io:format("  wrong, per app: ~p~n", [[{A, N} || {A, N} <- Ex]]),
    io:format("  the guess maps Elixir.String -> ~p, Elixir.Enum -> ~p; both live in app elixir~n", [ex_guess(x, 'Elixir.String'), ex_guess(x, 'Elixir.Enum')]),
    io:format("OTP 28 apps: ~p apps, ~p modules; module==app or app_ prefix right for ~p (~.1f%)~n",
              [length(OtpApps), tot(O), hits(O), pct(O)]),
    io:format("  apps where the guess fails for >=1 module (count): ~p of ~p~n", [length(Ox), length(O)]),
    io:format("  worst: ~p~n", [lists:sublist(lists:reverse(lists:keysort(2, Ox)), 6)]).
mods(App) -> {ok, [{application, _, P}]} = file:consult(App), proplists:get_value(modules, P).
count(Apps, Guess) ->
    Per = [begin A = list_to_atom(filename:basename(F, ".app")),
                 Ms = mods(F),
                 Bad = [M || M <- Ms, Guess(A, M) =/= A],
                 {A, length(Ms), length(Bad)} end || F <- Apps],
    {Per, [{A, B} || {A, _, B} <- Per, B > 0]}.
tot(Per) -> lists:sum([N || {_, N, _} <- Per]).
hits(Per) -> tot(Per) - lists:sum([B || {_, _, B} <- Per]).
pct(Per) -> 100 * hits(Per) / tot(Per).
ex_guess(_App, M) ->
    case atom_to_list(M) of
        "Elixir." ++ Rest -> [First | _] = string:split(Rest, "."), list_to_atom(snake(First));
        _ -> none      % an Erlang-named module inside an Elixir app (elixir_utils, ...)
    end.
snake(S) -> string:lowercase(re:replace(S, "([a-z0-9])([A-Z])", "\\1_\\2", [global, {return, list}])).
erl_guess(App, M) ->
    S = atom_to_list(M), A = atom_to_list(App),
    case S =:= A orelse lists:prefix(A ++ "_", S) of true -> App; false -> none end.
E
escript $W/p11.escript
