#!/usr/bin/env bash
# PROBE 60e -- ticket 60 (ENG-242). OTP 28 `xref` (lib/tools-4.1.4/src/xref.erl). Claims:
#   X1. xref IS a caller check over static edges: {module_use, callee} lists modules with a
#       direct call or `fun callee:f/A`.
#   X2. A module that reaches callee only through apply/3 with a variable module (caller_dyn) is
#       ABSENT from {module_use, callee}; xref reports it only as an unresolved call
#       ('$M_EXPR'), which xref.erl:53 itself says "make module data incomplete".
#   X3. CONTROL: a module that calls callee directly (caller_bad) IS reported, so the probe can go red.
#   X4. `-ignore_xref` is not in OTP 28's tools (grep): the silencing convention lives in rebar3.
set -uo pipefail
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
cat > callee.erl <<'E'
-module(callee).
-export([exported/0]).
exported() -> ok.
E
cat > caller_ok.erl <<'E'
-module(caller_ok). -export([f/0]).
f() -> callee:exported().
E
cat > caller_bad.erl <<'E'
-module(caller_bad). -export([f/0]).
f() -> F = fun callee:exported/0, F().
E
cat > caller_dyn.erl <<'E'
-module(caller_dyn). -export([f/1]).
f(M) -> apply(M, exported, []).
E
erlc +debug_info *.erl || exit 2
cat > run.escript <<'E'
#!/usr/bin/env escript
main(_) ->
    {ok, _} = xref:start(s),
    xref:set_default(s, [{verbose,false},{warnings,false}]),
    {ok, _} = xref:add_directory(s, "."),
    {ok, Use} = xref:analyze(s, {module_use, callee}),
    io:format("modules using callee (static)   : ~p~n", [lists:sort(Use)]),
    {ok, UC} = xref:q(s, "UC"),
    io:format("unresolved calls (UC)           : ~p~n", [lists:sort(UC)]),
    Allowed = [caller_ok],
    io:format("policy 'only caller_ok may call': violators seen = ~p~n", [lists:sort(Use) -- Allowed]),
    io:format("   caller_dyn is NOT in that list although caller_dyn:f(callee) returns ~p~n",
              [caller_dyn:f(callee)]),
    xref:stop(s).
E
escript run.escript
echo "--- X4 grep for ignore_xref in OTP 28 lib sources"
n=$(grep -rl "ignore_xref" "$(dirname "$(dirname "$(command -v erl)")")"/lib/erlang/lib/*/src 2>/dev/null | wc -l); echo "files mentioning ignore_xref: $n"
c=$(grep -rl "Unresolved calls" "$(dirname "$(dirname "$(command -v erl)")")"/lib/erlang/lib/*/src 2>/dev/null | wc -l); echo "CONTROL same grep for 'Unresolved calls': $c file(s)"
