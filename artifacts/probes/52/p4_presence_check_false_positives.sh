#!/usr/bin/env bash
# Ticket 52: prototype of "check at compile time that a foreign `using` module is on the code path".
# Question measured: over the repo's own examples, how many programs that compile today would this REFUSE?
# Usage: BSC_HEAD=<bsc> BSC_VARIANT=<bsc patched with variant_presence_check.patch> bash p4_presence_check_false_positives.sh
set -u; here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../../.." && pwd)
H=${BSC_HEAD:?}; V=${BSC_VARIANT:?}; ex=$root/compiler/examples
echo "otp: $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')"
printf '%-34s %-8s %-8s %s\n' module HEAD variant "diagnostic (variant)"
n=0; flipped=0
for d in $(find "$ex" -name '*.bs' -not -path '*/exemplars/*' -printf '%h\n' | sort -u); do
  n=$((n+1)); rel=${d#$ex/}
  "$H" --src-root "$ex" -o "$(mktemp -d)" "$d" >/dev/null 2>&1; h=$?
  out=$("$V" --src-root "$ex" -o "$(mktemp -d)" "$d" 2>&1); v=$?
  if [ $h -ne $v ]; then flipped=$((flipped+1)); printf '%-34s %-8s %-8s %s\n' "$rel" "exit $h" "exit $v" "$(echo "$out" | head -1 | sed 's/^.*error: //')"; fi
done
echo "modules compared: $n   flipped from accepted to refused by the check: $flipped"

echo
echo "== every distinct foreign module the corpus names (examples AND exemplars; exemplars do not compile in their checked-in layout, ENG-446, so they are checked by lookup, not by compile)"
grep -rhoE "^using :('[^']+'|[a-z_A-Z0-9]+)" "$ex" | sed -E "s/^using ://; s/'//g" | sort | uniq -c | sort -rn > /tmp/foreign_mods.txt
while read -r cnt mod; do
  r=$(erl -noshell -eval 'M=list_to_atom("'"$mod"'"), io:format("~p",[case code:which(M) of non_existing -> absent; _ -> present end]), halt().' </dev/null)
  printf '%4s  %-14s %s\n' "$cnt" "$mod" "$r"
done < /tmp/foreign_mods.txt
