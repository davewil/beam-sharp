#!/usr/bin/env bash
# PROBE 65g — ticket 65's option 3, "user names win", prototyped three ways and run.
#
# EVERYTHING HERE IS A PROTOTYPE DELTA ON SCRATCH COPIES OF THE COMPILER; the repo is untouched.
# What is measured is these prototypes, NOT the option in the abstract: a different build of
# "user names win" could behave differently, and the findings below say which delta they belong to.
#
#   half   (checker only)  bs_check:reserved_module_name/2 stops refusing the four qualifiers, and
#                          type_of/3's e_qcall clause sends a qualifier a `using` also claims
#                          through the ordinary module path. The emitter is untouched.
#   shadow (full)          half + bs_emit:expr/2 skips the standard lowering when the `qmods` table
#                          the emitter already receives (bs_emit.erl:47,127) holds the short name.
#                          The user's module replaces the standard one for the whole word.
#   fall   (per-site)      the checker uses the claimant's function when it DECLARES that
#                          name/arity and otherwise falls through to the standard operation; it
#                          tells the emitter which sites were the user's with a new `ruser` note
#                          (the `pcall` mechanism of F64: is_note/1, Keyed/1, the result map, the
#                          emitter's ctx). No warning is emitted: that needs a bs_diag clause and
#                          is NOT built here, so "shadowing does not warn" is a fact about this
#                          prototype only.
#
#   source env.sh; bash artifacts/probes/65/65g_user_names_win_prototype.sh
set -uo pipefail
: "${BSC:?source env.sh first}"; : "${S:?source env.sh first}"
REPO="$(git rev-parse --show-toplevel)"
patch() { python3 -I - "$1/src/bs_check.erl" "$2" <<'PY'
import sys
p=sys.argv[1]; mode=sys.argv[2]; s=open(p).read()
def sub(old,new):
    global s
    assert s.count(old)==1, old
    s=s.replace(old,new)
sub("case lists:member(Module, reserved_qualifiers() ++ maps:keys(protocol_table())) of",
    "case lists:member(Module, maps:keys(protocol_table())) of")
old="        {_, true} -> reserved_call(L, Mod0, Fun, Args, S, C);"
if mode in ("half","shadow"):
    sub(old,"""        {_, true} ->
            case maps:get(Mod0, maps:get(mods, C#ctx.imports, #{}), []) of
                [] -> reserved_call(L, Mod0, Fun, Args, S, C);
                _  -> UMod = qualified_module(Mod0, L, C),
                      call(L, {q, UMod, Fun, length(Args)}, qualified_name(UMod, Fun),
                           Args, S, C)
            end;""")
else:
    sub(old,"""        {_, true} ->
            case maps:get(Mod0, maps:get(mods, C#ctx.imports, #{}), []) of
                [] -> reserved_call(L, Mod0, Fun, Args, S, C);
                _  -> UMod = qualified_module(Mod0, L, C),
                      UKey = {q, UMod, Fun, length(Args)},
                      case maps:is_key(UKey, C#ctx.callees) of
                          true  -> {URet, UD} = call(L, UKey, qualified_name(UMod, Fun), Args, S, C),
                                   {URet, [{ruser, L, true} | UD]};
                          false -> reserved_op(L, Mod0, Fun, Args, S, C)
                      end
            end;""")
    sub("is_note(D) -> lists:member(element(1, D), [prune, fname, fdiv, vproj, pcall, ihole]).",
        "is_note(D) -> lists:member(element(1, D), [prune, fname, fdiv, vproj, pcall, ihole, ruser]).")
    sub("    Pcalls = Keyed(pcall),","    Pcalls = Keyed(pcall),\n    Rusers = Keyed(ruser),")
    sub("                         pcalls => Pcalls,","                         pcalls => Pcalls,\n                         rusers => Rusers,")
open(p,"w").write(s)
if mode=="half": raise SystemExit
e=sys.argv[1].replace("bs_check","bs_emit"); t=open(e).read()
c="    case lists:member(Mod, bs_check:reserved_qualifiers()) of\n        true ->\n            Key = {Mod, Fn, length(As)},"
assert t.count(c)==1
if mode=="shadow":
    t=t.replace(c,"    case lists:member(Mod, bs_check:reserved_qualifiers())\n         andalso not is_map_key(Mod, maps:get(qmods, C, #{})) of\n        true ->\n            Key = {Mod, Fn, length(As)},")
else:
    t=t.replace(c,"    case lists:member(Mod, bs_check:reserved_qualifiers())\n         andalso not is_map_key({map_get(file, C), L}, maps:get(rusers, C, #{})) of\n        true ->\n            Key = {Mod, Fn, length(As)},")
    d="            pcalls => maps:get(pcalls, Module, #{}),"
    assert t.count(d)==1
    t=t.replace(d,d+"\n            rusers => maps:get(rusers, Module, #{}),")
open(e,"w").write(t)
PY
}
declare -A BIN
for m in half shadow fall; do
  D="$S/compiler-65g-$m"; rm -rf "$D"; cp -r "$REPO/compiler" "$D"; rm -rf "$D/_build"; patch "$D" "$m"
  (cd "$D" && rebar3 escriptize >/dev/null 2>&1) || { echo "$m build failed"; exit 2; }
  BIN[$m]="$D/_build/default/bin/bsc"
  echo "prototype '$m': $(diff "$REPO/compiler/src/bs_check.erl" "$D/src/bs_check.erl" | grep -c '^[<>]') changed lines in bs_check.erl + $(diff "$REPO/compiler/src/bs_emit.erl" "$D/src/bs_emit.erl" | grep -c '^[<>]') in bs_emit.erl"
done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/Shop/Coll/List" "$W/Shop/Coll/Term" "$W/List" "$W/Map" "$W"/P{2,3,4,5,6,6b}
printf 'module Shop.Coll.List\n\npublic int Length(list<int> xs)\nLength(xs) -> 99\n' > "$W/Shop/Coll/List/List.bs"
printf 'module Shop.Coll.Term\n\npublic atom Compare(int a, int b)\nCompare(a, b) -> :user\n' > "$W/Shop/Coll/Term/Term.bs"
printf 'module List\n\npublic int Twice(int n)\nTwice(n) -> n + n\n\npublic int Go(int n)\nGo(n) -> n\n' > "$W/List/List.bs"
printf 'module Map\n\npublic int Twice(int n)\nTwice(n) -> n + n\n\npublic int Via(int n)\nVia(n) -> Map.Twice(n)\n' > "$W/Map/Map.bs"
printf 'module P2\n\nusing Shop.Coll\n\npublic int Go(int n)\nGo(n) -> List.Length([n])\n'                  > "$W/P2/P2.bs"
printf 'module P3\n\nusing Shop.Coll\n\npublic int Go(int n)\nGo(n) -> List.Sum([n, n])\n'                  > "$W/P3/P3.bs"
printf 'module P4\n\npublic int Go(int n)\nGo(n) -> List.Sum([n, n]) + List.Length([n])\n'                  > "$W/P4/P4.bs"
printf 'module P5\n\nusing Shop.Coll\n\npublic atom Go(int n)\nGo(n) -> Term.Compare(n, 2)\n'              > "$W/P5/P5.bs"
printf 'module P6\n\nusing List\n\npublic int Go(int n)\nGo(n) -> Twice(n) + List.Twice(n) + List.Sum([n])\n' > "$W/P6/P6.bs"
printf 'module P6b\n\nusing List\n\npublic int Go(int n)\nGo(n) -> Twice(n) + List.Sum([n])\n' > "$W/P6b/P6b.bs"
show() { # label dir [fn]
  echo "== $1"
  local name c
  for name in pristine half shadow fall; do
    if [ $name = pristine ]; then c="$BSC"; else c="${BIN[$name]}"; fi
    out="$("$c" --src-root "$W" "$W/$2" ${3:-Go} 1 2>&1 | head -3 | tr '\n' '|' | sed "s#$W/##g")"
    printf '   %-9s %s\n' "$name" "${out:0:170}"
  done
}
show "P1  module List declared (Go returns n)"                     List
show "P2  using Shop.Coll; List.Length([n])  [user declares Length; 99 = user, 1 = standard]"  P2
show "P3  using Shop.Coll; List.Sum([n,n])   [user module has no Sum; 2 = standard]"          P3
show "P4  no user List anywhere (control; 3 = standard)"           P4
show "P5  using Shop.Coll; Term.Compare(n,2) [a 'generated' row; :user = user's]"            P5
show "P6b module-tier 'using List' (top-level user List); Twice(n) + List.Sum([n])  [n=1: user's Twice 2 + standard Sum 1 = 3]" P6b
show "P6  module-tier 'using List' (top-level user List); Twice(n)+List.Twice(n)+List.Sum([n]) [n=1: 2+2+1=5; EXPECTED TO FAIL in every prototype: a module-tier 'using' does not populate the short-name table the delta consults]" P6
show "P7  call from INSIDE a top-level user module Map: Via(n) -> Map.Twice(n)  [2 = user's Twice; EXPECTED TO FAIL: a module is not its own claimant in that table]"  Map Via
echo "== generated code"
md5() { erl -noshell -eval '{ok,{_,M}}=beam_lib:md5(hd(init:get_plain_arguments())), io:format("~s~n",[binary:encode_hex(M)]), halt().' -extra "$1"; }
for name in pristine half shadow fall; do
  if [ $name = pristine ]; then c="$BSC"; else c="${BIN[$name]}"; fi
  mkdir -p "$W/o_$name"; "$c" --src-root "$W" -o "$W/o_$name" "$W/P4" >/dev/null 2>&1
  printf '   P4 (no user List) %-9s code md5 %s\n' "$name" "$(md5 "$W/o_$name/P4.beam")"
done
echo "   (raw .beam files differ only in compile_info's source path, naming each run's own output dir; Code, AtU8, ExpT, ImpT chunks verified equal by hand 2026-10-23)"
fns() { erl -noshell -pa "$1" -eval 'M=list_to_atom(hd(init:get_plain_arguments())), code:load_file(M), io:format("~p~n",[lists:sort([F||{F,_}<-M:module_info(functions), F=/=module_info])]), halt().' -extra "$2"; }
for name in shadow fall; do
  mkdir -p "$W/o5_$name"; "${BIN[$name]}" --src-root "$W" -o "$W/o5_$name" "$W/P5" >/dev/null 2>&1
  printf '   P5 functions in the compiled beam, %-6s %s\n' "$name" "$(fns "$W/o5_$name" P5)"
done
echo "   (a function named like 'bs@list...' / 'Term...Compare' that nothing calls is the stray helper from bs_emit.erl:2102 reserved_forms/1, which these prototypes do NOT patch)"
