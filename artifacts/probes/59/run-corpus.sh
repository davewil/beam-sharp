#!/usr/bin/env bash
# Probe 59-G: blast radius over the shipped corpus. Compile every module under
# compiler/examples with head / narrow / widen and count the beams whose Code
# chunk differs from head's. (Corpus-visible change = the delta touches real programs.)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
"$HERE/build-compilers.sh" "$W/c" >/dev/null
EX="$HERE/../../../compiler/examples"
cat > "$W/code.escript" <<'X'
#!/usr/bin/env escript
main([F]) -> {ok, {_, [{"Code", C}]}} = beam_lib:chunks(F, ["Code"]), io:format("~p ~s~n", [byte_size(C), binary:encode_hex(crypto:hash(md5, C))]).
X
total=0; ok=0
declare -A changed bytes
for v in head narrow widen; do mkdir -p "$W/o/$v"; done
for d in "$EX"/*/ ; do
  m=$(basename "$d"); total=$((total+1))
  good=1
  for v in head narrow widen; do
    "$W/c/$v/bsc" --src-root "$EX" -o "$W/o/$v" "$d" >/dev/null 2>&1 || good=0
  done
  [ $good = 1 ] && ok=$((ok+1)) || echo "  (skipped, did not compile under all three: $m)"
done
echo "example dirs: $total; compiled under all three builds: $ok. Beams below are counted per .beam (one module dir can emit several)."
echo "NOTE: no shipped example has a private function with a record parameter, so the narrow build changing 0 beams is NO evidence about Option B's blast radius."
for v in narrow widen; do
  n=0; delta=0; same=0
  for f in "$W/o/head"/*.beam; do
    b=$(basename "$f"); [ -f "$W/o/$v/$b" ] || continue
    hh=$(escript "$W/code.escript" "$f"); xx=$(escript "$W/code.escript" "$W/o/$v/$b"); h=${hh% *}; x=${xx% *}; hm=${hh#* }; xm=${xx#* }; [ "$hm" = "$xm" ] && same_code="Code chunk BYTE-IDENTICAL (md5 $hm)" || same_code="Code chunk differs ($hm vs $xm)"
    if ! cmp -s <(escript "$HERE/dump.escript" "$f" 2>/dev/null) <(escript "$HERE/dump.escript" "$W/o/$v/$b" 2>/dev/null); then n=$((n+1)); echo "    $v differs in abstract code: $b; Code $h -> $x bytes; $same_code"; delta=$((delta + x - h)); else same=$((same+1)); fi
  done
  echo "  $v: $n beam(s) with different emitted code, $same identical; summed Code-chunk delta vs head = $delta bytes"
done
