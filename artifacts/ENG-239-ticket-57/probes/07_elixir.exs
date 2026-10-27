# H1: Elixir's reader keeps `-5` as {:-, meta, [5]} (no parser fold), in patterns and guards alike.
# H2: Elixir accepts `def f(-5)` and `when x >= -5 + 1` (folded later, by the expander/compiler), and refuses `def f(x + 2)`.
# H3: the Erlang forms Elixir emits hold a literal for `-5 + 1`.
# FALSIFIED if: H1 shows a bare -5; H2 accepts f(x + 2); H3's guard still contains a '+' op.
# RESULT (see 07_elixir.out): H1 held. H2 held for `f(x + 2)` but `f(1 + 2)` is ALSO refused in a pattern (only -N is
# special-cased there). H3 was FALSIFIED: Elixir hands the Erlang compiler the unfolded ops; folding happens after.
IO.puts("Elixir #{System.version()} on OTP #{:erlang.system_info(:otp_release)}")
for s <- ["-5", "x >= -5", "x >= -5 + 1", "- -5"] do
  IO.puts("quoted #{String.pad_trailing(s, 14)} #{inspect(Code.string_to_quoted!(s), limit: :infinity)}")
end
try_c = fn label, src ->
  r =
    try do
      Code.compile_string(src); :accepted
    rescue
      e -> {:refused, e.__struct__, String.slice(Exception.message(e), 0, 70)}
    end
  IO.puts("compile #{String.pad_trailing(label, 36)} #{inspect(r)}")
end
Code.put_compiler_option(:ignore_module_conflict, true)
try_c.("def f(-5)",                 "defmodule P1 do def f(-5), do: :a end")
try_c.("def f(x) when x >= -5 + 1", "defmodule P2 do def f(x) when x >= -5 + 1, do: :a end")
try_c.("def f(x + 2)",              "defmodule P3 do def f(x + 2), do: :a end")
try_c.("def f(1 + 2)",              "defmodule P4 do def f(1 + 2), do: :a end")
try_c.("def f(x) when x >= 1 / 0",  "defmodule P5 do def f(x) when x >= 1 / 0, do: :a end")
[{mod, bin}] = Code.compile_string("defmodule P6 do def f(x) when x >= -5 + 1, do: :a end")
{:ok, {_, [debug_info: {:debug_info_v1, backend, data}]}} = :beam_lib.chunks(bin, [:debug_info])
{:ok, forms} = backend.debug_info(:erlang_v1, mod, data, [])
guards = for {:function, _, :f, 1, [{:clause, _, _, g, _} | _]} <- forms, do: g
IO.puts("erlang forms of P6 guard: #{inspect(guards, limit: :infinity)}")
