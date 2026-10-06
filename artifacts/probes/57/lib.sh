# shared helper for probes 57*. source it. Needs $BSC (see scratchpad env.sh); run from repo root.
: "${BSC:?source the env.sh first}"
: "${WORK:=$(mktemp -d)}"
# probe NAME EXPECT SRC  -> prints "ok/!!  NAME got (expected EXPECT)" and first diagnostic line
fails=0
probe () {
    local name=$1 expect=$2 src=$3 out got mark first
    mkdir -p "$WORK/src/$name"
    printf 'module %s\n%s\n' "$name" "$src" > "$WORK/src/$name/a.bs"
    if out=$($BSC --src-root "$WORK/src" -o "$WORK/o_$name" "$WORK/src/$name" 2>&1) && [ -z "$out" ]; then got=accepted; else got=refused; fi
    first=$(printf '%s\n' "$out" | head -1 | sed "s#$WORK/src/##")
    if [ "$got" = "$expect" ]; then mark="ok"; else mark="!!"; fails=$((fails+1)); fi
    printf '%s  %-22s %-9s (expected %-8s) %s\n' "$mark" "$name" "$got" "$expect" "${first:0:110}"
}
