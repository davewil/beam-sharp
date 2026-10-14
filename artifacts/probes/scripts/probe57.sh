#!/bin/sh
# probe 57: which refinement predicates the checker accepts. usage: probe57.sh BSC_DIR
B=$1; i=0
while IFS= read -r r; do i=$((i+1)); d=M$i; mkdir -p $d
 printf 'module %s\n\ntype T = int where %s\n\npublic atom F(T n)\n\nF(n) -> :ok\n' $d "$r" > $d/$d.bs
 out=$($B/bsc.sh --src-root . $d </dev/null 2>&1 | head -1)
 echo "[$r] => ${out:-ACCEPTED}"
done <<'EOT'
value >= -5
value >= -5 and value <= 5
value >= 1 or value <= -1
value <= 3 or value >= 10
value != 0
value >= 0 - 5
value >= (-5)
value >= 2 + 3
value >= 2 * 3
value > -1
value != -1
EOT
