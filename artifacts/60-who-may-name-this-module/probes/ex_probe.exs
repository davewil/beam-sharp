# PREDICTION (before running), Elixir 1.14:
#  1. `@doc false` / `@moduledoc false` hide from docs only: an unrelated module can still call the function.
#  2. `defp` is refused at compile time for a caller in another module (UndefinedFunctionError/CompileError).
#  3. Elixir 1.14 Kernel has no built-in "only these modules may call me" feature: no attribute of that kind is
#     known to Module; an unknown attribute like @visible_to is accepted silently (stored, unenforced), with at most a
#     warning; and `@compile {:no_warn_undefined, M}` only silences the undefined-function warning.
#  4. Nested `defmodule Shop.Orders.Internal` inside Shop.Orders gives no privacy: the nested module's name is just
#     Shop.Orders.Internal and any module may call it.
Application.ensure_all_started(:ex_unit)
Code.compiler_options(ignore_module_conflict: true)
defmodule Shop.Orders do
  @moduledoc false
  def total(l), do: recompute(l)
  @doc false
  def recompute_total(l), do: Enum.sum(l)
  defp recompute(l), do: recompute_total(l)
  @visible_to [Shop.Reports]
  def marked(), do: :marked
  defmodule Internal do
    def helper(), do: :internal_helper
  end
end
defmodule Outsider do
  def go(), do: Shop.Orders.recompute_total([10, 20])
  def nested(), do: Shop.Orders.Internal.helper()
  def marked(), do: Shop.Orders.marked()
end
IO.inspect(Outsider.go(), label: "1. @doc false fn called by Outsider")
IO.inspect(Outsider.nested(), label: "4. nested defmodule helper called by Outsider")
IO.inspect(Outsider.marked(), label: "3. fn under unknown @visible_to called by Outsider")
IO.inspect(Code.fetch_docs(Shop.Orders) |> elem(0), label: "1b. fetch_docs tag for moduledoc false module")
IO.inspect(Shop.Orders.module_info(:attributes) |> Keyword.delete(:vsn), label: "3b. module attributes persisted")
IO.inspect(Shop.Orders.__info__(:functions), label: "2b. __info__(:functions) (defp absent)")
# 2. defp from another module: separate compile phase from run phase, capture warnings
{res, warn} = (fn ->
  w = ExUnit.CaptureIO.capture_io(:stderr, fn ->
    Process.put(:r, (try do
      Code.compile_string("defmodule Outsider2 do\n def go(), do: Shop.Orders.recompute([1])\nend")
      :compiled
    rescue e -> {:compile_error, inspect(e.__struct__)} end))
  end)
  {Process.get(:r), w}
end).()
IO.puts("2a. compile of a caller of another module's defp: " <> inspect(res) <> "; stderr warning: " <> inspect(String.slice(warn, 0, 200)))
try do Outsider2.go() rescue e -> IO.puts("2b. run: " <> inspect(e.__struct__) <> ": " <> String.slice(Exception.message(e), 0, 120)) end
# 3c. no_warn_undefined vs control
for {label, attr} <- [{"with", "@compile {:no_warn_undefined, Nope}\n"}, {"control (without)", ""}] do
  out = ExUnit.CaptureIO.capture_io(:stderr, fn ->
    Code.compile_string("defmodule W#{:erlang.unique_integer([:positive])} do\n #{attr} def go(), do: Nope.x()\nend")
  end)
  IO.puts("3c. #{label} no_warn_undefined stderr: " <> inspect(String.slice(out, 0, 150)))
end
# any restriction-shaped API in Module / Kernel exports?
names = (Module.__info__(:functions) ++ Kernel.__info__(:functions) ++ Kernel.__info__(:macros))
        |> Enum.map(&elem(&1, 0)) |> Enum.uniq |> Enum.map(&Atom.to_string/1)
hits = Enum.filter(names, &String.contains?(&1, ["friend", "internal", "restrict", "visible", "allowed", "boundary"]))
IO.inspect(hits, label: "3d. Module/Kernel exported names containing friend|internal|restrict|visible|allowed|boundary")
