# Compile-time caller whitelist for Elixir 1.14: a module under a restricted prefix may be named
# only from modules under the allowed prefix. 22 lines, counting this one.
defmodule InternalTracer do
  @rules [{"Shop.Orders.Internal", "Shop.Orders"}]

  def trace({:remote_function, meta, callee, _n, _a}, env), do: check(callee, meta, env)
  def trace({:alias_reference, meta, callee}, env), do: check(callee, meta, env)
  def trace(_event, _env), do: :ok

  defp check(callee, meta, env) do
    c = inspect(callee)
    caller = if env.module, do: inspect(env.module), else: ""
    for {restricted, allowed} <- @rules,
        String.starts_with?(c, restricted),
        not String.starts_with?(caller, allowed) do
      IO.puts(:stderr, "#{Path.basename(env.file)}:#{meta[:line]}: error: #{caller} may not name #{c} (only #{allowed}.* may)")
      :ets.insert(:violations, {c, caller})
    end
    :ok
  end
end
