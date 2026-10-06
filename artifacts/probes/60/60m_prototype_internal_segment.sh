#!/usr/bin/env bash
# PROBE 60m -- ticket 60 (ENG-242). Rule-by-path, Go's `internal`, no new syntax (proto_patch_path.py):
# a module whose dotted path has an `Internal` segment may be named only from the subtree rooted at
# that segment's parent. The SAME source tree is compiled by the pristine and the patched bsc.
#   M1 pristine: every module compiles, including Lab.Web naming Lab.Core.Internal.Pricing (today).
#   M2 patched: Lab.Core (the parent itself) names it.          exit 0
#   M3 patched: Lab.Core.Sub (a sibling directory under the parent) names it.  exit 0
#   M4 patched: Lab.Web names it: refused.                      exit 1
#   M5 patched: Lab.Web names Lab.Core (non-Internal): compiles (CONTROL: only the segment triggers).
set -uo pipefail
: "${PRISTINE:?}" ; : "${PATH_BSC:?}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/src/Lab/Core/Internal/Pricing" "$W/src/Lab/Core/Sub" "$W/src/Lab/Web" "$W/src/Lab/WebOk"
printf 'module Lab.Core.Internal.Pricing\npublic int Price(int n)\nPrice(n) -> n * 2\n' > "$W/src/Lab/Core/Internal/Pricing/Pricing.bs"
printf 'module Lab.Core\nusing Lab.Core.Internal.Pricing\npublic int Api(int n)\nApi(n) -> Price(n)\n' > "$W/src/Lab/Core/Core.bs"
printf 'module Lab.Core.Sub\nusing Lab.Core.Internal.Pricing\npublic int S(int n)\nS(n) -> Price(n)\n' > "$W/src/Lab/Core/Sub/Sub.bs"
printf 'module Lab.Web\nusing Lab.Core.Internal.Pricing\npublic int W(int n)\nW(n) -> Price(n)\n' > "$W/src/Lab/Web/Web.bs"
printf 'module Lab.WebOk\nusing Lab.Core\npublic int W(int n)\nW(n) -> Api(n)\n' > "$W/src/Lab/WebOk/WebOk.bs"
b() { erl -noshell -pa "$1/ebin" -eval 'bsc:main(init:get_plain_arguments())' -extra --src-root "$W/src" -o "$W/o" "$W/src/Lab/$2" 2>&1 | sed "s|$W/src/||" | head -3; return "${PIPESTATUS[0]}"; }
for m in Core Core/Sub Web WebOk; do b "$PRISTINE" $m >/dev/null; echo "M1 pristine Lab/$m exit=$?"; done
for m in Core Core/Sub; do b "$PATH_BSC" $m >/dev/null; echo "patched Lab/$m exit=$?"; done
b "$PATH_BSC" Web; echo "patched Lab/Web exit=${PIPESTATUS[0]}"
b "$PATH_BSC" WebOk >/dev/null; echo "patched Lab/WebOk (control) exit=$?"
