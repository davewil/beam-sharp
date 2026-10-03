#!/bin/sh
# p09: would a compile-time "module is on the code path" check refuse anything that compiles today?
# Baseline = the repo's real compiler (scratchpad build of compiler/src); check = PROTOTYPE BS52=module.
# Both run with NO ERL_LIBS, i.e. a build machine that has OTP and nothing else.
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
HERE=$(cd "$(dirname "$0")" && pwd)
"$HERE/../proto/build.sh" /tmp/bs52_proto >/dev/null 2>&1 || exit 1
REPO=/home/user/beam-sharp
REAL=/tmp/claude-0/-home-user-beam-sharp/41c7fa9e-39c6-543b-8f3d-dee4a7daa0ba/scratchpad/bsc.sh
P="$HERE/../proto/bsc52.sh"
W=$(mktemp -d); same=0; diff=0
check() { # dir srcroot
  rm -rf $W/a $W/b; mkdir $W/a $W/b
  ( cd $W/a; env -u ERL_LIBS $REAL --src-root "$2" "$1" >/dev/null 2>&1; echo $? > ../a.rc )
  ( cd $W/b; env -u ERL_LIBS BS52=module "$P" --src-root "$2" "$1" > ../b.out 2>&1; echo $? > ../b.rc )
  A=$(cat $W/a.rc); B=$(cat $W/b.rc)
  if [ "$A" = "$B" ]; then same=$((same+1)); else diff=$((diff+1)); echo "DIFFERS: $1 baseline rc=$A  module-check rc=$B"; head -3 $W/b.out | sed 's/^/    /'; fi
}
for d in $REPO/compiler/examples/*/; do n=$(basename $d); [ "$n" = exemplars ] && continue; check "$d" "$REPO/compiler/examples"; done
echo "compiler/examples/*: same result under the check: $same   different: $diff"
echo "--- the two corpus modules that name a library not on this machine:"
for d in $REPO/wayfinder/prototypes/51a-code-path/Req $REPO/wayfinder/prototypes/51a-code-path/Elx; do check "$d" "$REPO/wayfinder/prototypes/51a-code-path"; done
