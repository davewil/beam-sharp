#!/usr/bin/env bash
# 13d — Dialyzer on beam-sharp-emitted specs. The tool the specs exist for, finally run.
#
# Ticket 06 recommended emitting `-spec`s; ticket 13 §6 committed to it and built the widening
# rule in `bs_emit:spec_type/1` around what Dialyzer would read, noting that
# `-Wunderspecs`/`-Wspecdiffs` "turn warnings *on* rather than off". Nobody had ever run it.
#
# Sections:
#   1. Does the emitted .beam even carry the spec? With the `.core` path as the negative control —
#      ticket 13 found it loses the spec silently, and this shows how it actually fails.
#   2. Does Dialyzer accept our specs on the default warning set?
#   3. Does it agree? -Wunderspecs / -Woverspecs / -Wspecdiffs.
#   4. POSITIVE CONTROLS. A clean pass proves nothing unless a wrong spec would fail, so two
#      deliberately-broken specs are built from the real .abstr and run through the same command.
#      (Ticket 15 lost a session to a harness that supplied the protection it was measuring.)
#   5. The widening rule, in the direction that would flag it — plus a hand-written Erlang control
#      that isolates *why* -Wunderspecs cannot see beam-sharp's widening.
#   6. The same across the pinned OTP range, since 13c proved the range and this is nearly free.
#
# Usage:  ./13d_dialyzer_on_emitted_specs.sh [--no-docker]
# Needs:  a built compiler (rebar3 escriptize in compiler/), dialyzer on PATH, docker for §6.

set -u
cd "$(dirname "$0")/../.."                      # repo root

NODOCKER=${1:-}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
PLT=$WORK/base.plt

BSC=compiler/_build/default/bin/bsc
[ -x "$BSC" ] || ( cd compiler && rebar3 escriptize >/dev/null 2>&1 )

echo "=== environment ==="
erl -noshell -eval 'io:format("  OTP ~s~n",[erlang:system_info(otp_release)]), halt(0).'
printf '  building base PLT over erts/kernel/stdlib ... '
t0=$(date +%s)
dialyzer --build_plt --apps erts kernel stdlib --output_plt "$PLT" >/dev/null 2>&1
echo "$(( $(date +%s) - t0 ))s"

dial() { dialyzer --plt "$PLT" "$@" 2>&1 | sed -n '/Proceeding with analysis/,$p' | sed 's/^/    /'; }

# ---------------------------------------------------------------------------------------
echo
echo "=== 1. does the emitted .beam carry the spec? ==="
"$BSC" -o "$WORK" compiler/examples/readings.bs compiler/examples/math.bs >/dev/null 2>&1

cat > "$WORK/chunk.escript" <<'ESCRIPT'
#!/usr/bin/env escript
main([Beam]) ->
    {ok, {M, [{abstract_code, AC}]}} = beam_lib:chunks(Beam, [abstract_code]),
    case AC of
        {raw_abstract_v1, Fs} ->
            io:format("~-10s raw_abstract_v1, ~p forms, ~p spec(s)~n",
                      [M, length(Fs), length([S || S = {attribute,_,spec,_} <- Fs])]);
        no_abstract_code ->
            io:format("~-10s NO ABSTRACT CODE~n", [M])
    end.
ESCRIPT

printf '  abstract-format path: '; escript "$WORK/chunk.escript" "$WORK/Readings.beam"

# Negative control: ticket 13's `.core` finding, reproduced.
mkdir -p "$WORK/core" && cp "$WORK/Readings.abstr" "$WORK/core/"
( cd "$WORK/core" \
  && erlc +from_abstr +to_core Readings.abstr >/dev/null 2>&1 \
  && erlc +from_core +debug_info -o . Readings.core >/dev/null 2>&1 )
printf '  via .core           : '; escript "$WORK/chunk.escript" "$WORK/core/Readings.beam"
echo "  and Dialyzer on the .core-built beam:"
dial "$WORK/core/Readings.beam" | head -4

# ---------------------------------------------------------------------------------------
echo
echo "=== 2. Dialyzer on our beams, default warning set ==="
dial "$WORK/Readings.beam" "$WORK/Math.beam"

echo
echo "=== 3. does it agree? ==="
for w in -Wunderspecs -Woverspecs -Wspecdiffs; do
  echo "  --- $w"
  dial $w "$WORK/Readings.beam" "$WORK/Math.beam"
done

# ---------------------------------------------------------------------------------------
echo
echo "=== 4. positive controls: would a wrong spec actually fail? ==="
python3 - "$WORK" <<'PY'
import sys, pathlib
w = pathlib.Path(sys.argv[1])
src = (w / "Readings.abstr").read_text()

ret = """{type,0,union,
               [{atom,0,negative},
                {atom,0,positive},
                {atom,0,unknown},
                {atom,0,zero}]}"""
arg = """{type,0,union,
                    [{type,0,tuple,[{atom,0,ok},{type,0,integer,[]}]},
                     {type,0,tuple,[{atom,0,error},{type,0,atom,[]}]}]}"""
assert ret in src and arg in src, "the emitted shape changed; update 13d's controls"

(w / "WrongRet.abstr").write_text(
    src.replace(ret, "{type,0,integer,[]}").replace("module,'Readings'", "module,'WrongRet'"))
(w / "WrongArg.abstr").write_text(
    src.replace(arg, "{type,0,atom,[]}").replace("module,'Readings'", "module,'WrongArg'"))
PY
( cd "$WORK" && erlc +from_abstr +debug_info -o . WrongRet.abstr WrongArg.abstr )
echo "  --- a spec whose RETURN is wrong (default warnings):"
dial "$WORK/WrongRet.beam"
echo "  --- a spec whose ARGUMENT is wrong (default warnings):"
dial "$WORK/WrongArg.beam"

# ---------------------------------------------------------------------------------------
echo
echo "=== 5. the widening rule, in the direction that would flag it ==="
cat > "$WORK/widen.bs" <<'BS'
// The declared return type is the atom top; the body only ever returns :ok. That is
// bs_emit's atom_parts({cofinite,_}) branch — the widening ticket 13 §6 names explicitly.
module Widen;

atom Always(int n);

Always(n) -> :ok;
BS
"$BSC" -o "$WORK" "$WORK/widen.bs" >/dev/null 2>&1
printf '  emitted return type: '; grep -o "{type,0,atom,\[\]}" "$WORK/Widen.abstr" | tail -1
for w in -Wunderspecs -Wspecdiffs; do
  echo "  --- $w on the widened spec"
  dial $w "$WORK/Widen.beam"
done

echo
echo "  Hand-written Erlang control, isolating why -Wunderspecs stays quiet above:"
cat > "$WORK/wctl.erl" <<'ERL'
-module(wctl).
-export([narrow_dom/1, same_dom/1]).

%% domain NARROWER than the success typing, range WIDER. beam-sharp's shape, because
%% ticket 04 makes signatures mandatory so the domain is always declared.
-spec narrow_dom(integer()) -> atom().
narrow_dom(_N) -> ok.

%% domain IDENTICAL, range wider only. Isolates the range comparison.
-spec same_dom(any()) -> atom().
same_dom(_N) -> ok.
ERL
erlc +debug_info -o "$WORK" "$WORK/wctl.erl"
echo "  --- -Wunderspecs"; dial -Wunderspecs "$WORK/wctl.beam"

# ---------------------------------------------------------------------------------------
[ "$NODOCKER" = "--no-docker" ] && exit 0
echo
echo "=== 6. across the OTP range 13c proved ==="
for v in 26 27; do
  echo "  --- OTP $v (arm64), rebuilt from the same .abstr"
  docker run --rm --platform linux/arm64 -v "$WORK:/w" -w /tmp "erlang:$v" bash -c '
    erlc +from_abstr +debug_info -o /tmp /w/Readings.abstr /w/Math.abstr /w/WrongRet.abstr
    dialyzer --build_plt --apps erts kernel stdlib --output_plt /tmp/p.plt >/dev/null 2>&1
    printf "      correct specs: "
    dialyzer --plt /tmp/p.plt /tmp/Readings.beam /tmp/Math.beam 2>&1 | tail -1
    printf "      wrong-return control: "
    dialyzer --plt /tmp/p.plt /tmp/WrongRet.beam 2>&1 | grep -c "Invalid type specification" \
      | sed "s/^/warnings=/"
  '
done
