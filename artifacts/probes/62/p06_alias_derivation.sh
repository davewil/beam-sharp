#!/usr/bin/env bash
# P06: the alias-export compiler delta, run for real (compiler-alias.patch, experimental copy only).
# Part A: what `BS_ALIAS=thin` emits for names that stress a derivation rule, listed from the beam export table.
# Part B: collisions and name clashes -- what the PATCH (rule S) does, and what the BASELINE compiler does with the same source.
# CLAIMS: (1) a mechanical rule exists for every B# name (REFUTED IF a name makes the patch crash for a reason other than a collision);
#         (2) collisions exist in the B# name alphabet (REFUTED IF FooBar/Foo_Bar/FooBAR/HttpGet/HTTPGet each derive DISTINCT aliases);
#         (3) the baseline accepts all those names (REFUTED IF baseline bsc rejects any of them).
. "$(dirname "$0")/lib.sh"; build_alias_compiler || { echo "alias compiler build failed"; exit 1; }
B="$HERE/b"; O="$SCRATCH/p06"; rm -rf "$O"; mkdir -p "$O"
exports() { erl -noshell -pa "$1" -eval "M=list_to_atom(\"$2\"), L=[E||E={N,_}<-M:module_info(exports), N=/=module_info, N=/='bs@type_atoms'], io:format(\"  ~p~n\",[lists:sort(L)]), halt()."; }
echo "##### A. Casing module, rule S, thin alias"
BS_ALIAS=thin "$BSC_ALIAS" --src-root "$B" -o "$O/Casing" "$B/Casing" 2>&1 | head -5
exports "$O/Casing" Casing
echo "  -- call each alias and its Pascal original (must agree):"
erl -noshell -pa "$O/Casing" -eval "
  Pairs=[{'HTTPGet',http_get},{'ToJSON',to_json},{'Add2',add2},{'Vec3Dot',vec3_dot},{'FooBar',foo_bar},{'GetHTTPResponse',get_http_response},{'IOList',io_list},{'New',new},{'Spawn',spawn},{'Abs',abs},{'Do','do'},{'End','end'},{'If','if'},{'Fn','fn'},{'Nil',nil},{'True','true'},{'When','when'},{'And','and'},{'Not','not'},{'Case','case'},{'Receive','receive'},{'Of','of'}],
  [io:format(\"  ~p/~p -> ~p, ~p\",[P,A,'Casing':P(1),'Casing':A(1)]) || {P,A} <- Pairs, io:format(\"~n\")==ok], halt()." 2>&1 | grep -v '^$'
echo
echo "##### B. collisions (patch, mode=thin). Each line: source names -> result"
for m in Clash1 Clash2 Clash3 Clash4 Clash5; do
  echo "--- $m: $(grep -h '^public\|^private' "$B/$m"/*.bs | awk '{print $1":"$3}' | sed 's/(int//' | tr '\n' ' ')"
  echo "  baseline bsc:"; "$BSC" --src-root "$B" -o "$O/base_$m" "$B/$m" >"$O/base_$m.log" 2>&1; echo "    exit=$? (0 = compiled); output: $(head -c 200 "$O/base_$m.log")"
  echo "  alias bsc (BS_ALIAS=thin):"; BS_ALIAS=thin "$BSC_ALIAS" --src-root "$B" -o "$O/al_$m" "$B/$m" 2>&1 | head -4 | cut -c1-200 | sed 's/^/    /'
done
echo
echo "##### C. does an alias capture an OTP callback name the language deliberately leaves alone? (bs_otp.erl header: 'a helper that shares a callback's name is never silently captured')"
echo "  Capture declares NO behaviour; its public functions are Init/1, HandleCall/2 (arity 2: not a gen_server callback), Start/2."
echo "  baseline exports:"; "$BSC" --src-root "$B" -o "$O/cap_base" "$B/Capture" >/dev/null 2>&1; exports "$O/cap_base" Capture
echo "  alias exports (BS_ALIAS=thin):"; BS_ALIAS=thin "$BSC_ALIAS" --src-root "$B" -o "$O/cap_alias" "$B/Capture" >/dev/null 2>&1; exports "$O/cap_alias" Capture
echo "  does gen_server accept the alias-bearing module as a callback module (it has init/1 now, but no handle_call/3)?"
erl -noshell -pa "$O/cap_alias" -eval 'R = (catch gen_server:start(list_to_atom("Capture"), 7, [])), io:format("  gen_server:start(Capture, 7, []) -> ~p~n", [R]), halt().' 2>&1 | head -3
echo "  same call against the BASELINE beam:"
erl -noshell -pa "$O/cap_base" -eval 'R = (catch gen_server:start(list_to_atom("Capture"), 7, [])), io:format("  gen_server:start(Capture, 7, []) -> ~p~n", [R]), halt().' 2>&1 | head -3
