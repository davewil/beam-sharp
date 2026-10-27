# Hypothesis H1: a compiler tracer can reject "a module outside Shop.Orders.* names Shop.Orders.Internal",
#   accepting the in-subtree caller (falsifiable: expect exactly 1 rejection, and it must be the outsider).
# Hypothesis H2: the tracer's added compile cost is small (we only report the number; no threshold is tuned).
defmodule Boundary do
  def trace({:remote_function, _m, mod, _n, _a}, env) when mod == Shop.Orders.Internal do
    caller = Atom.to_string(env.module)
    unless String.starts_with?(caller, "Elixir.Shop.Orders.") or caller == "Elixir.Shop.Orders.Internal",
      do: raise CompileError, description: "#{caller} may not name Shop.Orders.Internal"
    :ok
  end
  def trace(_, _), do: :ok
end
IO.puts("Elixir #{System.version()} / OTP #{System.otp_release()}")
Code.compiler_options(ignore_module_conflict: true)
Code.compile_string("defmodule Shop.Orders.Internal do def f(x), do: x + 1 end")
try_compile = fn name, src, tracers ->
  Code.put_compiler_option(:tracers, tracers)
  try do Code.compile_string(src); {name, :ok} rescue e in CompileError -> {name, {:rejected, e.description}} end
end
IO.inspect(try_compile.("inside", "defmodule Shop.Orders.Api do def g(x), do: Shop.Orders.Internal.f(x) end", [Boundary]))
IO.inspect(try_compile.("outside", "defmodule Other.Peek do def g(x), do: Shop.Orders.Internal.f(x) end", [Boundary]))
IO.inspect(try_compile.("outside, no tracer", "defmodule Other.Peek2 do def g(x), do: Shop.Orders.Internal.f(x) end", []))
# overhead: N modules, half inside half outside-but-not-calling (so none rejected)
for n <- [100, 1000] do
  srcs = for i <- 1..n, do: "defmodule Shop.Orders.M#{i} do def g(x), do: Shop.Orders.Internal.f(x) + #{i} end"
  t = fn tr ->
    Code.put_compiler_option(:tracers, tr)
    {us, _} = :timer.tc(fn -> Enum.each(srcs, &Code.compile_string/1) end)
    us
  end
  t.([]) # warm
  base = for _ <- 1..3, do: t.([])
  with = for _ <- 1..3, do: t.([Boundary])
  IO.puts("N=#{n}: no tracer median #{Enum.at(Enum.sort(base),1)} us, tracer median #{Enum.at(Enum.sort(with),1)} us")
end
