#!/usr/bin/env bash
# 57_variants -- the SAME case set (57_cases.sh) on stock, gramA, gramB, gramC, chk.
# Claims tested: (1) both fixes accept the ticket's refused rows R01-R03, R21 and keep R11-R14,
# R22 refused (R22 for its own reason: empty); (2) they DIFFER on R06-R09 and G04 (fold
# boundary); (3) a grammar-side fold changes typing (E01, E03) and the zero-divisor check (D01);
# (4) the checker fold does not (E01, E03 still refused) -- a second site is needed;
# (5) gramC (refinement-only fold) accepts R01 but leaves the SAME literal in a guard unread (G01 refused):
# the split the ticket fears, measured.
# REFUTED by: any "MUST refuse" row reading accepted in a patched build; gramA/gramB/chk columns
# identical on R06-R09/E01/D01 (then the variants do not differ and the choice is only taste).
# usage: 57_variants.sh   (builds the variants into a fresh mktemp dir unless V57 is set)
. "$(dirname "$0")/env.sh"; here=$(cd "$(dirname "$0")" && pwd)
if [ -z "${V57:-}" ]; then V57=$("$here/57_build_variants.sh" | sed -n 's/^export V57=//p'); fi
for v in stock gramA gramB gramC chk; do
  "$here/57_stock.sh" "$V57/$v/_build/default/bin/bsc" > "$V57/$v.txt"
  echo "=== $v"; cat "$V57/$v.txt"
done
echo "=== verdict table (stock | gramA | gramB | gramC | chk)"
for v in stock gramA gramB gramC chk; do sed -E 's/^(.{34}) (accepted|refused).*/\2/' "$V57/$v.txt" > "$V57/$v.col"; done
paste -d'|' <(cut -c1-34 "$V57/stock.txt") "$V57/stock.col" "$V57/gramA.col" "$V57/gramB.col" "$V57/gramC.col" "$V57/chk.col" | awk -F"|" '{printf "%-34s %-9s %-9s %-9s %-9s %-9s\n",$1,$2,$3,$4,$5,$6}'
