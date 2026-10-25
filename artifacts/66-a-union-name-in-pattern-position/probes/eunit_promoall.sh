#!/usr/bin/env bash
# eunit under the all-seven-dead-code-warnings-promoted compiler; lists failures beyond the stock baseline (9 env failures).
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
export PATH=$S/beam/bin:$PATH LANG=C.UTF-8
P="$(cd "$(dirname "$0")" && pwd)"
R=$S/66/tree_promoall; rm -rf $R; mkdir -p $R; cp -r /home/user/beam-sharp/compiler/{examples,test,bin,features,README.md} $R/; mkdir -p $R/_build/default/bin
printf '#!/usr/bin/env bash\nexport PATH=%s/beam/bin:$PATH LANG=C.UTF-8\nexec erl -noshell -pa %s/66/promoall/ebin -eval "bsc:main(init:get_plain_arguments()), halt(0)." -extra "$@"\n' $S $S > $R/_build/default/bin/bsc; chmod +x $R/_build/default/bin/bsc
mods=$(ls $R/test/*.erl | xargs -n1 basename | sed 's/\.erl//' | grep -v support | tr '\n' ',' | sed 's/,$//')
( cd $R; erl -noshell -pa $S/66/promoall/ebin -pa $S/66/testbin -eval "eunit:test([$mods],[verbose]), halt(0)." > $P/eunit_full_promoall.raw 2>&1 )
grep -E '\*failed\*' $P/eunit_full_promoall.raw | sed 's/\.\.\..*//' | sort > $P/eunit_full_failed_promoall.txt
tail -n 2 $P/eunit_full_promoall.raw; diff $P/eunit_full_failed_base.txt $P/eunit_full_failed_promoall.txt | grep '^>' 
