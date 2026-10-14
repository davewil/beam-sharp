#!/bin/sh
# guard-position probe: does `when n >= -5` count toward exhaustiveness? usage: probe57g.sh BSC_DIR
B=$1; mkdir -p g57/G; cat > g57/G/G.bs <<'EOT'
module G

public atom Sign(int n)

Sign(n) when n >= -5 -> :near
Sign(n) when n < -5  -> :far
EOT
$B/bsc.sh --src-root g57 g57/G </dev/null 2>&1 | head -4
echo "exit-ok"
