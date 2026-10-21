#!/usr/bin/env bash
# Ticket 52 (prototype B, patches/52a+52b): compare the `using` modules against the application list the build
# already declares (BSC_APPS stands in for rebar.config's / .app.src's `applications`). No source syntax added.
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
mkdir -p $d/libs/mydep-1.0.0/ebin $d/Dep
printf -- '-module(mydep).\n-export([answer/0]).\nanswer() -> 42.\n' > $d/mydep.erl
erlc -o $d/libs/mydep-1.0.0/ebin $d/mydep.erl
printf '{application,mydep,[{vsn,"1.0.0"},{modules,[mydep]},{registered,[]},{applications,[kernel,stdlib]}]}.\n' > $d/libs/mydep-1.0.0/ebin/mydep.app
cat > $d/Dep/dep.bs <<'X'
module Dep
using :mydep {
    int answer()
}
using :lists {
    int sum(list<int> xs)
}
using :erlang {
    int abs(int n)
}
public int Ask()
Ask() -> :mydep.answer() + :lists.sum([1, 2]) + :erlang.abs(-1)
X
export BSC_EBIN=$PROBE_HOME/variants/${1:-v52b}/ebin
run () { printf '%-44s' "$1"; shift; env "$@" $BSC $d/Dep Ask 2>&1 | tr '\n' ' ' | cut -c1-210; echo; }
run "libs on path, BSC_APPS unset"            ERL_LIBS=$d/libs
run "libs on path, BSC_APPS=mydep"            ERL_LIBS=$d/libs BSC_APPS=mydep
run "libs on path, BSC_APPS= (declared none)" ERL_LIBS=$d/libs BSC_APPS=
run "libs NOT on path, BSC_APPS=mydep"        BSC_APPS=mydep
