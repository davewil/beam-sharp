# 57_elixir -- survey: how Elixir reads and folds a negative literal.
# Claims: (1) the parser yields a unary-op node {:-, _, [5]} for `-5` (no fold in the parser);
# (2) `when x >= -5` and `-5` patterns and `2 + 3` in a guard are all accepted; arithmetic in a
# PATTERN (`2 + 3`) is refused; (3) the fold happens after expansion (erlc), not in Elixir.
# REFUTED by: Code.string_to_quoted!("-5") returning the bare integer -5, or the pattern `2 + 3` compiling.
for s <- ["-5", "- 5", "-(-5)", "-5 + 10", "-2 * 3", "x >= -5"] do
  IO.puts("quote #{String.pad_trailing(s, 10)} => #{inspect(Code.string_to_quoted!(s), limit: :infinity)}")
end
try_c = fn name, src ->
  r = try do
    Code.compile_string(src); "accepted"
  rescue e -> "REFUSED " <> (Exception.message(e) |> String.split("\n") |> hd)
  end
  IO.puts("#{String.pad_trailing(name, 38)} #{r}")
end
try_c.("guard  when x >= -5", "defmodule G1 do def f(x) when x >= -5, do: :a; def f(_), do: :b end")
try_c.("guard  when x >= 2 + 3", "defmodule G2 do def f(x) when x >= 2 + 3, do: :a; def f(_), do: :b end")
try_c.("guard  when x >= -(-5)", "defmodule G3 do def f(x) when x >= -(-5), do: :a; def f(_), do: :b end")
try_c.("pattern f(-5)", "defmodule P1 do def f(-5), do: :a; def f(_), do: :b end")
try_c.("pattern f(2 + 3) (MUST refuse)", "defmodule P2 do def f(2 + 3), do: :a; def f(_), do: :b end")
try_c.("pattern f(-(-5))", "defmodule P3 do def f(-(-5)), do: :a; def f(_), do: :b end")
try_c.("module attr @min -5 in guard", "defmodule P4 do @min -5; def f(x) when x >= @min, do: :a; def f(_), do: :b end")
IO.puts("run: G1.f(-5)=#{inspect(G1.f(-5))} G1.f(-6)=#{inspect(G1.f(-6))} P1.f(-5)=#{inspect(P1.f(-5))} G3.f(5)=#{inspect(G3.f(5))}")
