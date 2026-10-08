# Shared probe helper. BSC_EBIN points at a built bsc ebin dir (default: scratch OTP25 build, see artifacts/BUILD-NOTE.md).
BSC_EBIN=${BSC_EBIN:-/tmp/bsbuild/ebin}
bsc() { erl -noshell -pa "$BSC_EBIN" -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra "$@"; }
# probe NAME EXPECT SRC : one module per directory (F15)
probe() {
  local name=$1 expect=$2 src=$3 out got
  local d; d=$(mktemp -d); mkdir -p "$d/$name"
  printf 'module %s\n%s\n' "$name" "$src" > "$d/$name/a.bs"
  out=$(cd "$d" && bsc "$name/a.bs" 2>&1) || true
  if [ -z "$out" ]; then got=accepted; else got=refused; fi
  printf '%-4s %-26s %-8s (expected %s)\n' "$([ "$got" = "$expect" ] && echo ok || echo '!!')" "$name" "$got" "$expect"
  [ "$got" = refused ] && echo "$out" | sed 's/^/       | /' | head -4
  rm -rf "$d"
}
