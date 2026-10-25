#!/usr/bin/env bash
# Only the test modules that went red under the other promotions (bindings columns comprehension diagnostic_json diagnostic_term
# down_view float heads switch), run against the 3c build; the full-suite run (eunit_promonamed.sh) is slow here.
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
export PATH=$S/beam/bin:$PATH LANG=C.UTF-8
P="$(cd "$(dirname "$0")" && pwd)"
R=$S/66/tree_promonamed2; rm -rf $R; mkdir -p $R; cp -r /home/user/beam-sharp/compiler/{examples,test,bin,features,README.md} $R/; mkdir -p $R/_build/default/bin
printf '#!/usr/bin/env bash\nexport PATH=%s/beam/bin:$PATH LANG=C.UTF-8\nexec erl -noshell -pa %s/66/promonamed/ebin -eval "bsc:main(init:get_plain_arguments()), halt(0)." -extra "$@"\n' $S $S > $R/_build/default/bin/bsc; chmod +x $R/_build/default/bin/bsc
( cd $R; erl -noshell -pa $S/66/promonamed/ebin -pa $S/66/testbin -eval "eunit:test([bindings_tests,columns_tests,comprehension_tests,diagnostic_json_tests,diagnostic_term_tests,down_view_tests,float_tests,heads_tests,switch_tests],[verbose]), halt(0)." > $P/eunit_subset_promonamed.raw 2>&1 )
grep -E '\*failed\*' $P/eunit_subset_promonamed.raw | sed 's/\.\.\..*//' | sort
tail -n 2 $P/eunit_subset_promonamed.raw
