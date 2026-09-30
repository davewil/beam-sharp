# sourced by probes. $BSC = path to bsc.sh; $B = build dir (default /tmp/bsc57)
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BSC=${BSC:-$here/bsc.sh}
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT; cd "$work"   # bsc writes .abstr/.beam into cwd
# probe NAME EXPECT SRC : one module per case; prints accepted/refused + first diagnostic line
probe () {
    local name=$1 expect=$2 src=$3 out got mark
    mkdir -p "$work/$name"
    printf 'module %s\n%s\n' "$name" "$src" > "$work/$name/a.bs"
    if out=$("$BSC" "$work/$name/a.bs" 2>&1) && [ -z "$out" ]; then got=accepted; else got=refused; fi
    mark="ok "; [ "$got" = "$expect" ] || mark="!! "
    printf '%s %-26s %-8s (expected %s)\n' "$mark" "$name" "$got" "$expect"
    if [ "$got" = refused ]; then printf '%s\n' "$out" | sed -n '1,2p;' | sed 's/^/        | /'; fi
}
