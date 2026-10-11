#!/usr/bin/env bash
# One command: ./02_gleam_emission.sh -> probes/02_gleam_emission.out
# Claim under test (ticket 62, from ticket 10 sec.7): "Gleam downcases when it emits to the BEAM -- PascalCase becomes snake_case."
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib.sh"
G=$WORK/gl; rm -rf $G; mkdir -p $G; cp -r $HERE/gleam_shop $HERE/gleam_bad $G/
echo "gleam: $(gleam --version)"
echo; echo "=== 1. Gleam SOURCE: PascalCase variants, snake_case functions"; cat $G/gleam_shop/src/shop.gleam
echo; echo "=== 2. gleam build"; (cd $G/gleam_shop && gleam build 2>&1 | tail -2)
echo; echo "=== 3. what the .beam holds"
escript $HERE/show_beam.escript $G/gleam_shop/build/dev/erlang/shop/ebin/shop.beam
echo; echo "=== 4. NEGATIVE CONTROL: does Gleam downcase a PascalCase FUNCTION name, or refuse it?"
(cd $G/gleam_bad && gleam build 2>&1 | head -12)
echo "(a build that produced a beam would show up here:)"; ls $G/gleam_bad/build/dev/erlang/bad/ebin/*.beam 2>&1 | head -2
