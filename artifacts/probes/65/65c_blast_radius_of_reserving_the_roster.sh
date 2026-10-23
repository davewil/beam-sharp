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
# --- the corpus, compared by exit status AND by generated code (beam_lib:md5 of every beam) ---
md5s() { # dir -> "Module md5" lines
  erl -noshell -eval '[begin {ok,{M,H}}=beam_lib:md5(F), io:format("~s ~s~n",[M,binary:encode_hex(H)]) end || F <- filelib:wildcard(hd(init:get_plain_arguments())++"/*.beam")], halt().' -extra "$1" | sort
}
tot=0; same=0; broke=0; ok0=0; harness=0; syntax=0; other=0; codesame=0
OUTROOT="$(mktemp -d)"
run() { # root dir
  local root="$1" dir="$2" a b oa ob
  oa="$OUTROOT/a$tot"; ob="$OUTROOT/b$tot"; mkdir -p "$oa" "$ob"
  a="$("$BSC" --src-root "$root" -o "$oa" "$dir" 2>&1 >/dev/null; echo "rc=$?")" ; b="$("$PATCHED" --src-root "$root" -o "$ob" "$dir" 2>&1 >/dev/null; echo "rc=$?")"
  tot=$((tot+1))
  if [ "${a##*rc=}" = 0 ]; then
    ok0=$((ok0+1))
    [ "$(md5s "$oa")" = "$(md5s "$ob")" ] && codesame=$((codesame+1)) || echo "CODE DIFFERS: ${dir#$REPO/}"
  else
    case "$a" in *"module directory itself"*) harness=$((harness+1));; *"syntax error"*) syntax=$((syntax+1));; *) other=$((other+1));; esac
  fi
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
echo "modules: $tot   exit status agrees: $same   differs: $broke"
echo "  compile under pristine: $ok0   of which generated code (beam_lib:md5, every beam) identical under patched: $codesame"
echo "  do NOT compile under pristine, so they carry no signal: $((tot-ok0)) = $harness harness errors ('--src-root' equals the module dir; compiler/bin/check-exemplar-frontier.sh records the same wall) + $syntax syntax errors (exemplars 'do not parse today') + $other other"
echo "--- why '0 differ' is close to a tautology, and what it does rest on: the collision surface is a whole MODULE NAME or a 'using' namespace's short name"
ROSTERRE="String|Enum|Int|Binary|Process|GenServer|Supervisor|Logger|System|Task|Agent"
echo "  .bs files in git: $(git -C "$REPO" ls-files '*.bs' | wc -l)"
echo "  files declaring a roster word as a WHOLE module name:  $(git -C "$REPO" ls-files '*.bs' | while read -r f; do grep -E "^module ($ROSTERRE)\$" "$REPO/$f"; done | wc -l)"
echo "  files declaring a module whose LAST segment is a roster word (legal; the 'using' short-name collision needs it): $(git -C "$REPO" ls-files '*.bs' | while read -r f; do grep -E "^module [A-Za-z0-9_.]+\.($ROSTERRE)\$" "$REPO/$f"; done | wc -l)"
echo "  calls of the form Roster.Op( anywhere in .bs files: $(git -C "$REPO" ls-files '*.bs' | while read -r f; do grep -Eo "\b($ROSTERRE)\.[A-Z][A-Za-z]*\(" "$REPO/$f"; done | sort | uniq -c | tr '\n' ' ')  (all in non-compiling exemplars)"
W="$(mktemp -d)"; trap 'rm -rf "$W" "$OUTROOT"' EXIT
echo "--- control: the patched compiler still refuses what it refused, and now refuses a roster name"
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
echo "--- a call through a qualifier that is not built yet: what each compiler says (P7's 'advice that can never work')"
mkdir -p "$W/U"
printf 'module U\n\npublic int Go(int n)\nGo(n) -> String.Length(n)\n' > "$W/U/U.bs"
for c in "$BSC" "$PATCHED"; do
  out="$("$c" --src-root "$W" "$W/U" Go 1 2>&1 | head -4 | tr '\n' '|' | sed "s#$W/##g")"
  printf '%-8s String.Length(n), no user String anywhere -> %s\n' "$([ "$c" = "$BSC" ] && echo pristine || echo patched)" "${out:0:260}"
done
echo "--- compile time, 4 vs 15 reserved names: 'bsc --src-root examples examples/Shop', 40 pairs, order alternated each pair to cancel drift"
python3 -I - "$BSC" "$PATCHED" "$REPO/compiler/examples" <<'PY'
import subprocess,sys,time,statistics
a,b,root=sys.argv[1:4]
def run(cmd):
    t=time.perf_counter(); subprocess.run(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); return (time.perf_counter()-t)*1000
def comp(c): return [c,"--src-root",root,root+"/Shop"]
A=[];B=[];V=[]
for i in range(40):
    if i%2: B.append(run(comp(b))); A.append(run(comp(a)))
    else:   A.append(run(comp(a))); B.append(run(comp(b)))
    V.append(run(["erl","-noshell","-eval","halt()."]))
def row(n,x):
    q=statistics.quantiles(x,n=4)
    print(f"   {n:34s} median {statistics.median(x):6.1f} ms  IQR {q[0]:6.1f}-{q[2]:6.1f}  min {min(x):6.1f}  max {max(x):6.1f}  stdev {statistics.stdev(x):5.1f}")
row("pristine (4 reserved names)",A); row("patched (15 reserved names)",B); row("baseline: bare erl VM start+halt",V)
print(f"   median difference patched-pristine: {statistics.median(B)-statistics.median(A):+.1f} ms  (the spread above is larger; this mostly measures VM startup)")
PY
