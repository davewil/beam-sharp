#!/bin/sh
# Builds base (unpatched HEAD copy) and the five experimental compilers from COPIES of compiler/src.
# Nothing under compiler/ is edited. Output: $W/<variant>/ebin ; conflict counts in $W/<variant>.yecc
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../../.." && pwd)
W=${W:-/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad/work/57}
mkdir -p "$W"
for v in base A Aprod B0 Bn Ba; do
  rm -rf "$W/$v-copy" "$W/$v"
  mkdir -p "$W/$v-copy"; cp -r "$repo/compiler/src" "$W/$v-copy/src"
  [ "$v" = base ] || (cd "$W/$v-copy" && patch -s -p1 < "$here/patches/$v.patch") || exit 1
  "$here/build.sh" "$W/$v-copy/src" "$W/$v" > "$W/$v.build" 2>&1
  grep -o 'conflicts: .*' "$W/$v.build" > "$W/$v.yecc"
  printf '%-6s yecc %s\n' $v "$(cat $W/$v.yecc)"
done
