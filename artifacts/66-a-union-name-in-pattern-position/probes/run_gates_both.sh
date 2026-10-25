#!/usr/bin/env bash
# Copy the repo (minus .git, artifacts) twice, put a shim `bsc` escript at compiler/_build/default/bin/bsc pointing at
# (base) the stock HEAD build and (promo) the build with vacuous_clause promoted to error, run every compiler/bin/check-*.sh
# (no --self-test) in each copy and tabulate exit codes. A DIFFERING row is a gate the promotion would turn red.
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
export PATH=$S/beam/bin:$PATH LANG=C.UTF-8
for v in base:$S/bsc-build promo:$S/66/promo; do
  n=${v%%:*}; d=${v#*:}; R=$S/66/gt_$n; rm -rf $R; mkdir -p $R
  ( cd /home/user/beam-sharp && tar --exclude=.git --exclude=artifacts --exclude=aoc --exclude=compiler/_build -cf - . ) | tar -xf - -C $R
  mkdir -p $R/compiler/_build/default/bin
  printf '#!/usr/bin/env bash\nexport PATH=%s/beam/bin:$PATH LANG=C.UTF-8\nexec erl -noshell -pa %s/ebin -eval "bsc:main(init:get_plain_arguments()), halt(0)." -extra "$@"\n' $S $d > $R/compiler/_build/default/bin/bsc
  chmod +x $R/compiler/_build/default/bin/bsc
done
for g in $(ls /home/user/beam-sharp/compiler/bin/check-*.sh | xargs -n1 basename); do
  for n in base promo; do
    ( cd $S/66/gt_$n/compiler && timeout 600 bash bin/$g > $S/66/gt_$n/$g.log 2>&1; echo $? > $S/66/gt_$n/$g.rc ) &
  done
  wait
  printf '%-34s base=%s promo=%s\n' $g "$(cat $S/66/gt_base/$g.rc)" "$(cat $S/66/gt_promo/$g.rc)"
done
