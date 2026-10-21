# probe NAME EXPECT SRC  -- one directory is one module (F15). Prints bsc's stderr on refusal.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
fails=0
probe () {
    local name=$1 expect=$2 src=$3 out got mark
    mkdir -p "$work/$name"
    printf 'module %s\n%s\n' "$name" "$src" > "$work/$name/a.bs"
    if out=$("$BSC" "$work/$name/a.bs" 2>&1) && [ -z "$out" ]; then got=accepted; else got=refused; fi
    [ "$got" = "$expect" ] && mark="ok " || { mark="!! "; fails=$((fails+1)); }
    printf '%s %-28s %s (expected %s)\n' "$mark" "$name" "$got" "$expect"
    [ "$got" = refused ] && [ -n "${SHOW:-}" ] && printf '%s\n' "$out" | sed 's/^/      | /'
    return 0
}
