# PREDICTION (before running; Elixir 1.14.0 on OTP 25 runtime):
#  X1 Code.string_to_quoted("-5") is the op node {:-, _, [5]} (Elixir's parser does not fold), same for
#     "x >= -5" -> {:>=, _, [{:x,_,nil}, {:-,_,[5]}]}. `quote do: -5` likewise (an op node).
#  X2 Elixir accepts `-5` in a pattern (def f(-5)) and in a guard (when x >= -5); the expander/compile
#     path folds. Expanded (Macro.expand / :elixir_expand) form of the guard: still an op node, or `-5`?  (unknown; measure)
#  X3 The Erlang abstract code Elixir emits for `-5` in pattern and guard positions is {op,_,'-',{integer,_,5}}
#     or {integer,_,-5} -- measure via :elixir.string_to_quoted + :elixir_erl... (use beam_lib debug_info abstract_code).
#  X4 A function compiled from `-5` vs from `0 - 5`-free literal via Macro.escape(-5) yields identical Code chunk.
show = fn s -> IO.puts("#{s}\n   => #{inspect(Code.string_to_quoted!(s), limit: :infinity)}") end
IO.puts("X1 Code.string_to_quoted:")
Enum.each(["-5", "x >= -5", "2 + 3", "- -5", "-(5)", "-5.0", "- 5"], show)
IO.puts("X1b quote do: -5 => #{inspect(quote(do: -5))}")
IO.puts("X1c quote do: x >= -5 => #{inspect(quote(do: x >= -5))}")
IO.puts("X1d Macro.escape(-5) => #{inspect(Macro.escape(-5))}")

# Compile two modules and read back the Erlang abstract code Elixir generated.
src_a = """
defmodule PA do
  def f(-5), do: :five
  def f(_), do: :no
  def g(x) when x >= -5, do: :ge
  def g(_), do: :no
end
"""
src_b = """
defmodule PB do
  def f(unquote(-5)), do: :five
  def f(_), do: :no
  def g(x) when x >= unquote(-5), do: :ge
  def g(_), do: :no
end
"""
Code.compiler_options(debug_info: true)
[{PA, ba}] = Code.compile_string(src_a)
[{PB, bb}] = Code.compile_string(src_b)
forms_of = fn bin ->
  {:ok, {_, [debug_info: {:debug_info_v1, backend, data}]}} = :beam_lib.chunks(bin, [:debug_info])
  {:ok, forms} = backend.debug_info(:erlang_v1, :x, data, [])
  forms
end
show_clause = fn forms, name ->
  for {:function, _, ^name, 1, clauses} <- forms, {:clause, _, args, guards, _body} <- clauses, do: {args, guards}
end
abs_of = forms_of
IO.puts("X3 PA (literal -5 in source) elixir debug_info definitions, f/1 then g/1 clauses:")
IO.inspect(show_clause.(abs_of.(ba), :f), limit: :infinity)
IO.inspect(show_clause.(abs_of.(ba), :g), limit: :infinity)
IO.puts("X3 PB (unquote(-5): parser sees a call, value spliced as integer -5):")
IO.inspect(show_clause.(abs_of.(bb), :f), limit: :infinity)
IO.inspect(show_clause.(abs_of.(bb), :g), limit: :infinity)
# X4: compare final code chunks (rename module atoms out of the picture)
{:ok, {_, [{~c"Code", ca}]}} = :beam_lib.chunks(ba, [~c"Code"])
{:ok, {_, [{~c"Code", cb}]}} = :beam_lib.chunks(bb, [~c"Code"])
IO.puts("X4 Code chunk equal between literal `-5` source and spliced integer -5: #{ca == cb}")
