#!/bin/sh
# usage: run_d.sh WORKDIR  (WORKDIR holds base/proto/wide compilers built by ../build-bsc.sh)
cd "$(dirname "$0")"; W=$1
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
quiet() { grep -v '^%\|^$\|^ ' || true; }
for v in base wide proto; do rm -rf out-$v; ../bsc-run.sh $W/$v/ebin -o out-$v Elide 2>&1 | quiet; done
for v in base wide; do echo "######## BEAM asm, compiler=$v"; ../dump.escript out-$v/Elide.beam asm OnlyLit AfterTest Unproven Mid IntFromProven IntUnproven | grep -v 'line\|func_info\|^$'; done
echo "######## JIT (x86_64) native listing, +JDdump true: native instruction lines per function (comments, .db, align excluded)"
for v in base proto wide; do rm -rf $W/jit-$v; mkdir -p $W/jit-$v; cp out-$v/Elide.beam $W/jit-$v/
  ( cd $W/jit-$v; erl +JDdump true -noshell -eval "code:load_file('Elide'), halt()." > /dev/null 2>&1 )
  echo "compiler=$v"
  awk '/^# .Elide.:/{name=$2; next} /^#|^\.db|^ *$|^ *align|^L[0-9]+:/{next} name!=""{n[name]++} END{for(k in n) printf "   %-26s %d\n", k, n[k]}' $W/jit-$v/Elide.asm | sort
done
echo "######## JIT listing of Unproven/1 (base) -- the tag test: is_map + header check + map_get helper call + cmp"
awk '/^# .Elide.:.Unproven.\/1/{p=1; next} /^# .Elide.:/{p=0} p' $W/jit-base/Elide.asm | sed -n '/^.Unproven.\/1:/,$p' | head -45
