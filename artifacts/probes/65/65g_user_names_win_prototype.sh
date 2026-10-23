#!/usr/bin/env bash
# PROBE 65g — ticket 65's option 3, "user names win", built and run.
#
# A PROTOTYPE DELTA ON A SCRATCH COPY OF THE COMPILER (the repo is untouched):
#   (1) bs_check:reserved_module_name/2 no longer refuses the four reserved qualifiers, so
#       `module List` declares;
#   (2) bs_check:type_of/3's e_qcall clause sends a reserved qualifier through the ordinary
#       module path when a `using` line also claims the short name, instead of refusing;
#   (3) bs_emit:expr/2's e_qcall clause asks the same question. WITHOUT (3) THE PROGRAM
#       TYPE-CHECKS AGAINST THE USER'S SIGNATURE AND RUNS THE STANDARD OPERATION: the emitter
#       decides "reserved" from the module name alone (bs_emit.erl:1050), so a checker-only
#       user-wins is a silent wrong answer (measured first: P2 printed 1, not 99). The `qmods`
#       table the emitter already receives (bs_emit.erl:47, 127) is the side channel.
# The same programs then run under the pristine compiler and the user-wins one. CONTROL (P4):
# a program with no user `List` anywhere is identical under both — the delta does not touch
# the unshadowed path. The point of P3 is what user-wins COSTS: the standard operations
# become unreachable in any scope that shadows the word.
#
#   source env.sh; bash artifacts/probes/65/65g_user_names_win_prototype.sh
set -uo pipefail
: "${BSC:?source env.sh first}"; : "${S:?source env.sh first}"
REPO="$(git rev-parse --show-toplevel)"
P="$S/compiler-65g"; rm -rf "$P"; cp -r "$REPO/compiler" "$P"; rm -rf "$P/_build"
patch() { python3 -I - "$1/src/bs_check.erl" "$2" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
a="case lists:member(Module, reserved_qualifiers() ++ maps:keys(protocol_table())) of"
assert s.count(a)==1
s=s.replace(a,"case lists:member(Module, maps:keys(protocol_table())) of")
b="        {_, true} -> reserved_call(L, Mod0, Fun, Args, S, C);"
assert s.count(b)==1
s=s.replace(b,"""        {_, true} ->
            case maps:get(Mod0, maps:get(mods, C#ctx.imports, #{}), []) of
                [] -> reserved_call(L, Mod0, Fun, Args, S, C);
                _  -> UMod = qualified_module(Mod0, L, C),
                      call(L, {q, UMod, Fun, length(Args)}, qualified_name(UMod, Fun),
                           Args, S, C)
            end;""")
open(p,"w").write(s)
if sys.argv[2] != "full": raise SystemExit
e=sys.argv[1].replace("bs_check","bs_emit"); t=open(e).read()
c="    case lists:member(Mod, bs_check:reserved_qualifiers()) of\n        true ->\n            Key = {Mod, Fn, length(As)},"
assert t.count(c)==1
t=t.replace(c,"    case lists:member(Mod, bs_check:reserved_qualifiers())\n         andalso not is_map_key(Mod, maps:get(qmods, C, #{})) of\n        true ->\n            Key = {Mod, Fn, length(As)},")
open(e,"w").write(t)
PY
}
patch "$P" full
H="$S/compiler-65g-half"; rm -rf "$H"; cp -r "$REPO/compiler" "$H"; rm -rf "$H/_build"; patch "$H" checker-only
echo "prototype delta: $(diff "$REPO/compiler/src/bs_check.erl" "$P/src/bs_check.erl" | grep -c '^[<>]') changed lines in bs_check.erl + $(diff "$REPO/compiler/src/bs_emit.erl" "$P/src/bs_emit.erl" | grep -c '^[<>]') in bs_emit.erl (scratch copy)"
(cd "$P" && rebar3 escriptize >/dev/null 2>&1) || { echo "patched build failed"; exit 2; }
(cd "$H" && rebar3 escriptize >/dev/null 2>&1) || { echo "half-patched build failed"; exit 2; }
UW="$P/_build/default/bin/bsc"; HALF="$H/_build/default/bin/bsc"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/Shop/Coll/List" "$W/List" "$W/P1" "$W/P2" "$W/P3" "$W/P4"
printf 'module Shop.Coll.List\n\npublic int Length(list<int> xs)\nLength(xs) -> 99\n' > "$W/Shop/Coll/List/List.bs"
printf 'module List\n\npublic int Go(int n)\nGo(n) -> n\n'                                           > "$W/List/List.bs"
printf 'module P2\n\nusing Shop.Coll\n\npublic int Go(int n)\nGo(n) -> List.Length([n])\n'                    > "$W/P2/P2.bs"
printf 'module P3\n\nusing Shop.Coll\n\npublic int Go(int n)\nGo(n) -> List.Sum([n, n])\n'                    > "$W/P3/P3.bs"
printf 'module P4\n\npublic int Go(int n)\nGo(n) -> List.Sum([n, n]) + List.Length([n])\n'                    > "$W/P4/P4.bs"
show() { # label prog-dir
  for c in "$BSC" "$UW"; do
    out="$("$c" --src-root "$W" "$W/$2" Go 1 2>&1 | head -3 | tr '\n' '|' | sed "s#$W/##g")"
    printf '%-10s %-34s %s\n' "$([ "$c" = "$BSC" ] && echo pristine || echo user-wins)" "$1" "${out:0:210}"
  done
}
show "P1 module List (declaration)"                    List
show "P2 using Shop.Coll; List.Length([n])"            P2
show "P3 using Shop.Coll; List.Sum([n,n])  <- cost"    P3
show "P4 no user List anywhere (control)"              P4
echo "--- the half-built delta (checker only, emitter untouched): the same P2"
out="$("$HALF" --src-root "$W" "$W/P2" Go 1 2>&1 | head -2 | tr '\n' '|')"
printf '%-10s %-34s %s\n' checker-only "P2 using Shop.Coll; List.Length([n])" "$out"
echo "   (99 is the user's Length; 1 is lists-length of [1]. It type-checked against the user's signature and ran the standard op.)"
