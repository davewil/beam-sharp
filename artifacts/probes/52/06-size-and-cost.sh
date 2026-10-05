#!/usr/bin/env bash
# MEASUREMENTS. (1) beam bytes with and without the `bs_requires` attribute, (2) cost of the compile-time
# check as a microbenchmark and end-to-end.
# CLAIM (mine): the attribute costs tens of bytes per entry; the check costs microseconds, far below bsc's
# VM start-up.   REFUTED IF: the delta is > 1% of a small module's beam, or the check adds > 5 ms per compile,
# or lib_dir/1 cost grows with the number of apps on the path enough to matter (>100 us at 500 apps).
. "$(dirname "$0")/lib.sh"
G=$WORK/gen; F=$WORK/fakeapps; O=$WORK/o06; rm -rf "$G" "$F" "$O"; mkdir -p "$G" "$O"
for a in req finch mint jason; do mkdir -p "$F/$a/ebin"; done
export ERL_LIBS=$F:$MYLIBS
bash "$ROOT/gen_shop.sh" "$G/none/Req10"   Req10 none
bash "$ROOT/gen_shop.sh" "$G/using/Req10"  Req10 using
bash "$ROOT/gen_shop.sh" "$G/module/Req10" Req10 module
echo "### (1) beam size, 10 usings over 4 apps (Req-shaped), patched bsc"
for m in none using module; do mkdir -p "$O/$m"; "$PBSC" -o "$O/$m" "$G/$m/Req10" >/dev/null; printf "%-8s %6d bytes\n" "$m" "$(stat -c %s "$O/$m/Req10.beam")"; done
# the repo's own, unpatched bsc on the unmarked source: the baseline is the same compiler minus the patch
mkdir -p "$O/repo"; bsc -o "$O/repo" "$G/none/Req10" >/dev/null; printf "%-8s %6d bytes  (repo bsc, no patch)\n" repo "$(stat -c %s "$O/repo/Req10.beam")"
echo "ShopA/ShopB (2 usings, 1 app):"
for p in ShopC ShopA ShopB; do "$PBSC" -o "$O" "$BS/$p" >/dev/null 2>&1; printf "%-8s %6d bytes\n" "$p" "$(stat -c %s "$O/$p.beam")"; done
echo "for scale: beam sizes of the repo's own shipped examples (repo bsc, no markers)"
for d in Shop Ledger Counter Intake Foreign; do mkdir -p "$O/ex$d"; ( cd /home/user/beam-sharp/compiler && env -u ERL_LIBS bsc -o "$O/ex$d" examples/$d >/dev/null 2>&1 ); for b in "$O/ex$d"/*.beam; do printf "  %-10s %6d bytes\n" "$(basename "$b" .beam)" "$(stat -c %s "$b")"; done; done
echo "attribute payload as stored (term_to_binary size):"
erl -noshell -eval '
P=[{req,'"'"'Elixir.Req'"'"'},{req,'"'"'Elixir.Req.Request'"'"'},{req,'"'"'Elixir.Req.Response'"'"'},{req,'"'"'Elixir.Req.Steps'"'"'},{finch,'"'"'Elixir.Finch'"'"'},{finch,'"'"'Elixir.Finch.Request'"'"'},{mint,'"'"'Elixir.Mint.HTTP'"'"'},{mint,'"'"'Elixir.Mint.Types'"'"'},{jason,'"'"'Elixir.Jason'"'"'},{jason,'"'"'Elixir.Jason.Encoder'"'"'}],
io:format("per-using (10 pairs): ~p bytes~n per-module (4 atoms)   : ~p bytes~n",[byte_size(term_to_binary(P)), byte_size(term_to_binary([req,finch,mint,jason]))]), halt().'
echo
echo "### (2a) microbenchmark of the candidate checks, inside one escript VM (bsc is one)"
mkdir -p "$WORK/many"; for i in $(seq 1 500); do mkdir -p "$WORK/many/app$i/ebin"; done
ERL_LIBS=$WORK/many:$MYLIBS:$F escript "$ROOT/bench.escript"
echo
echo "### (2b) end to end: patched bsc compiling the 10-using program, 40 alternating runs each (ms)"
runs=40; declare -a A B
for i in $(seq 1 $runs); do
  t0=$(date +%s%N); "$PBSC" -o "$O/none"  "$G/none/Req10"  >/dev/null; t1=$(date +%s%N); A+=( $(( (t1-t0)/1000 )) )
  t0=$(date +%s%N); "$PBSC" -o "$O/using" "$G/using/Req10" >/dev/null; t1=$(date +%s%N); B+=( $(( (t1-t0)/1000 )) )
done
stat_() { printf '%s\n' "$@" | sort -n | awk '{a[NR]=$1; s+=$1} END{printf "n=%d min=%.1f median=%.1f mean=%.1f max=%.1f ms\n", NR, a[1]/1000, a[int((NR+1)/2)]/1000, s/NR/1000, a[NR]/1000}'; }
echo "no markers (no check)   : $(stat_ "${A[@]}")"
echo "10 markers (10 checks)  : $(stat_ "${B[@]}")"
