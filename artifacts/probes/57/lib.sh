# shared: try NAME 'source' -> prints exit code and first diagnostic line, for a bsc binary in $BSC
try() { d=$(mktemp -d)/$1; mkdir -p $d; printf 'module %s\n%s\n' "$1" "$2" > $d/a.bs
  out=$("$BSC" $d/a.bs 2>&1); rc=$?
  printf 'rc=%d  %s\n' $rc "$(echo "$2" | head -1 | cut -c1-70)"; [ -n "$out" ] && echo "$out" | sed -n '1,2p;' | sed 's/^/        /' | cut -c1-150; return 0; }
