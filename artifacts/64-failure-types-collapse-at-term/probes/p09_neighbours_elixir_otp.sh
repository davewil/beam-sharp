#!/usr/bin/env bash
# P09: Erlang/Elixir lookup shapes from the INSTALLED trees. Elixir .ex source is not in the conda package (ebin only),
# so Elixir is cited from the compiled Docs chunk + specs of Elixir.Map / Elixir.Keyword (source unavailable: only ebin shipped).
. "$(dirname "$0")/lib.sh"
OTP=$S/beam/lib/erlang/lib/stdlib-8.1.1/src/maps.erl
echo "--- OTP maps.erl line numbers"; grep -n '^-spec find\|^-spec get(Key, Map)\|^-spec get(Key, Map, Default)\|^-spec is_key\|^-spec take' $OTP
cat > $S/64/nb.exs <<'EX'
for {m, funs} <- [{Map, [fetch: 2, get: 3, get: 2, fetch!: 2, has_key?: 2]}, {Keyword, [fetch: 2, get: 3, fetch!: 2, has_key?: 2]}] do
  {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(m)
  {:ok, specs} = Code.Typespec.fetch_specs(m)
  for {{:function, f, a}, anno, _, doc, _} <- docs, {f, a} in funs do
    spec = Enum.find_value(specs, fn {{sf, sa}, [s | _]} -> if {sf, sa} == {f, a}, do: Macro.to_string(Code.Typespec.spec_to_quoted(f, s)) end)
    d = case doc do %{"en" => t} -> t |> String.split("\n\n") |> hd(); _ -> "" end
    IO.puts("#{inspect(m)}.#{f}/#{a}  [doc anno #{inspect(anno)}]\n   spec: #{spec}\n   doc : #{d}")
  end
end
IO.inspect(Map.get(%{a: nil}, :a), label: "Map.get(%{a: nil}, :a)  (stored nil)")
IO.inspect(Map.get(%{}, :a), label: "Map.get(%{}, :a)           (absent)")
IO.inspect(Map.fetch(%{a: nil}, :a), label: "Map.fetch stored nil")
IO.inspect(Map.fetch(%{}, :a), label: "Map.fetch absent")
IO.inspect(Map.get(%{}, :a, :dflt), label: "Map.get/3 default")
EX
elixir $S/64/nb.exs
