# Elixir 1.20.4: what the parser hands over for `-5`, and who accepts it where.
IO.puts("Elixir #{System.version()} on OTP #{System.otp_release()}")
for src <- ["-5", "- 5", "-(5)", "2 + 3", "x >= -5", "-x", "- -5", "-5.0"] do
  IO.puts("  quoted  #{String.pad_trailing(src, 10)} -> #{inspect(Code.string_to_quoted!(src))}")
end
IO.puts("\nPattern / guard / module-attribute sites (compiled for real):")
defmodule Neg do
  def pat(-5), do: :minus_five          # unary minus over an int literal as a PATTERN
  def pat(_), do: :other
  def guard(x) when x >= -5, do: :in    # comparison with unary minus in a GUARD
  def guard(_), do: :out
  def sum_guard(x) when x >= 2 + 3, do: :in   # constant arithmetic in a guard
  def sum_guard(_), do: :out
  @min -5
  def attr(x) when x >= @min, do: :in   # module attribute as comparand
  def attr(_), do: :out
  def rng(x) when x in -5..5, do: :in   # range membership in a guard
  def rng(_), do: :out
end
IO.inspect({Neg.pat(-5), Neg.pat(5), Neg.guard(-5), Neg.guard(-6), Neg.sum_guard(5), Neg.attr(-5), Neg.rng(-5), Neg.rng(6)}, label: "results")
for src <- ["defmodule N1 do def f(-x), do: x end", "defmodule N2 do def f(2 + 3), do: 1 end", "defmodule N3 do def f(x) when x >= -y, do: x end"] do
  try do
    Code.compile_string(src); IO.puts("  compiled: #{src}")
  rescue e -> IO.puts("  REFUSED:  #{src}\n            #{String.replace(Exception.message(e), "\n", " ") |> String.slice(0, 150)}")
  end
end
