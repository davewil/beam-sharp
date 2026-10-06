#!/usr/bin/env bash
# PROBE 60k -- ticket 60 (ENG-242). The other direction, prototyped in a scratch copy
# (proto_patch_caller.py): the CALLER writes `forbids <Module>` and the check reads only the
# importer's own declarations (import_env already holds Decls and Self: no World field, no bsc.erl change).
#   K1 Lab.Web with `forbids Lab.Grp` naming Lab.Grp.Core: refused, exit 1.
#   K2 CONTROL: Lab.Billing, no `forbids`, names the same module: compiles, exit 0.
#   K3 THE WEAKNESS: Lab.Web2 is a NEW module that simply omits `forbids`: compiles, exit 0.
#      Protection exists only where every caller opted in; the callee cannot protect itself.
# Usage: CALLER=<dir from build_proto.sh <dir> --patch-caller> ./60k_prototype_caller_declares.sh
set -uo pipefail
: "${CALLER:?}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/src/Lab/Grp/Core" "$W/src/Lab/Web" "$W/src/Lab/Billing" "$W/src/Lab/Web2"
printf 'module Lab.Grp.Core\npublic int Sum(int a, int b)\nSum(a, b) -> a + b\n' > "$W/src/Lab/Grp/Core/Core.bs"
printf 'module Lab.Web\nforbids Lab.Grp\nusing Lab.Grp.Core\npublic int W(int n)\nW(n) -> Sum(n, 3)\n' > "$W/src/Lab/Web/Web.bs"
printf 'module Lab.Billing\nusing Lab.Grp.Core\npublic int B(int n)\nB(n) -> Sum(n, 1)\n' > "$W/src/Lab/Billing/Billing.bs"
printf 'module Lab.Web2\nusing Lab.Grp.Core\npublic int W(int n)\nW(n) -> Sum(n, 4)\n' > "$W/src/Lab/Web2/Web2.bs"
for m in Web Billing Web2; do
  erl -noshell -pa "$CALLER/ebin" -eval 'bsc:main(init:get_plain_arguments())' -extra --src-root "$W/src" -o "$W/o" "$W/src/Lab/$m" 2>&1 | sed "s|$W/src/||" | head -2
  echo "Lab.$m exit=${PIPESTATUS[0]}"
done
