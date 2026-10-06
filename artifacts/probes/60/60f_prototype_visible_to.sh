#!/usr/bin/env bash
# PROBE 60f -- ticket 60 (ENG-242). Claim: the callee-side, subtree-unit declaration costs ONE new
# decl (`visible_to M`), ONE World field, and a check at add_import/add_module_import (strict mode),
# and it behaves as follows on a real compile. Built from a SCRATCH COPY of compiler/src
# (build_proto.sh --patch + proto_patch.py); the repo is never edited.
#   V1 CONTROL (pristine bsc, same sources minus the one declaration): Lab.Web names Lab.Grp.Core -> exit 0 (today).
#   V2 patched: Lab.Billing (named in visible_to) compiles.            exit 0
#   V3 patched: Lab.Billing.Deep (a SUBTREE of Lab.Billing) compiles.   exit 0
#   V4 patched: Lab.Web is refused, diagnostic names both modules.      exit 1
#   V5 patched: `using Lab` (namespace import) then Core.Sum from Lab.Web is ALSO refused (no bypass
#       through the namespace tier).                                    exit 1
#   V6 patched: a call that skips `using` altogether is refused by the EXISTING module_not_imported
#       rule, so `using` is the single choke point the check relies on. exit 1
#   V7 patched: the dynamic hole -- Lab.Sneak calls :erlang.apply(m, f, ..) and reaches Lab.Grp.Core at
#       run time; compiles, exit 0, prints 4. The check is source-level only.
# Usage: S=<scratch>; ./build_proto.sh $S/pristine; ./build_proto.sh $S/patched --patch;
#        PRISTINE=$S/pristine PATCHED=$S/patched ./60f_prototype_visible_to.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${PRISTINE:?dir from build_proto.sh <dir>}" ; : "${PATCHED:?dir from build_proto.sh <dir> --patch}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/src/Lab/Grp/Core" "$W/src/Lab/Billing/Deep" "$W/src/Lab/Web" "$W/src/Lab/WebNs" "$W/src/Lab/WebNoUsing" "$W/src/Lab/Sneak"
printf 'module Lab.Grp.Core\nvisible_to Lab.Billing\n' > "$W/src/Lab/Grp/Core/index.bs"
printf 'public int Sum(int a, int b)\nSum(a, b) -> a + b\n' > "$W/src/Lab/Grp/Core/Sum.bs"
printf 'module Lab.Billing\nusing Lab.Grp.Core\npublic int Bill(int n)\nBill(n) -> Sum(n, 1)\n' > "$W/src/Lab/Billing/Bill.bs"
printf 'module Lab.Billing.Deep\nusing Lab.Grp.Core\npublic int D(int n)\nD(n) -> Sum(n, 2)\n' > "$W/src/Lab/Billing/Deep/Deep.bs"
printf 'module Lab.Web\nusing Lab.Grp.Core\npublic int W(int n)\nW(n) -> Sum(n, 3)\n' > "$W/src/Lab/Web/Web.bs"
printf 'module Lab.WebNs\nusing Lab.Grp\npublic int W(int n)\nW(n) -> Core.Sum(n, 3)\n' > "$W/src/Lab/WebNs/WebNs.bs"
printf 'module Lab.WebNoUsing\npublic int W(int n)\nW(n) -> Lab.Grp.Core.Sum(n, 3)\n' > "$W/src/Lab/WebNoUsing/WebNoUsing.bs"
printf 'module Lab.Sneak\nusing :erlang {\n    int apply(atom m, atom f, list<int> args)\n}\npublic int Dyn(atom m, atom f, int n)\nDyn(m, f, n) -> :erlang.apply(m, f, [n, 3])\n' > "$W/src/Lab/Sneak/Sneak.bs"
bs() { # <ebin parent> <module path> <outdir>
  erl -noshell -pa "$1/ebin" -eval 'bsc:main(init:get_plain_arguments())' -extra --src-root "$W/src" -o "$3" "$W/src/Lab/$2" 2>&1 | sed "s|$W/src/||" | head -3
  return "${PIPESTATUS[0]}"; }
row() { echo "$1 exit=$2"; }
mkdir -p "$W/o1" "$W/o2"
# V1: the pristine bsc has no `visible_to`, so the control tree is the same sources without that line
cp -r "$W/src" "$W/src0"; printf 'module Lab.Grp.Core\n' > "$W/src0/Lab/Grp/Core/index.bs"
erl -noshell -pa "$PRISTINE/ebin" -eval 'bsc:main(init:get_plain_arguments())' -extra --src-root "$W/src0" -o "$W/o1" "$W/src0/Lab/Web" >/dev/null 2>&1; row "V1 pristine bsc, no visible_to: Lab.Web names Lab.Grp.Core" $?
bs "$PATCHED" Billing "$W/o2" >/dev/null; row "V2 patched: Lab.Billing" $?
bs "$PATCHED" Billing/Deep "$W/o2" >/dev/null; row "V3 patched: Lab.Billing.Deep (subtree)" $?
bs "$PATCHED" Web "$W/o2"; row "V4 patched: Lab.Web" ${PIPESTATUS[0]}
bs "$PATCHED" WebNs "$W/o2"; row "V5 patched: Lab.WebNs via namespace" ${PIPESTATUS[0]}
bs "$PATCHED" WebNoUsing "$W/o2"; row "V6 patched: Lab.WebNoUsing" ${PIPESTATUS[0]}
bs "$PATCHED" Sneak "$W/o2" ; row "V7 patched: Lab.Sneak (dynamic)" $?
erl -noshell -pa "$W/o2" -eval 'io:format("   run Lab.Sneak:Dyn(Lab.Grp.Core, Sum, 1) = ~p~n", [catch '"'"'Lab.Sneak'"'"':'"'"'Dyn'"'"'('"'"'Lab.Grp.Core'"'"', '"'"'Sum'"'"', 1)]), halt().'
