#!/usr/bin/env bash
# Same as run_gates_both.sh but for the build with ALL SEVEN dead-code warnings promoted (clause x3, arm x3, generator).
# Needs run_gates_both.sh to have run first (compares to gt_base rc files).
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
export PATH=$S/beam/bin:$PATH LANG=C.UTF-8
R=$S/66/gt_promoall; rm -rf $R; mkdir -p $R
( cd $S/66/gt_base && tar --exclude=compiler/_build -cf - . 2>/dev/null ) | tar -xf - -C $R
mkdir -p $R/compiler/_build/default/bin
printf '#!/usr/bin/env bash\nexport PATH=%s/beam/bin:$PATH LANG=C.UTF-8\nexec erl -noshell -pa %s/66/promoall/ebin -eval "bsc:main(init:get_plain_arguments()), halt(0)." -extra "$@"\n' $S $S > $R/compiler/_build/default/bin/bsc; chmod +x $R/compiler/_build/default/bin/bsc
for g in $(ls /home/user/beam-sharp/compiler/bin/check-*.sh | xargs -n1 basename); do
  ( cd $R/compiler && timeout 600 bash bin/$g > $R/$g.log 2>&1; echo $? > $R/$g.rc )
  printf '%-34s base=%s promoall=%s\n' $g "$(cat $S/66/gt_base/$g.rc)" "$(cat $R/$g.rc)"
done
