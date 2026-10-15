# usage: . v57_lib.sh ; V57 must be set (dir with stock/ gramA/ ... built variants)
bsc_of () { echo "$V57/$1/_build/default/bin/bsc"; }
# cmp_src NAME 'source' [fn args...] : compile with stock and gramA; if fn given, also run it. Prints one line per build.
cmp_src () {
  local name=$1 src=$2; shift 2; local d; d=$(mktemp -d /tmp/v57x.XXXXXX); mkdir -p $d/M $d/o
  printf 'module M\n%s\n' "$src" > $d/M/a.bs
  for v in ${BUILDS:-stock gramA}; do
    local b out; b=$(bsc_of $v)
    if out=$("$b" -o $d/o "$d/M" 2>&1) && ! grep -q 'error' <<<"$out"; then
      if [ $# -gt 0 ]; then printf '%-30s %-6s accepted run: %s\n' "$name" $v "$("$b" -o $d/o "$d/M" "$@" 2>&1 | tail -1 | cut -c1-90)"
      else printf '%-30s %-6s accepted\n' "$name" $v; fi
    else printf '%-30s %-6s REFUSED %s\n' "$name" $v "$(printf '%s' "$out" | grep -m1 error | sed 's/^[^ ]*:\([0-9]*\):[0-9]*: error: /L\1 /' | cut -c1-110)"; fi
  done; rm -rf $d
}
