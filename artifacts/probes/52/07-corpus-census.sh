#!/usr/bin/env bash
# CLAIM (mine, against variant C = "refuse a `using :m` whose module is not loadable at compile time",
# which needs no new syntax): it would refuse programs the repo ships as valid.
# Two measurements: (a) every foreign `using :atom {` in the repo's .bs corpus and LANGUAGE.md, checked with
# code:which/1 in a plain VM; (b) the repo's compiler/examples compiled by the PROTOTYPE with and without
# the module-presence hook.
# REFUTED IF: every atom in the corpus is loadable in a plain VM (then C refuses nothing), or (b) shows the
# same exit codes with and without the hook.
. "$(dirname "$0")/lib.sh"
cd /home/user/beam-sharp
RX="using\s+:('[^']+'|\"[^\"]+\"|[a-zA-Z_0-9@]+)\s*\{"
tmp=$WORK/census; mkdir -p "$tmp"
echo "### (a) foreign using-atoms by source set (repo files only; this probe's own fixtures excluded)"
for set in "compiler/examples/*.bs compiler/examples/*/*.bs:examples (must compile)" \
           "compiler/examples/exemplars/*/*.bs:exemplars (ticket 25)" \
           "wayfinder/prototypes/*.bs wayfinder/prototypes/*/*.bs wayfinder/prototypes/*/*/*.bs:prototypes"; do
  files=${set%%:*}; label=${set#*:}
  grep -hoE "$RX" $files 2>/dev/null | sed -E "s/using\s+://; s/\s*\{//; s/'//g" | sort -u > "$tmp/$label.txt"
  printf "%-26s %3d distinct atoms\n" "$label" "$(wc -l < "$tmp/$label.txt")"
done
grep -hoE "$RX" LANGUAGE.md | sed -E "s/using\s+://; s/\s*\{//; s/'//g" | sort -u > "$tmp/language.txt"
printf "%-26s %3d distinct atoms\n" "LANGUAGE.md blocks" "$(wc -l < "$tmp/language.txt")"
cat "$tmp"/*.txt | sort -u > "$tmp/all.txt"
echo "### loadable in a plain VM (no ERL_LIBS)?"
env -u ERL_LIBS erl -noshell -eval '
{ok,B}=file:read_file("'$tmp'/all.txt"), As=[list_to_atom(S)||S<-string:tokens(binary_to_list(B),"\n")],
{Ok,Bad}=lists:partition(fun(A)-> code:which(A)=/=non_existing end, As),
io:format("loadable: ~p~nNOT loadable: ~p~n",[Ok,Bad]), halt().'
echo
echo "### (b) PROTOTYPE compiler over compiler/examples, with and without the module-presence hook"
mkdir -p "$WORK/o07"; pass_plain=0; pass_hook=0; total=0
for d in compiler/examples/*/; do
  n=$(basename "$d"); [ "$n" = exemplars ] && continue
  total=$((total+1))
  env -u ERL_LIBS "$PBSC" -o "$WORK/o07" --src-root compiler/examples "$d" >/dev/null 2>&1; a=$?
  env -u ERL_LIBS BS_PROTO_CHECK_MODULES=1 "$PBSC" -o "$WORK/o07" --src-root compiler/examples "$d" >/dev/null 2>&1; b=$?
  [ $a -eq 0 ] && pass_plain=$((pass_plain+1)); [ $b -eq 0 ] && pass_hook=$((pass_hook+1))
  [ $a -ne $b ] && echo "  REFUSED ONLY WITH HOOK: $n (plain exit $a, hook exit $b)"
done
echo "example modules: $total   compile without hook: $pass_plain   compile with hook: $pass_hook"
echo
echo "### (c) a LANGUAGE.md block the language gate (check-language.sh) compiles and expects a SPECIFIC diagnostic from"
echo '###     (using :analytics_db names a module that does not exist anywhere)'
X=$WORK/o07c/Analytics; rm -rf "$WORK/o07c"; mkdir -p "$X"
awk '/<!-- diagnoses: foreign_ret_beyond_one_guard -->/{f=1;next} f&&/^```csharp/{g=1;next} g&&/^```/{exit} g{print}' /home/user/beam-sharp/LANGUAGE.md > "$X/analytics.bs"
sed 's/^/    | /' "$X/analytics.bs" | head -12
echo "--- without hook:"; env -u ERL_LIBS "$PBSC" -o "$WORK/o07c" "$X" 2>&1 | head -3 | cut -c1-140
echo "--- with hook:";    env -u ERL_LIBS BS_PROTO_CHECK_MODULES=1 "$PBSC" -o "$WORK/o07c" "$X" 2>&1 | head -3 | cut -c1-140
