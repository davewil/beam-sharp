#!/usr/bin/env bash
# p06 driver: the modelled check against three programs, with libdep reachable and not.  Needs build-bsc.sh,
# build_parser_b.sh and /tmp/mixdeps52b (brief.md Reproduce).  my_helper.erl exists as SOURCE beside the project
# but is not yet compiled, which is the build-order case.
cd "$(dirname "$0")"
mkdir -p /tmp/helper52 && printf -- '-module(my_helper).\n-export([twice/1]).\ntwice(N) -> N * 2.\n' > /tmp/helper52/my_helper.erl
P="programs/Dep/dep.bs programs/Wrong/wrong.bs programs/NoApp/noapp.bs"
echo '=== libdep REACHABLE (ERL_LIBS=.../_build/dev/lib)'
ERL_LIBS=/tmp/mixdeps52b/consumer/_build/dev/lib escript p06_prototype_check.escript $P
echo
echo '=== libdep NOT reachable (ERL_LIBS unset)'
env -u ERL_LIBS escript p06_prototype_check.escript $P
echo
echo '=== the build-order case: /tmp/helper52/my_helper.erl exists, is not compiled yet'
env -u ERL_LIBS erl -noshell -eval 'io:format("code:which(my_helper) = ~p   source present: ~p~n", [code:which(my_helper), filelib:is_file("/tmp/helper52/my_helper.erl")]), halt().'
