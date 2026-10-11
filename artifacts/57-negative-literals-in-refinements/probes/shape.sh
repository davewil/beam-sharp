#!/usr/bin/env bash
# shape.sh : generated-AST shape. (1) parsed term for `-5` per build, with erts_debug sizes;
# (2) .beam byte size and md5 of the code chunk for a module using -5 in expr, guard, pattern, per build.
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
source $S/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p $W/src/Shape $W/out
cat > $W/src/Shape/a.bs <<'X'
module Shape
public int Lit()
Lit() -> -5
public int Calc(int x)
Calc(x) -> x - -5 + -(-2) * -3
public atom Sign(int n)
Sign(-5) -> :five
Sign(n) when n <= -1 -> :neg
Sign(n) -> :other
X
for spec in reference:$S/bsc-ebin A:$S/57/ebin-A B:$S/57/ebin-B Barith:$S/57/ebin-Barith; do
  n=${spec%%:*}; e=${spec#*:}
  echo "== $n"
  erl -noshell -pa $e -eval '
    {ok,T,_} = bs_lexer:string("module M\npublic int F(int x)\nF(x) -> -5\nF2(x) when x >= -5 -> 1\n"),
    {ok,D} = bs_parser:parse(T),
    [C1, C2] = [X || X <- D, element(1,X) =:= clause],
    Body = element(6, C1), {guard, G} = element(5, C2),
    io:format("  body  `-5`        : ~w   flat_size=~p words~n", [Body, erts_debug:flat_size(Body)]),
    io:format("  guard `x >= -5`   : ~w   flat_size=~p words~n", [G, erts_debug:flat_size(G)]),
    halt().' 2>&1 | head -4
  rm -rf $W/out/*; mkdir -p $W/out/o; (cd $W/out/o && erl -noshell -pa $e -run bsc main $W/src/Shape/a.bs -run init stop 2>&1 | head -3)
  printf '  Shape.beam bytes=%s  md5(whole .beam)=%s\n' "$(stat -c %s $W/out/o/Shape.beam)" "$(md5sum < $W/out/o/Shape.beam | cut -c1-12)"
  printf '  Shape.abstr sha  =%s\n' "$(md5sum < $W/out/o/Shape.abstr | cut -c1-12)"
  erl -noshell -eval '{ok,{_,[{"Code",C}]}} = beam_lib:chunks("'$W'/out/o/Shape.beam",["Code"]), io:format("  Code chunk md5=~s bytes=~p~n",[binary:part(base64:encode(crypto:hash(md5,C)),0,12), byte_size(C)]), halt().'
done
