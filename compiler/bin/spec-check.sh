#!/usr/bin/env bash
#
# Regression test on `bs_emit`'s spec emission — the cheapest one available, and
# nothing else runs it.
#
# Ticket 06 recommended emitting `-spec`s and ticket 13 §6 committed to it,
# building its whole widening rule around what Dialyzer would read. Dialyzer is
# the tool those specs exist for, so a wrong spec is a defect Dialyzer will name
# and the unit suite cannot see.
#
# Costs ~9 s once to build the PLT, then ~0.05 s per run.
#
# The negative controls are the point. A clean Dialyzer run proves nothing unless
# a wrong spec would actually fail it — ticket 15 lost a session to a harness
# that supplied the protection it was measuring, and this script exists partly to
# not repeat that.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${SPEC_CHECK_DIR:-${TMPDIR:-/tmp}/bsc-spec-check}"
PLT="$WORK/base.plt"
OUT="$WORK/out"     # examples only
CTL="$WORK/ctl"     # negative controls, kept apart so they never join the main run
BSC="$HERE/_build/default/bin/bsc"

rm -rf "$OUT" "$CTL"
mkdir -p "$WORK" "$OUT" "$CTL"

[ -x "$BSC" ] || { echo "building escript..."; (cd "$HERE" && rebar3 escriptize >/dev/null); }

if [ ! -f "$PLT" ]; then
  echo "building base PLT (once, ~9 s)..."
  dialyzer --build_plt --output_plt "$PLT" --apps erts kernel stdlib >/dev/null 2>&1 || true
fi

echo "=== compiling the examples with bsc ==="
for f in "$HERE"/examples/*.bs; do
  "$BSC" -o "$OUT" "$f"
  echo "  $(basename "$f")"
done

echo
echo "=== Dialyzer, default warning set — any warning is a defect in bs_emit ==="
if dialyzer --plt "$PLT" "$OUT"/*.beam; then
  echo "PASS: every emitted spec is accepted"
else
  echo "FAIL: Dialyzer rejected an emitted spec" >&2
  exit 1
fi

echo
echo "=== negative controls: a wrong spec MUST be caught ==="
# Take a real emitted .abstr and corrupt ONLY its spec, so a control differs from
# the real artefact in exactly one respect. The .abstr is a sequence of Erlang
# terms, so it is read with file:consult/1 and rewritten — sed cannot do this
# reliably, because the forms are pretty-printed across several lines.
control() {
  local name="$1" which="$2"
  local src="$OUT/Readings.abstr" dst="$CTL/Ctl$name.abstr"
  erl -noshell -eval "
    {ok, Forms} = file:consult(\"$src\"),
    Int = {type,0,integer,[]},
    Atom = {type,0,atom,[]},
    New = [case F of
             {attribute,L,module,_} -> {attribute,L,module,'Ctl$name'};
             {attribute,L,spec,{NA,[{type,SL,'fun',[{type,PL,product,[_Arg]}, Ret]}]}} ->
                 case \"$which\" of
                   %% claim it returns an integer where every clause returns an atom
                   \"ret\" -> {attribute,L,spec,{NA,[{type,SL,'fun',
                                [{type,PL,product,[element(1,{_Arg,x})]}, Int]}]}};
                   %% claim it accepts a bare atom where every clause matches a tuple
                   \"arg\" -> {attribute,L,spec,{NA,[{type,SL,'fun',
                                [{type,PL,product,[Atom]}, Ret]}]}}
                 end;
             Other -> Other
           end || F <- Forms],
    ok = file:write_file(\"$dst\", [io_lib:format(\"~p.~n\",[F]) || F <- New]),
    halt()."
  erlc +from_abstr +debug_info -o "$CTL" "$dst" 2>/dev/null
  # Capture before grepping: dialyzer exits non-zero when it emits warnings, and
  # under `set -o pipefail` that sinks the whole pipeline even when grep matches.
  local out
  out="$(dialyzer --plt "$PLT" "$CTL/Ctl$name.beam" 2>&1 || true)"
  if printf '%s' "$out" | grep -q "Invalid type specification"; then
    echo "  PASS: $name is caught"
  else
    echo "  FAIL: $name was NOT caught — this check proves nothing" >&2
    exit 1
  fi
}

control WrongReturn ret
control WrongArg    arg

echo
echo "All spec checks passed."
