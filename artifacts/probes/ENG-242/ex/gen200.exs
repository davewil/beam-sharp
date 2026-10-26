# usage: elixir gen200.exs OUTDIR  — 200 modules, 20 subtrees x 10, each fn calls 5 others (deterministic)
[out] = System.argv()
File.rm_rf!(out); File.mkdir_p!(out)
:rand.seed(:exsss, {1, 2, 3})
mods = for s <- 1..20, m <- 1..10, do: {"Gen.S#{s}.M#{m}", s, m}
for {name, s, m} <- mods do
  fns = for f <- 1..10 do
    calls = for _ <- 1..5 do
      {t, _, _} = Enum.random(mods)
      "#{t}.f#{:rand.uniform(10)}(x)"
    end
    # avoid self-recursion cycles being a compile problem: calls are runtime, compile-time only needs the module to exist
    "  def f#{f}(x), do: Enum.sum([#{Enum.join(calls, ", ")}]) + x"
  end
  File.write!(Path.join(out, "s#{s}_m#{m}.ex"), "defmodule #{name} do\n#{Enum.join(fns, "\n")}\nend\n")
end
IO.puts("generated #{length(mods)}")
