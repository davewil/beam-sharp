# Shared helper. Usage: source lib.sh; BSC=path (default: repo bsc)
export PATH=/opt/otp28/bin:$PATH
root=/home/user/beam-sharp
BSC=${BSC:-$root/compiler/_build/default/bin/bsc}
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
# probe NAME SRC [FUNCTION ARGS...]  -> prints verdict + bsc output
probe () {
  local name=$1 src=$2; shift 2
  mkdir -p "$work/$name"; printf 'module %s\n%s\n' "$name" "$src" > "$work/$name/a.bs"
  local out rc; out=$(cd "$work" && "$BSC" "$work/$name/a.bs" "$@" 2>&1); rc=$?
  if [ $rc -eq 0 ] && [ -z "$out" ]; then v=accepted; elif [ $rc -eq 0 ]; then v="accepted(output)"; else v="refused(rc=$rc)"; fi
  printf '%-22s %s\n' "$name" "$v"
  [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/    | /'
  return 0
}
