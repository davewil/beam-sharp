#!/bin/bash
# S2: Elixir 1.14.0. @moduledoc false / @doc false hide from DOCS only; defp is the only compile-enforced hiding.
D=$(mktemp -d); S=$(dirname "$(readlink -f "$0")")/s2_src; cp $S/hidden.ex $D/; cp $S/ctl.ex $D/
mkdir $D/ebin
(cd $D && elixirc -o ebin hidden.ex 2>&1 | head -5; echo "elixirc hidden.ex exit: ${PIPESTATUS[0]}")
(cd $D && elixir -pa ebin $S/run.exs 2>&1 | head -12)
echo "--- control: calling the defp from another module"
(cd $D && elixirc -o ebin -pa ebin ctl.ex 2>&1 | head -6; echo "elixirc ctl.ex exit: ${PIPESTATUS[0]}")
rm -rf $D
