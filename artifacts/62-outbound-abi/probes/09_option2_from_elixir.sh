#!/usr/bin/env bash
# One command: ./09_option2_from_elixir.sh -> .out ; what Elixir gets when the (patched) compiler emits snake_case aliases.
# Control: the same Elixir file against the STOCK compiler (no aliases) must fail on the snake_case lines.
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/lib.sh"
"$HERE/patch_emit.sh" >/dev/null || exit 1
mkdir -p $WORK/alias $WORK/stock
BS_ALIAS_MODE=forward BSC_EBIN=$S/62/csrc-ebin bsc --src-root $HERE/bs -o $WORK/alias $HERE/bs/Abi
bsc --src-root $HERE/bs -o $WORK/stock $HERE/bs/Abi
echo "=== patched compiler (aliases on)"; BS_EBIN=$WORK/alias elixir $HERE/09_option2_from_elixir.exs 2>&1
echo; echo "=== CONTROL: stock compiler"; BS_EBIN=$WORK/stock elixir $HERE/09_option2_from_elixir.exs 2>&1
