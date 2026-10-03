#!/usr/bin/env bash
# roundtrip.sh EBIN LABEL -- is the residual the compiler prints for a SIGNED domain
# pasteable?  Take the `no clause matches:` heads verbatim, paste them as clauses,
# recompile; the program must then be exhaustive.  Also shows the JSON `residual`
# (a set description, uses `..`) beside the `pasteable` field.
ebin=$1; label=$2; here=$(cd "$(dirname "$0")" && pwd)
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
echo "## $label"
rt () {  # rt NAME DECL CLAUSE
  mkdir -p "$w/$1"
  printf 'module %s\n%s\npublic atom F(%s d)\n%s\n' "$1" "$2" "$3" "$4" > "$w/$1/a.bs"
  out=$("$here/bsc.sh" "$ebin" "$w/$1" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then echo "$1: first compile ACCEPTED unexpectedly"; return; fi
  heads=$(printf '%s\n' "$out" | grep -E '^ +F\(' | sed 's/^ *//')
  if [ -z "$heads" ]; then echo "$1: no residual printed: $(printf '%s' "$out" | head -1 | sed 's#^[^ ]* ##')"; return; fi
  printf 'module %sR\n%s\npublic atom F(%s d)\n%s\n%s\n' "$1" "$2" "$3" "$4" "$(printf '%s\n' "$heads" | sed 's/ -> \.\.\./ -> :rest/')" > /dev/null
  mkdir -p "$w/${1}R"
  printf 'module %sR\n%s\npublic atom F(%s d)\n%s\n%s\n' "$1" "$2" "$3" "$4" "$(printf '%s\n' "$heads" | sed 's/ -> \.\.\./ -> :rest/')" > "$w/${1}R/a.bs"
  out2=$("$here/bsc.sh" "$ebin" "$w/${1}R" 2>&1); rc2=$?
  printf '%s: printed [%s] ; pasted back -> %s\n' "$1" "$(printf '%s' "$heads" | paste -sd';' | sed 's/ -> \.\.\.//g; s/;/ ; /g')" "$([ $rc2 -eq 0 ] && echo 'COMPILES (exhaustive)' || echo "REFUSED: $(printf '%s' "$out2" | head -2 | tr '\n' ' ' | sed 's#[^ ]*/a.bs#a.bs#')")"
  "$here/bsc.sh" "$ebin" --diagnostics json "$w/$1" 2>&1 | grep -o '"pasteable":\[[^]]*\]\|"residual":"[^"]*"' | head -2 | sed "s/^/    json: /"
}
rt Unb  ''                                                      int   'F(0) -> :zero'
rt Sgn  'type Delta = int where value >= -10 and value <= 10'   Delta 'F(0) -> :zero'
rt Sgn2 'type Delta = int where value >= -10 and value <= 10'   Delta 'F(d) when d > 3 -> :hi'
rt Sgn3 'type Delta = int where value != -3 and value >= -9'    Delta 'F(-9) -> :lo'
