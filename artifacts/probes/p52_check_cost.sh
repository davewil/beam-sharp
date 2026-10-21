#!/usr/bin/env bash
# Ticket 52: what does the compile-time check cost, per `using`? 100k calls each, ERL_LIBS holding one fake app.
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
mkdir -p $d/libs/mydep-1.0.0/ebin
printf -- '-module(mydep).\n-export([answer/0]).\nanswer() -> 42.\n' > $d/mydep.erl
erlc -o $d/libs/mydep-1.0.0/ebin $d/mydep.erl
printf '{application,mydep,[{vsn,"1.0.0"},{modules,[mydep]},{registered,[]},{applications,[kernel,stdlib]}]}.\n' > $d/libs/mydep-1.0.0/ebin/mydep.app
cat > $d/c.escript <<'X'
#!/usr/bin/env escript
main(_) ->
    T = fun(Name, F) -> {U, _} = timer:tc(fun() -> [F() || _ <- lists:seq(1, 100000)] end),
                        io:format("~-46s ~6.2f us/call~n", [Name, U / 100000]) end,
    T("code:which(present module)",              fun() -> code:which(mydep) end),
    T("code:which(absent module)",               fun() -> code:which(nodep) end),
    T("code:lib_dir(present app) [name check]",  fun() -> code:lib_dir(mydep) end),
    T("code:lib_dir(absent app)",                fun() -> code:lib_dir(nodep) end),
    T("read .app + vsn [version check]",
      fun() -> {ok, [{application, _, Kv}]} = file:consult(filename:join(code:lib_dir(mydep), "ebin/mydep.app")),
               proplists:get_value(vsn, Kv) end).
X
ERL_LIBS=$d/libs escript $d/c.escript
