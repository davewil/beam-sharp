#!/usr/bin/env bash
# Extra probe for v52b (verifier-written): owner_app edge cases the author's probe does not cover.
. /home/user/beam-sharp/artifacts/probes/env.sh
export BSC_EBIN=$PROBE_HOME/variants/v52b/ebin
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
printf -- '-module(mydep).\n-export([answer/0]).\nanswer() -> 42.\n' > $d/mydep.erl
mkdir -p $d/Dep; printf 'module Dep\nusing :mydep {\n    int answer()\n}\npublic int Ask()\nAsk() -> :mydep.answer()\n' > $d/Dep/dep.bs
mk () { mkdir -p "$1"; erlc -o "$1" $d/mydep.erl; }
run () { printf '%-52s' "$1"; shift; env "$@" $BSC $d/Dep Ask 2>&1 | tr '\n' ' ' | cut -c1-230; echo; }
mk $d/l1/mydep/ebin;            run "A rebar3-style dir, no version suffix, declared=mydep" ERL_LIBS=$d/l1 BSC_APPS=mydep
run "A' same, declared=other"                                         ERL_LIBS=$d/l1 BSC_APPS=other
mk $d/l2/mydep-1.0.0-rc-1/ebin; run "B pre-release dir mydep-1.0.0-rc-1, declared=mydep"  ERL_LIBS=$d/l2 BSC_APPS=mydep
mk $d/flat;                     run "C flat dir via -pa style (ERL_FLAGS), declared=mydep" ERL_FLAGS="-pa $d/flat" BSC_APPS=mydep
mk $d/ebin;                     run "D dir literally named ebin at top, declared=mydep"   ERL_FLAGS="-pa $d/ebin" BSC_APPS=mydep
lib=$($PROBE_HOME/mm/env/bin/erl -noshell -eval 'io:format("~s",[code:lib_dir()]),halt().')
echo "lib_dir=$lib"
mk ${lib}2/mydep-1.0.0/ebin;    run "E app under ${lib}2 (string prefix of lib_dir), decl=other" ERL_LIBS=${lib}2 BSC_APPS=other
