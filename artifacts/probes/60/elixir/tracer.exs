# The whole caller-side check: a module whose path contains an `Internal` segment may be
# named only from the subtree that precedes that segment.
defmodule SubtreeTracer do
  def trace({:remote_function, meta, mod, name, arity}, env), do: check(mod, name, arity, meta, env)
  def trace({:remote_macro, meta, mod, name, arity}, env), do: check(mod, name, arity, meta, env)
  def trace(_event, _env), do: :ok

  defp segs(mod), do: mod |> Atom.to_string() |> String.split(".")

  defp check(mod, name, arity, meta, env) do
    case Enum.split_while(segs(mod), &(&1 != "Internal")) do
      {_, []} -> :ok
      {parent, _} ->
        caller = if env.module, do: segs(env.module), else: []
        unless Enum.take(caller, length(parent)) == parent do
          raise CompileError, file: env.file, line: meta[:line],
            description: "#{inspect(env.module)} may not name #{inspect(mod)}.#{name}/#{arity} (internal to #{Enum.join(tl(parent), ".")})"
        end
        :ok
    end
  end
end
