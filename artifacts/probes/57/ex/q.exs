for s <- ["n >= -5", "n >= -(5)", "n >= 0 - 5", "n >= 2 + 3", "-5", "f(-5)"] do
  IO.inspect(Code.string_to_quoted!(s), label: String.pad_trailing(s, 12))
end
IO.inspect(Code.string_to_quoted!("@type t :: -5..5"), label: "typespec")
IO.inspect(Code.string_to_quoted!("@type t :: -(5)..5"), label: "typespec -(5)")
IO.inspect(:erts_debug.flat_size({:-, [line: 1], [5]}), label: "flat_size unary AST")
IO.inspect(:erts_debug.flat_size(-5), label: "flat_size literal")
# Which typespec ranges does Elixir 1.14 accept? (each in its own module; compile errors are the answer)
for {label, ty} <- [{"-5..5", "-5..5"}, {"-(5)..5", "-(5)..5"}, {"(0 - 5)..5", "(0 - 5)..5"},
                    {"(1 + 1)..(2 * 3)", "(1 + 1)..(2 * 3)"}, {"-5..-1", "-5..-1"}, {"-(2 + 3)..5", "-(2 + 3)..5"}] do
  r =
    try do
      Code.compile_string("defmodule T#{:erlang.unique_integer([:positive])} do\n  @type t :: #{ty}\nend\n")
      "accepted"
    rescue
      e -> "refused: " <> (Exception.message(e) |> String.split("\n") |> hd)
    end
  IO.puts(String.pad_trailing("typespec " <> label, 34) <> r)
end
# guards and patterns accept literals, negations and arithmetic alike (run time, no fold at the language level)
Code.compile_string("""
defmodule Q do
  def g(-1), do: :neg
  def g(_), do: :other
  def h(n) when n >= 2 + 3, do: :y
  def h(n) when n >= -5, do: :z
  def h(_), do: :n
end
""")
IO.inspect({Q.g(-1), Q.h(6), Q.h(-3), Q.h(-9)}, label: "Q.g(-1), h(6), h(-3), h(-9)")
