# Shared helper for probes 57_*. Source after env.sh. Not a probe itself.
# usage: try BSCBIN NAME 'B# source body'   -> prints "NAME: accepted|refused  <first diag line>"
try () {
    local bsc=$1 name=$2 src=$3 d out
    d=$(mktemp -d "${TMPDIR:-/tmp}/p57.XXXXXX"); mkdir -p "$d/M"
    printf 'module M\n%s\n' "$src" > "$d/M/a.bs"
    if out=$("$bsc" "$d/M" 2>&1) && [ -z "$out" ]; then
        printf '%-34s accepted\n' "$name"
    else
        printf '%-34s refused   %s\n' "$name" "$(printf '%s' "$out" | head -1 | sed 's/^[^ ]*:\([0-9]*\):[0-9]*: error: /L\1 /')"
    fi
    rm -rf "$d"
}
