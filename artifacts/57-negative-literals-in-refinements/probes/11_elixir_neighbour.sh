#!/usr/bin/env bash
# Elixir 1.14.0 on OTP 25 (NOT 28: the apt Elixir's beams do not load on OTP 28). Version older than the tickets' 1.19.5.
export PATH=/usr/bin:/bin
d=$(mktemp -d); trap 'rm -rf $d' EXIT; cd $d
echo "== quoted forms: -5 is a unary-op call, not a literal (pattern and expr alike)"
elixir -e 'for s <- ["-5", "case x do -5 -> 1 end", "x when x >= -5", "-5..5", "2+3", "@spec f(-5..5) :: :ok"] do IO.puts(s <> "   =>   " <> inspect(Code.string_to_quoted!(s))) end'
echo "== Does -5 work in a pattern, a guard, a range pattern, an expression-folded pattern?"
cat > t.exs <<'EX'
defmodule T do
  def p(-5), do: :m5
  def p(_), do: :o
  def g(x) when x >= -5, do: :ge
  def g(_), do: :lt
  def r(x) when x in -5..5, do: :in
  def r(_), do: :out
end
IO.inspect({T.p(-5), T.g(-7), T.r(-5), T.r(9)})
EX
elixir t.exs 2>&1 | head -12
echo "== arithmetic in a pattern separately (Elixir refuses it?)"
cat > u.exs <<'EX'
defmodule U do
  def s(2 + 3), do: :five
end
EX
elixir u.exs 2>&1 | head -6
echo "== typespec -5..5"
cat > v.exs <<'EX'
defmodule V do
  @type r :: -5..5
  @spec f(r) :: :ok
  def f(_), do: :ok
end
IO.inspect(V.f(1))   # compiled: the typespec -5..5 was accepted
EX
elixir v.exs 2>&1 | head -12
echo "(Only .beam files ship in /usr/lib/elixir: no Elixir source was opened, so no file:line is cited for Elixir.)"
