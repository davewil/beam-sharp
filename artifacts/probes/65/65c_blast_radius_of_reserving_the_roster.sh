#!/usr/bin/env bash
# PROBE 65c — what breaks if the planned standard-environment roster is reserved NOW?
#
# Ticket 96 lists the qualifiers it will add: Enum, String, Int, Binary, Process,
# GenServer, Supervisor, Logger, System, Task, Agent. Q6 says each is reserved when
# it lands. This is the cost of reserving them all today: a one-line PROTOTYPE DELTA
# on a SCRATCH COPY of the compiler (reserved_qualifiers/0 gains eleven atoms; the
# repo is not touched), then every example module compiled by the pristine $BSC and
# by the patched one. A difference in exit status is a program the reservation breaks.
# The control is that the two compilers agree on everything else.
#
#   source env.sh; bash artifacts/probes/65/65c_blast_radius_of_reserving_the_roster.sh
set -uo pipefail
: "${BSC:?source env.sh first}"; : "${S:?source env.sh first}"
REPO="$(git rev-parse --show-toplevel)"
P="$S/compiler-65c"; rm -rf "$P"; cp -r "$REPO/compiler" "$P"; rm -rf "$P/_build"
ROSTER="'String', 'Enum', 'Int', 'Binary', 'Process', 'GenServer', 'Supervisor', 'Logger', 'System', 'Task', 'Agent'"
OLD="reserved_qualifiers() -> ['List', 'Map', 'Term', 'Float']."
grep -qF "$OLD" "$P/src/bs_check.erl" || { echo "PROBE BROKEN: baseline line not found"; exit 2; }
sed -i "s|reserved_qualifiers() -> \['List', 'Map', 'Term', 'Float'\].|reserved_qualifiers() -> ['List', 'Map', 'Term', 'Float', $ROSTER].|" "$P/src/bs_check.erl"
echo "prototype delta: $(diff <(cd "$REPO/compiler/src" && cat bs_check.erl) "$P/src/bs_check.erl" | grep -c '^>') line changed in bs_check.erl (scratch copy only)"
(cd "$P" && rebar3 escriptize >/dev/null 2>&1) || { echo "patched build failed"; exit 2; }
PATCHED="$P/_build/default/bin/bsc"
tot=0; same=0; broke=0; ok0=0
run() { # root dir
  local root="$1" dir="$2" a b
  a="$("$BSC" --src-root "$root" "$dir" 2>&1 >/dev/null; echo "rc=$?")" ; b="$("$PATCHED" --src-root "$root" "$dir" 2>&1 >/dev/null; echo "rc=$?")"
  tot=$((tot+1)); [ "${a##*rc=}" = 0 ] && ok0=$((ok0+1))
  if [ "${a##*rc=}" = "${b##*rc=}" ]; then same=$((same+1)); else
    broke=$((broke+1)); echo "DIFFERS: ${dir#$REPO/}"; echo "   pristine: ${a##*rc=}   patched: ${b##*rc=}"; printf '%s\n' "$b" | head -3 | sed "s#$REPO/##" | sed 's/^/   /'
  fi
}
for d in "$REPO"/compiler/examples/*/; do
  d="${d%/}"; [ "$(basename "$d")" = exemplars ] && continue
  ls "$d"/*.bs >/dev/null 2>&1 || continue
  run "$REPO/compiler/examples" "$d"
done
for d in "$REPO"/compiler/examples/exemplars/*/; do d="${d%/}"; run "$d" "$d"; done
echo "modules compiled: $tot   agree: $same   differ: $broke   (pristine exit 0: $ok0 — the rest fail under BOTH, so they carry no signal)"
echo "--- control: the patched compiler still refuses what it refused, and now refuses a roster name"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
for m in List String; do mkdir -p "$W/$m"; printf 'module %s\n\npublic int Go(int n)\nGo(n) -> n\n' "$m" > "$W/$m/$m.bs"
  for c in "$BSC" "$PATCHED"; do printf '%-9s module %-7s -> %s\n' "$([ "$c" = "$BSC" ] && echo pristine || echo patched)" "$m" "$("$c" --src-root "$W" "$W/$m" Go 1 2>&1 | head -1 | sed "s#$W/##")"; done
done
echo "--- what an author's existing program does the day 'String' lands (pristine = today, patched = after) ---"
R="$W/mig"; mkdir -p "$R/Shop/Text/String" "$R/A" "$R/B" "$R/C"
printf 'module Shop.Text.String\n\npublic int Length(int s)\nLength(s) -> 98\n' > "$R/Shop/Text/String/String.bs"
printf 'module A\n\nusing Shop.Text\n\npublic int Go(int n)\nGo(n) -> String.Length(n)\n'            > "$R/A/A.bs"   # short name through a namespace import
printf 'module B\n\nusing Shop.Text.String\n\npublic int Go(int n)\nGo(n) -> Shop.Text.String.Length(n)\n'  > "$R/B/B.bs"   # full path (the fix the diagnostic prints)
printf 'module C\n\nusing Shop.Text.String\n\npublic int Go(int n)\nGo(n) -> Length(n)\n'              > "$R/C/C.bs"   # module-tier import, unqualified
for p in A B C; do
  for c in "$BSC" "$PATCHED"; do
    out="$("$c" --src-root "$R" "$R/$p" Go 1 2>&1 | head -4 | tr '\n' '|' | sed "s#$R/##g")"
    printf '%-8s %s -> %s\n' "$([ "$c" = "$BSC" ] && echo pristine || echo patched)" "$p" "${out:0:230}"
  done
done
