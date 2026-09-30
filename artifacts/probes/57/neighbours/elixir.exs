# EXPECTED before run (Elixir 1.14.0):
#  E1 Code.string_to_quoted("-5") is {:-, _, [5]}  (a unary operator node, not the literal -5)
#  E2 Code.string_to_quoted("x >= -5") has the operand {:-, _, [5]}
#  E3 Macro.expand of quote(do: -5) is still {:-, _, [5]} (it is not a macro that rewrites to a literal)
#  E4 a guard `when x >= -5` compiles and decides -6 -> :out, -5 -> :in
#  E5 a pattern `-5` in a function head compiles and matches -5 (so the COMPILER reads the operator node in a pattern)
#  E6 `when x >= 2 + 3` compiles and decides 4 -> :out, 5 -> :in (guards take arbitrary arithmetic)
#  E7 Elixir tokenizer: "-5" gives a separate :dual_op token then :int (no negative-integer token)
# FIRST RUN: E3 and E7 FAILED against the predictions above (recorded in the brief, not hidden):
#  E3 observed: Macro.expand({:-,_,[5]}) returns the literal -5 -- the EXPANDER folds unary minus over an
#     integer literal (source of elixir_expand not installed; behaviour probed only).
#  E7 observed: the :int token payload is the charlist '5', not the integer 5 (my prediction's shape was wrong;
#     the claim "no negative-integer token" stands).
# Corrected expectations, written after seeing those outputs, are E3b, E7b, E8:
#  E3b Macro.expand of {:-, [], [5]} is the integer -5
#  E7b tokens of "-5" are [{:dual_op,_,:-}, {:int,_,'5'}]
#  E8  Macro.expand of the AST of "2 + 3" is still {:+, _, [2, 3]} (binary arithmetic is NOT folded by the expander)
ok = fn name, cond_ -> IO.puts((if cond_, do: "PASS ", else: "FAIL ") <> name) end
wrong = fn name, cond_ -> IO.puts((if cond_, do: "FAIL ", else: "PASS ") <> name <> " (the first-run prediction is confirmed WRONG; corrected in the b-check)") end
{:ok, q1} = Code.string_to_quoted("-5")
IO.inspect(q1, label: "E1 ast(-5)")
ok.("E1", match?({:-, _, [5]}, q1))
{:ok, q2} = Code.string_to_quoted("x >= -5")
IO.inspect(q2, label: "E2 ast(x >= -5)")
ok.("E2", match?({:>=, _, [{:x, _, _}, {:-, _, [5]}]}, q2))
q3 = Macro.expand(quote(do: -5), __ENV__)
IO.inspect(q3, label: "E3 Macro.expand(quote(do: -5))")
wrong.("E3", match?({:-, _, [5]}, q3))
ok.("E3b", Macro.expand({:-, [], [5]}, __ENV__) === -5)
ok.("E8", match?({:+, _, [2, 3]}, Macro.expand(Code.string_to_quoted!("2 + 3"), __ENV__)))
defmodule G do
  def g(x) when x >= -5, do: :in
  def g(_), do: :out
  def h(-5), do: :minus_five
  def h(_), do: :other
  def k(x) when x >= 2 + 3, do: :in
  def k(_), do: :out
end
ok.("E4", {G.g(-6), G.g(-5)} == {:out, :in})
ok.("E5", {G.h(-5), G.h(5)} == {:minus_five, :other})
ok.("E6", {G.k(4), G.k(5)} == {:out, :in})
{:ok, toks} = :elixir_tokenizer.tokenize(~c"-5", 1, [])  |> then(fn {:ok, _, _, _, t} -> {:ok, t}; o -> o end)
IO.inspect(toks, label: "E7 tokens(-5)")
wrong.("E7", match?([{:dual_op, _, :-}, {:int, _, 5}], toks))
ok.("E7b", match?([{:dual_op, _, :-}, {:int, _, ~c"5"}], toks))
