#!/usr/bin/env bash
# CLAIM (neighbour survey + the "compile-time only" half of the ticket): Erlang's closest
# tool, xref, is a post-hoc ANALYSIS (it reports who calls whom), not a gate on export, and
# it cannot see calls whose module or function is a variable (xref.erl lines 40-55).
# REFUTED IF: xref lists `sneaky` (variable-module call) among the users of `callee`.
. "$(dirname "$0")/lib.sh"
D="$WORK/p06"; rm -rf "${D:?}"; mkdir -p "$D"
erlc +debug_info -o "$D" "$HERE"/erl/callee.erl "$HERE"/erl/stranger.erl "$HERE"/erl/sneaky.erl "$HERE"/erl/literal.erl || exit 1
XREF=$(dirname "$(dirname "$(command -v erl)")")/lib/erlang/lib/tools-4.1.4/src/xref.erl
echo "--- the documentation of the limitation (installed source, $XREF)"
sed -n 40,55p "$XREF" | nl -ba -v40
cd "$D" || exit 1
erl -noshell -eval '
  {ok,_} = xref:start(s),
  xref:set_default(s, [{verbose,false},{warnings,false}]),
  {ok,_} = xref:add_directory(s, "'"$D"'"),
  {ok, Users} = xref:analyze(s, {module_use, callee}),
  io:format("modules that use callee (xref {module_use, callee}): ~p~n", [Users]),
  {ok, UC} = xref:q(s, "UC"),
  io:format("unresolved calls (xref query UC): ~p~n", [UC]),
  {ok, Cs} = xref:q(s, "E | sneaky"),
  io:format("edges FROM sneaky: ~p~n", [Cs]),
  case lists:member(sneaky, Users) of true -> halt(3); false -> ok end,
  case lists:member(stranger, Users) andalso lists:member(literal, Users) of true -> halt(0); false -> halt(4) end.' ; rc=$?
echo "exit=$rc (0 = sneaky absent, stranger+literal present)"
verdict "xref-cannot-see-variable-module-calls" $rc
echo
echo "--- OTP's own convention for 'application-internal': documentation hiding, not enforcement"
L=$(dirname "$(dirname "$(command -v erl)")")/lib/erlang/lib
printf 'kernel src modules: %s total, %s carry -moduledoc false\n' "$(ls "$L"/kernel-*/src/*.erl | wc -l)" "$(grep -l '^-moduledoc false' "$L"/kernel-*/src/*.erl | wc -l)"
echo "stdlib erl_internal.erl lines 22-25 (a module that describes itself as internal):"
sed -n 22,25p "$L"/stdlib-*/src/erl_internal.erl
echo "and any user module can call it (no enforcement):"
erl -noshell -eval 'io:format("erl_internal:bif(abs,1) = ~p~n",[erl_internal:bif(abs,1)])' -s init stop
echo "an exported function whose NAME says internal, called across modules in kernel (os.erl calling logger):"
grep -n 'logger:internal_init_logger\|os:internal_init_cmd_shell' "$L"/kernel-*/src/kernel.erl | head -3
grep -n -B1 -A1 '^internal_init_logger' "$L"/kernel-*/src/logger.erl | head -6
