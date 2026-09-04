# Does Elixir's guard-expression whitelist treat `-5` as a literal, or as
# Kernel.-/1 applied to 5? And does it fold constant arithmetic in guards
# the way it must in pattern position (Elixir patterns also allow -5 and
# even pin-less arithmetic like 2+3? -- Elixir patterns do NOT allow
# arbitrary arithmetic, only literals, so this tests where the line is).

defmodule GuardProbe do
  def classify(x) when x >= -5, do: :hi
  def classify(_), do: :lo

  # Real subtraction of two variables in guard position -- refused, since
  # general subtraction of two runtime values is not a guard-safe
  # operation UNLESS both are literals/already-bound in a way the compiler
  # accepts. Elixir DOES allow -/2 and -/1 as guard-safe operators (they're
  # in the Kernel guard whitelist) so `x - y` where x,y are bound variables
  # actually IS legal in a guard (arithmetic ops are guard BIFs in the BEAM
  # sense) -- unlike a genuinely non-whitelisted function call.
  def classify2(x, y) when x - y >= 0, do: :nonneg
  def classify2(_, _), do: :neg

  # Pattern-position negative literal.
  def sign(-5), do: :neg_five
  def sign(0), do: :zero
  def sign(_), do: :other

  # Pattern-position CONSTANT ARITHMETIC (not just negation) -- does
  # Elixir's pattern compiler fold `2 + 3` into the literal 5 the way
  # Erlang's does? Elixir patterns generally do NOT allow arbitrary
  # expressions (this should be a COMPILE ERROR, unlike Erlang).
  # Left commented -- tested separately since it may fail to compile.
end

IO.inspect(GuardProbe.classify(-5), label: "classify(-5)")
IO.inspect(GuardProbe.classify(0), label: "classify(0)")
IO.inspect(GuardProbe.classify(-6), label: "classify(-6)")
IO.inspect(GuardProbe.classify2(3, 5), label: "classify2(3,5) (3-5=-2 -> neg)")
IO.inspect(GuardProbe.classify2(5, 3), label: "classify2(5,3) (5-3=2 -> nonneg)")
IO.inspect(GuardProbe.sign(-5), label: "sign(-5)")
IO.inspect(GuardProbe.sign(0), label: "sign(0)")
