#!/usr/bin/env bash
# One command: ./07_naming_rules.sh -> probes/07_naming_rules.out
# Part 1: candidate PascalCase->snake_case rules on acronyms (and the REAL Macro.underscore / REAL Gleam for ground truth).
# Part 2: collisions the derived alias creates, shown with the patched compiler against the stock compiler.
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib.sh"
"$HERE/patch_emit.sh" >/dev/null || exit 1
echo "=== 1a. three candidate rules (A = simple, B = Elixir Macro.underscore, C = every capital is a word break)"
escript $HERE/rules.escript $S/62/csrc-ebin
echo; echo "=== 1b. ground truth for B: the REAL Elixir Macro.underscore"
elixir -e 'for s <- ~w(New NewHTTP ParseURL HTTPServer XMLHttpRequest ToJson OKResult V2Parse Parse2D Parse2d GetURLFor NewUrl NewURL IOList Id A AB), do: IO.puts(String.pad_trailing(s, 16) <> " " <> Macro.underscore(s))' 2>&1
echo; echo "=== 1c. ground truth for C: REAL gleam compiling these as VARIANT names (functions cannot be PascalCase in Gleam, probe 02)"
G=$WORK/gl; rm -rf $G; mkdir -p $G/r/src; cat > $G/r/gleam.toml <<'EOT'
name = "r"
version = "1.0.0"
target = "erlang"
EOT
cat > $G/r/src/r.gleam <<'EOT'
pub type T { New NewHTTP ParseURL HTTPServer XMLHttpRequest ToJson OKResult V2Parse Parse2D Parse2d GetURLFor NewUrl NewURL IOList Id A AB }
EOT
(cd $G/r && gleam build >/dev/null 2>&1); escript $HERE/spec_beam.escript $G/r/build/dev/erlang/r/ebin/r.beam | tr -s ' \n' ' '; echo
echo; echo "=== 2. collisions the alias creates (stock compiler vs patched with BS_ALIAS_MODE=forward)"
for m in Col2 Col3 Col5 Col6; do
  l=$(echo $m | tr A-Z a-z); echo "--- $m: $(grep -v '^$' $HERE/bs_collide/$m/$l.bs | tr '\n' ' ' | cut -c1-150)"
  mkdir -p $WORK/o/$m $WORK/p/$m
  echo "  stock  : $(bsc -o $WORK/o/$m $HERE/bs_collide/$m 2>&1 | sed "s#$HERE/##; s#$WORK/##g" | head -3 | tr '\n' '|') beam: $(ls $WORK/o/$m/*.beam 2>/dev/null | wc -l)"
  echo "  patched: $(BS_ALIAS_MODE=forward BSC_EBIN=$S/62/csrc-ebin bsc -o $WORK/p/$m $HERE/bs_collide/$m 2>&1 | sed "s#$HERE/##; s#$WORK/##g" | head -4 | tr '\n' '|') beam: $(ls $WORK/p/$m/*.beam 2>/dev/null | wc -l)"
done
