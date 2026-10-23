#!/usr/bin/env bash
# PROBE 60c — Elixir: what does `@moduledoc false` prevent, and can a caller-side compile check be built?
# Claims under test:
#   (1) @moduledoc false / @doc false change documentation metadata only: the caller still compiles and runs.
#       Control: `defp` IS refused at compile time.
#   (2) A COMPILER TRACER (Code.put_compiler_option(:tracers, ...)) can refuse a remote call by caller module
#       -> the caller-side check is expressible, in ~15 lines, with the callee naming who may call it.
# Needs: source env.sh first.
set -uo pipefail
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
cat > lib.ex <<'E'
defmodule Shop.Internal.Totals do
  @moduledoc false
  def recompute(x), do: x * 2
  @doc false
  def also_hidden(x), do: x + 1
  defp truly_private(x), do: x
  def keep(x), do: truly_private(x)
end
E
cat > outsider.ex <<'E'
defmodule Billing.Outsider do
  def go, do: Shop.Internal.Totals.recompute(21)
end
E
cat > outsider_private.ex <<'E'
defmodule Billing.Outsider2 do
  def go, do: Shop.Internal.Totals.truly_private(1)
end
E
cat > tracer.exs <<'E'
# the callee-names-who-may-call rule, enforced on the CALLER's compile
defmodule VisTracer do
  # module => allowed caller prefixes (callee-side declaration table)
  @allowed %{Shop.Internal.Totals => [Shop]}
  def trace({:remote_function, meta, mod, name, arity}, env) do
    case @allowed do
      %{^mod => prefixes} ->
        caller = Module.split(env.module || Elixir) |> hd() |> then(&Module.concat([&1]))
        unless caller in prefixes do
          IO.puts("      TRACER REFUSES #{inspect(env.module)} -> #{inspect(mod)}.#{name}/#{arity} (line #{meta[:line]})")
          raise CompileError, file: env.file, line: meta[:line],
            description: "#{inspect(mod)} may only be named from #{inspect(prefixes)}"
        end
      _ -> :ok
    end
    :ok
  end
  def trace(_, _), do: :ok
end
E
cat > friend.ex <<'E'
defmodule Shop.Friend do
  def go, do: Shop.Internal.Totals.recompute(21)
end
E
echo "== 1. @moduledoc false: outsider compiles and runs"
elixirc -o out lib.ex outsider.ex 2>&1 | head -5
elixir -pa out -e 'IO.puts("      Billing.Outsider.go() = #{Billing.Outsider.go()}")'
elixir -pa out -e '
  {:docs_v1, _, _, _, moddoc, _, docs} = Code.fetch_docs(Shop.Internal.Totals)
  IO.puts("      moduledoc metadata: #{inspect(moddoc)}  (hidden = documentation tools skip it)")
  IO.puts("      recompute doc entry: #{inspect(for {{:function, :recompute, _}, _, _, d, _} <- docs, do: d)}")'
echo "== 2. CONTROL: a defp call from outside (Elixir: warning at compile time, UndefinedFunctionError at run time)"
elixirc -o out2 lib.ex outsider_private.ex 2>&1 | grep -E 'warning|error' | head -2 | sed 's/^/      /'
elixir -pa out2 -e 'try do Billing.Outsider2.go() rescue e -> IO.puts("      runtime: " <> inspect(e.__struct__)) end'
echo "== 3. tracer: outsider refused, friend accepted (same callee, same rule)"
elixirc -o out3 lib.ex 2>&1 | head -2          # callee compiled untraced and loadable
for f in outsider.ex friend.ex; do
  echo "   -- compiling $f"
  elixir -pa out3 -r tracer.exs -e '
    Code.put_compiler_option(:tracers, [VisTracer])
    case Kernel.ParallelCompiler.compile_to_path(["'$f'"], "out4", return_diagnostics: true) do
      {:ok, _modules, _diags} -> IO.puts("      RESULT: compiled")
      {:error, errors, _diags} -> IO.puts("      RESULT: refused (#{length(errors)} error)")
    end' 2>&1 | sed 's/^/   /' | head -12
done
echo "== 4. size of the rule (lines of Elixir in the tracer body)"
awk '/def trace\(\{:remote_function/{c=1} c{n++} /^  def trace\(_, _\)/{c=0} END{print "      " n-1 " lines between the remote_function clause and the catch-all"}' tracer.exs
