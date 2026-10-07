# Which Elixir spellings can reach a PascalCase export? Each row is executed or parsed, not assumed.
Code.prepend_path(System.get_env("BS_EBIN"))
parse = fn s -> case Code.string_to_quoted(s) do {:ok, _} -> :parses; {:error, _} -> :SYNTAX_ERROR end end
ev = fn s -> try do {r, _} = Code.eval_string(s); {:ok, r} rescue e -> {:raised, e.__struct__} end end
row = fn l, v -> IO.puts(String.pad_trailing(l, 62) <> inspect(v)) end

IO.puts("-- syntax forms (parse only)")
for s <- [":Shop.New(1)", ~s|:Shop."New"(1)|, ~s|:"Shop"."New"(1)|, ~s|Kernel.apply(:Shop, :New, [1])|,
          ~s|(&:Shop.New/1).(1)|, ~s|(&:Shop."New"/1).(1)|, ~s|m = :Shop; m.New(1)|, ~s|m = :Shop; m."New"(1)|,
          ~s|:erlang.apply(:Shop, :New, [1])|, ~s|:Shop.unquote(:New)(1)|] do
  row.(s, parse.(s))
end

IO.puts("-- execution of the forms that parse")
for s <- [~s|:Shop."New"(1)|, ~s|(&:Shop."New"/1).(1)|, ~s|m = :Shop; m."New"(1)|,
          ~s|apply(:Shop, :New, [1])|, ~s|:erlang.apply(:Shop, :New, [1])|, ~s|Function.capture(:Shop, :New, 1).(1)|] do
  row.(s, ev.(s))
end

IO.puts("-- macro with unquote (compile-time generated defs)")
defmodule ShopWrap do
  # generate snake_case wrappers from the beam's own export table at compile time
  for {f, a} <- :Shop.module_info(:exports), f not in [:module_info, :bs@type_atoms] do
    name = f |> Atom.to_string() |> Macro.underscore() |> String.to_atom()
    args = Macro.generate_arguments(a, __MODULE__)
    def unquote(name)(unquote_splicing(args)), do: apply(:Shop, unquote(f), [unquote_splicing(args)])
  end
end
row.("ShopWrap.__info__(:functions)", ShopWrap.__info__(:functions) |> Enum.sort())
row.("ShopWrap.new(4)", ShopWrap.new(4))

IO.puts("-- direct unquote in a call position inside quote")
defmodule Q do
  defmacro call(m, f, args), do: quote(do: unquote(m).unquote(f)(unquote_splicing(args)))
end
row.("Q.call(:Shop, :New, [1]) (macro, runtime)", (Code.eval_string("require Q; Q.call(:Shop, :New, [1])", [], __ENV__) |> elem(0)))

IO.puts("-- Module.concat / attribute")
row.("Module.concat(Shop, nil)", Module.concat(Shop, nil))
