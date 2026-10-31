# Run: elixir p3_elixir_privacy.exs      (Elixir 1.14.0 / OTP 25)
# Question: what does Elixir give for "who may call this"? Observe @moduledoc false, @doc false, defp,
# and whether a compile-time warning/error exists for a stranger calling a hidden-from-docs function.
defmodule Shop.Internal.Helper do
  @moduledoc false
  @doc false
  def recompute(x), do: x * 2
  defp secret(x), do: x
  def via_secret(x), do: secret(x)
end

defmodule Shop.Public do
  @moduledoc "documented"
  @doc "documented fn"
  def a(x), do: x
  @doc false
  def hidden(x), do: x
end

{:ok, _} = Application.ensure_all_started(:ex_unit)
{_, diags} = ExUnit.CaptureIO.with_io(:stderr, fn ->
  Code.compile_string("""
  defmodule Stranger.Caller do
    def go(), do: {Shop.Internal.Helper.recompute(21), Shop.Public.hidden(1)}
  end
  """)
end)
out = Stranger.Caller.go()

IO.inspect(out, label: "stranger calls @moduledoc-false / @doc-false fns -> result")
IO.inspect(diags, label: "compiler diagnostics for the stranger module")
{:docs_v1, _, _, _, moddoc, _, docs} = Code.fetch_docs(Shop.Internal.Helper) |> case do
  {:error, e} -> IO.inspect(e, label: "fetch_docs (modules compiled in-memory have no docs chunk)"); {:docs_v1, 0, :elixir, "", :none, %{}, []}
  ok -> ok
end
IO.inspect({moddoc, length(docs)}, label: "moduledoc marker")
IO.inspect(Shop.Internal.Helper.module_info(:exports) |> Enum.sort(), label: "Helper exports (defp absent)")
r = try do Shop.Internal.Helper.secret(1) rescue e -> {e.__struct__, e.function} end
IO.inspect(r, label: "defp called remotely")
# assertions on observed values
{42, 1} = out
"" = diags
{UndefinedFunctionError, :secret} = r
IO.puts("ASSERTIONS HELD: Elixir hides from docs (convention) and defp from linking; no caller-aware diagnostic")
