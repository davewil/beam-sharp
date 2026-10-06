#!/usr/bin/env bash
# PROBE 60n -- ticket 60 (ENG-242). Strongest counter to rule-by-path: visibility becomes part of the
# module's NAME, and the name is the emitted atom and the record tag (ticket 40 §1, 26 §1, F3).
#   N1 the same record, declared in Lab.Core.Pricing vs Lab.Core.Internal.Pricing, carries a different
#      tag at run time: moving a module under `Internal` changes the term on the wire.
#   N2 CONTROL: under the declaration form (`visible_to`) the module keeps its path, so its tag does
#      not change when visibility is added (patched bsc, same module path before/after).
set -uo pipefail
: "${BSC:?}"; : "${PATCHED:?}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mk() { mkdir -p "$W/$1/$2"; printf 'module %s\n%srecord Order { Id: int }\npublic Order New(int id)\nNew(id) -> Order{ Id = id }\n' "$3" "${4:-}" > "$W/$1/$2/m.bs"; }
mk s Lab/Core/Pricing Lab.Core.Pricing
mk s Lab/Core/Internal/Pricing Lab.Core.Internal.Pricing
tag() { erl -noshell -pa "$1" -eval "io:format(\"~p~n\", ['$2':'New'(1)]), halt()."; }
"$BSC" --src-root "$W/s" -o "$W/o1" "$W/s/Lab/Core/Pricing" >/dev/null 2>&1
"$BSC" --src-root "$W/s" -o "$W/o2" "$W/s/Lab/Core/Internal/Pricing" >/dev/null 2>&1
echo "N1 before (Lab.Core.Pricing)          : $(tag "$W/o1" Lab.Core.Pricing)"
echo "N1 after  (Lab.Core.Internal.Pricing) : $(tag "$W/o2" Lab.Core.Internal.Pricing)"
mk d Lab/Core/Pricing Lab.Core.Pricing
"$BSC" --src-root "$W/d" -o "$W/o3" "$W/d/Lab/Core/Pricing" >/dev/null 2>&1
mk d2 Lab/Core/Pricing Lab.Core.Pricing $'visible_to Lab.Core\n'
erl -noshell -pa "$PATCHED/ebin" -eval 'bsc:main(init:get_plain_arguments())' -extra --src-root "$W/d2" -o "$W/o4" "$W/d2/Lab/Core/Pricing" >/dev/null 2>&1
echo "N2 declaration form, before           : $(tag "$W/o3" Lab.Core.Pricing)"
echo "N2 declaration form, after visible_to : $(tag "$W/o4" Lab.Core.Pricing)"
