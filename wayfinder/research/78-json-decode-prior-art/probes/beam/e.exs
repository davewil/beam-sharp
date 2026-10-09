Mix.install([{:jsx, "~> 3.1"}, {:thoas, "~> 1.2"}, {:jsone, "~> 1.9"}, {:jesse, "~> 1.8"}, {:jiffy, "~> 2.0"}])
for a <- [:jsx, :thoas, :jsone, :jesse, :jiffy], do: IO.puts("#{a} #{Application.spec(a, :vsn)}")
p = fn label, f ->
  r =
    try do
      f.()
    rescue
      e -> {:raised, e}
    catch
      k, v -> {k, v}
    end
  IO.puts("#{label}\n    => #{inspect(r, limit: :infinity, printable_limit: :infinity)}")
end
cases = [
  {"valid", ~s({"a":1,"b":null})}, {"not json", "hello"}, {"empty", ""}, {"truncated", ~s({"a":)},
  {"trailing", ~s({"a":1} x)}, {"dup keys", ~s({"a":1,"a":2})}, {"invalid utf8", <<?", 0xFF, ?">>},
  {"lone surrogate", ~s("\\ud800")}, {"big int", "123456789012345678901234567890"}, {"1.0", "1.0"}, {"1e2", "1e2"},
  {"1E400", "1E400"}, {"trailing comma", "[1,]"}, {"comment", "[1 /* c */]"}, {"single quotes", "{'a':1}"}
]
IO.puts("== jsx:decode/1"); for {l, s} <- cases, do: p.(l, fn -> :jsx.decode(s) end)
IO.puts("== jsx:decode strict"); for {l, s} <- cases, do: p.(l, fn -> :jsx.decode(s, [:strict]) end)
p.("jsx return_tail", fn -> :jsx.decode(~s({"a":1} x), [:return_tail]) end)
p.("jsx labels atom", fn -> :jsx.decode(~s({"zzq_never_4":1}), [{:labels, :atom}]) end)
p.("jsx labels existing_atom", fn -> :jsx.decode(~s({"zzq_never_5":1}), [{:labels, :existing_atom}]) end)
p.("jsx labels attempt_atom", fn -> :jsx.decode(~s({"zzq_never_6":1,"ok":2}), [{:labels, :attempt_atom}]) end)
p.("jsx dup proplist", fn -> :jsx.decode(~s({"a":1,"a":2}), [{:return_maps, false}]) end)
IO.puts("== thoas:decode/1"); for {l, s} <- cases, do: p.(l, fn -> :thoas.decode(s) end)
p.("thoas to_existing_atom", fn -> :thoas.decode(~s({"zzq_never_7":1}), %{keys: :to_existing_atom}) end)
IO.puts("== jsone:try_decode/1"); for {l, s} <- cases, do: p.(l, fn -> :jsone.try_decode(s) end)
p.("jsone reject_invalid_utf8", fn -> :jsone.try_decode(<<?", 0xFF, ?">>, [:reject_invalid_utf8]) end)
p.("jsone duplicate_map_keys last", fn -> :jsone.try_decode(~s({"a":1,"a":2}), [{:duplicate_map_keys, :last}]) end)
IO.puts("== jiffy:decode/2 return_maps"); for {l, s} <- cases, do: p.(l, fn -> :jiffy.decode(s, [:return_maps]) end)
p.("jiffy default ejson dup", fn -> :jiffy.decode(~s({"a":1,"a":2})) end)
p.("jiffy dedupe_keys", fn -> :jiffy.decode(~s({"a":1,"a":2}), [:dedupe_keys]) end)
p.("jiffy return_trailer", fn -> :jiffy.decode(~s({"a":1} x), [:return_trailer]) end)
IO.puts("== jesse")
schema = %{"type" => "object", "required" => ["id", "kind"], "additionalProperties" => false,
  "properties" => %{"id" => %{"type" => "integer"}, "kind" => %{"enum" => ["card", "cash"]}, "note" => %{"type" => ["string", "null"]}}}
loose = Map.delete(schema, "additionalProperties")
one = %{"oneOf" => [%{"type" => "object", "required" => ["t","r"], "properties" => %{"t" => %{"enum" => ["circle"]}, "r" => %{"type" => "number"}}},
                   %{"type" => "object", "required" => ["t","w"], "properties" => %{"t" => %{"enum" => ["square"]}, "w" => %{"type" => "number"}}}]}
p.("jesse ok", fn -> :jesse.validate_with_schema(schema, %{"id" => 1, "kind" => "card"}) end)
p.("jesse extra key (additionalProperties false)", fn -> :jesse.validate_with_schema(schema, %{"id" => 1, "kind" => "card", "x" => 1}) end)
p.("jesse extra key (default)", fn -> :jesse.validate_with_schema(loose, %{"id" => 1, "kind" => "card", "x" => 1}) end)
p.("jesse missing+wrong, default allowed_errors", fn -> :jesse.validate_with_schema(schema, %{"id" => "a"}) end)
p.("jesse missing+wrong, allowed_errors infinity", fn -> :jesse.validate_with_schema(schema, %{"id" => "a", "kind" => "x"}, [{:allowed_errors, :infinity}]) end)
p.("jesse null on integer", fn -> :jesse.validate_with_schema(schema, %{"id" => :null, "kind" => "card"}) end)
p.("jesse oneOf unknown tag", fn -> :jesse.validate_with_schema(one, %{"t" => "tri"}) end)
p.("jesse oneOf known tag missing field", fn -> :jesse.validate_with_schema(one, %{"t" => "circle"}) end)
p.("jesse float 1.0 as integer", fn -> :jesse.validate_with_schema(schema, %{"id" => 1.0, "kind" => "card"}) end)
