# Probe 16: the caller-side alternative -- an Elixir module that gives a B# module snake_case names,
# costing the B# compiler nothing. (a) hand-written defdelegate with as:, (b) a 10-line macro that derives
# the wrappers from the beam's export table at the CALLER's compile time.
Code.prepend_path(System.get_env("BS_EBIN"))

defmodule ShopHand do
  defdelegate new(id), to: :Shop, as: :New
  defdelegate which(o), to: :Shop, as: :Which
end

defmodule BSharpWrap do
  defmacro __using__(mod: mod) do
    {:module, _} = Code.ensure_loaded(mod)
    defs =
      for {f, a} <- mod.module_info(:exports),
          s = Atom.to_string(f), not String.starts_with?(s, "bs@"), f != :module_info do
        name = String.to_atom(Macro.underscore(s))
        args = Macro.generate_arguments(a, __MODULE__)
        quote do
          defdelegate unquote(name)(unquote_splicing(args)), to: unquote(mod), as: unquote(f)
        end
      end
    quote do: (unquote_splicing(defs))
  end
end

defmodule ShopAuto do
  use BSharpWrap, mod: :Shop
end

IO.inspect(ShopHand.new(1), label: "hand defdelegate new/1")
IO.inspect(ShopAuto.which(ShopAuto.new(2)), label: "macro-derived which(new(2))")
IO.inspect(ShopAuto.__info__(:functions) |> Enum.sort(), label: "macro-derived functions")
IO.inspect((try do ShopAuto.which(%{Kind: :"MyApp.Order", Id: 9, Total: 5}) rescue e -> {e.__struct__, hd(__STACKTRACE__) |> elem(0), hd(__STACKTRACE__) |> elem(1)} end), label: "crash through wrapper: top frame (mod, fun)")
IO.inspect((try do ShopAuto.nope(1) rescue e -> e.__struct__ end), label: "NEGATIVE nonexistent wrapper")
