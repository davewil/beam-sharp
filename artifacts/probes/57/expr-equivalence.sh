#!/usr/bin/env bash
# expr-equivalence.sh — option B changes how `-5` parses EVERYWHERE (guards, bodies, patterns' neighbours),
# not only in a refinement. Evaluate a battery of negative-literal expressions under base and
# optB and require identical answers. Also shows the one place the emitted forms differ.
set -uo pipefail
WORK=${WORK:-/tmp/p57work}; w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
cd "$w"
cat > /tmp/p57-battery.txt <<'S'
-5
- 5
-(5)
--5
-0
5 - -5
-5 - 3
-2 * 3
-2 * -3 + 1
2 * -3
0 - 5
-9223372036854775808
-2147483648 - 1
-5 / 2
-7 % 3
S
for v in base optB optA2; do
  : > "$w/$v.txt"
  while IFS= read -r e; do
    mkdir -p "$w/E"; printf 'module E\npublic int V()\nV() -> %s\n' "$e" > "$w/E/a.bs"
    printf '%-26s => %s\n' "$e" "$("$WORK/$v/bsc" "$w/E" V 2>&1 </dev/null | tail -1)" >> "$w/$v.txt"
  done < /tmp/p57-battery.txt
done
cat "$w/base.txt"
diff -q "$w/base.txt" "$w/optB.txt" >/dev/null && echo "optB: identical to base on all $(wc -l < /tmp/p57-battery.txt) expressions" || { echo "optB DIFFERS:"; diff "$w/base.txt" "$w/optB.txt"; }
diff -q "$w/base.txt" "$w/optA2.txt" >/dev/null && echo "optA2: identical to base (as expected: checker-only change)" || { echo "optA2 DIFFERS:"; diff "$w/base.txt" "$w/optA2.txt"; }
