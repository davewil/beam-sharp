#!/usr/bin/env bash
# P08: beam size / export table / spec count for N=1,10,100 public functions, 4 modes:
#   none (repo compiler) | thin (alias delegates, with -spec) | thin_nospec (no alias -spec) | dup (duplicate bodies)
# CLAIM (ticket 62 option 2): "Costs two exports per function". REFUTED IF export count does not exactly double (+module_info,+bs@type_atoms).
# Also tests the hidden assumption "a delegating alias is cheap": REFUTED IF thin's beam growth per function exceeds dup's.
. "$(dirname "$0")/lib.sh"; build_alias_compiler || exit 1
W="$SCRATCH/p08"; mkdir -p "$W"
printf "%-4s %-12s %s\n" N mode "bytes (beam; stripped; counts)"
for N in 1 10 100; do
  "$HERE/gen_sz.sh" $N "$W/src"
  for mode in none thin thin_nospec dup; do
    d="$W/out_${N}_$mode"; mkdir -p "$d"
    if [ $mode = none ]; then "$BSC" --src-root "$W/src" -o "$d" "$W/src/Sz$N" >/dev/null 2>"$d/err" || cat "$d/err"
    else BS_ALIAS=$mode "$BSC_ALIAS" --src-root "$W/src" -o "$d" "$W/src/Sz$N" >/dev/null 2>"$d/err" || cat "$d/err"; fi
    printf "%-4s %-12s %s\n" $N $mode "$(escript "$HERE/sizes.escript" "$d/Sz$N.beam")"
  done
done
echo; echo "--- bsc --api output, baseline vs alias compiler (aliases invisible to B#'s own view?)"
"$BSC" --api "$W/src/Sz10" > "$W/api_base.txt" 2>&1; BS_ALIAS=thin "$BSC_ALIAS" --api "$W/src/Sz10" > "$W/api_alias.txt" 2>&1
wc -c "$W/api_base.txt" "$W/api_alias.txt"; cmp "$W/api_base.txt" "$W/api_alias.txt" && echo "api identical"
