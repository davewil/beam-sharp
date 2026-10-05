#!/usr/bin/env bash
# P04: does the quoted call survive the real Elixir toolchain (compile + xref warnings + formatter)?
# CLAIM (this brief's): `:Shop."New"(1)` is an ordinary, compile-time-checked remote call.
# REFUTED IF: elixirc emits no undefined-function warning for a mistyped quoted name (=> unchecked),
# or the formatter rewrites/rejects the quoted form, or the compiled caller fails at run time.
. "$(dirname "$0")/lib.sh"
D="$SCRATCH/p04"; rm -rf "$D"; mkdir -p "$D/ebin" "$D/caller"
"$BSC" --src-root "$REPO/compiler/examples" -o "$D/ebin" "$REPO/compiler/examples/Shop" >/dev/null 2>&1
cat > "$D/caller/c.ex" <<'EXEOF'
defmodule Caller do
  def good(n), do: :Shop."New"(n)
  def typo(n),  do: :Shop."Nw"(n)       # misspelt on purpose
  def wrong_arity, do: :Shop."New"(1, 2)
  def lower(n), do: :Shop.new(n)        # what an alias export would make legal
end
EXEOF
echo "--- elixirc with Shop on the code path (compile-time xref):"
(cd "$D/caller" && elixirc -pa "$D/ebin" -o "$D/caller" c.ex 2>&1 | sed 's/^/  /')
echo "--- run the compiled caller:"
elixir -pa "$D/ebin" -pa "$D/caller" -e 'IO.inspect(Caller.good(5)); IO.inspect(try do Caller.typo(5) rescue e -> Exception.message(e) end)'
echo "--- formatter on the quoted form:"
elixir -e 'IO.puts(Code.format_string!(~S[:Shop."New"(1)])); IO.puts(Code.format_string!(~S[x = :Shop."New"(1) |> foo()])); IO.puts(Code.format_string!(~S[:Shop."new"(1)]))'
