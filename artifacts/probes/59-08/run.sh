#!/usr/bin/env bash
# Survey: do Elixir's stdlib authors put type-test guards / struct matches on PRIVATE (defp) heads
# as often as on public (def) heads? Crude line-based grep; counts clause HEADS (one line, `do`/`->`-less).
set -u
L=/nix/store/pp8kbll8n2778kdm3b3bihjj3nnrrvh3-elixir-1.18.5/lib/elixir/lib/elixir/lib
cd $L
cnt() { grep -rhE "$1" --include=*.ex . | wc -l; }
G='when .*\b(is_integer|is_binary|is_atom|is_list|is_map|is_float|is_tuple|is_function|is_number)\('
S='\(%[A-Z][A-Za-z.]*\{'
echo "heads (one-line defs):   def=$(cnt '^\s+def [a-z_?!]+\(')  defp=$(cnt '^\s+defp [a-z_?!]+\(')"
echo "with type-test guard:    def=$(cnt "^\s+def [a-z_?!]+\(.*$G")  defp=$(cnt "^\s+defp [a-z_?!]+\(.*$G")"
echo "head mentions %Struct{}: def=$(cnt "^\s+def [a-z_?!]+$S|^\s+def [a-z_?!]+\(.*[ (]%[A-Z][A-Za-z.]*\{")  defp=$(cnt "^\s+defp [a-z_?!]+$S|^\s+defp [a-z_?!]+\(.*[ (]%[A-Z][A-Za-z.]*\{")"
echo "--- 3 sample private heads with guards (file:line):"
grep -rnE "^\s+defp [a-z_?!]+\(.*$G" --include=*.ex . | head -3
echo "--- 3 sample private heads matching a struct:"
grep -rnE "^\s+defp [a-z_?!]+\(.*[ (]%[A-Z][A-Za-z.]*\{" --include=*.ex . | head -3
