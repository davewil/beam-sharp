#!/usr/bin/env bash
# P8: can a B# module reach another B# module's function without `using` it, by declaring it foreign?
# If this compiles+runs, ANY check placed at add_module_import/using is bypassable.
BSC=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/bsc
cd "$(dirname "$0")/p8"; O=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/60/out8; rm -rf $O; mkdir -p $O
# Shop.Orders comes from p1's tree
$BSC --src-root ../p1/src -o $O ../p1/src/Shop/Orders; echo "orders exit=$?"
echo "## bypass module, compiled alone"
$BSC --src-root src -o $O src/Shop/Bypass; echo "exit=$?"
export PATH=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/beam/bin:$PATH
erl -noshell -pa $O -eval "io:format(\"~p~n\", ['Shop.Bypass':'Probe'(50)]), halt()."
echo "## CONTROL: foreign block naming a B# module's lowercase callback (Counter.init/1), no 'using Counter'"
$BSC --src-root ../../../../compiler/examples -o $O ../../../../compiler/examples/Counter; echo "counter exit=$?"
$BSC --src-root src -o $O src/Shop/Bypass2; echo "bypass2 exit=$?"
erl -noshell -pa $O -eval "io:format(\"~p~n\", ['Shop.Bypass2':'Probe'(50)]), halt()."
