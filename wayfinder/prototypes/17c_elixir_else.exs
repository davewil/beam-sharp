# 17c — Where does `else` live in Elixir? Companion to 17c_else_in_the_neighbourhood.md.
#
# Elixir 1.19.5 (compiled with Erlang/OTP 28).
#
# To reproduce: `elixir 17c_elixir_else.exs`
#
# The question ticket 17 was actually asking: is `else` a general keyword for the
# fall-through arm, or does it belong to `if` alone? If it belongs to `if` alone, then
# adopting `if`/`else` into beam-sharp means adopting the only construct on this platform
# whose fall-through case is not expressible as a pattern.

IO.puts("--- one-armed if ---")

# Elixir returns nil, which is what ticket 10 routed to ticket 17: the beam-sharp analogue
# would be option<T>, and ticket 15 §1 makes `atom | :nothing` an error at the declaration.
IO.inspect(if(false, do: 1), label: "one-armed if, false branch")

IO.puts("\n--- cond's catch-all is a CLAUSE, not a keyword ---")

result =
  cond do
    1 > 2 -> :a
    2 > 1 -> :b
    true -> :c
  end

IO.inspect(result, label: "cond")

IO.puts("\n--- and both pattern constructs reject `else` outright ---")

for {name, src} <- [
      {"cond with else", "cond do\n 1 > 2 -> :a\n else\n :b\n end"},
      {"case with else", "case 1 do\n 2 -> :a\n else\n :b\n end"}
    ] do
  try do
    Code.eval_string(src)
    IO.inspect(:accepted, label: name)
  rescue
    _ -> IO.inspect(:rejected, label: name)
  end
end

# OBSERVED OUTPUT, Elixir 1.19.5 / OTP 28:
#
#   one-armed if, false branch: nil
#   cond: :b
#   error: unexpected option :else in "cond"
#   cond with else: :rejected
#   error: unexpected option :else in "case"
#   case with else: :rejected
#
# READING: `else` is not merely unidiomatic in a pattern construct here — it is not in the
# grammar. `with`, `try` and `receive` do have `else`/`after` clauses, but those name the
# non-matching and timeout paths, which is a different thing from a binary conditional's
# second arm.
#
# → ticket 17 §6: beam-sharp has one branching construct, `switch`, and no `else`.
