Mix.install([{:peri, "~> 0.11"}, {:zoi, "~> 0.18"}, {:nimble_options, "~> 1.1"}, {:ex_json_schema, "~> 0.11"}, {:json_xema, "~> 0.6"}, {:norm, "~> 0.13"}, {:drops, "~> 0.2"}])
for a <- [:peri, :zoi, :nimble_options, :ex_json_schema, :xema, :json_xema, :norm, :drops], do: IO.puts("#{a} #{Application.spec(a, :vsn)}")
p = fn label, f ->
  r =
    try do
      f.()
    rescue
      e -> {:raised, e}
    catch
      k, v -> {k, v}
    end
  IO.puts("#{label}\n    => #{inspect(r, limit: :infinity, printable_limit: :infinity, width: 200)}")
end
IO.puts("== Peri")
ps = %{id: {:required, :integer}, kind: {:required, {:enum, ["card", "cash"]}}, note: {:string, []} , line: %{sku: {:required, :string}}}
ps = %{id: {:required, :integer}, kind: {:required, {:enum, ["card", "cash"]}}, note: :string, line: %{sku: {:required, :string}}}
p.("peri ok string keys + extra", fn -> Peri.validate(ps, %{"id" => 1, "kind" => "card", "x" => 1}) end)
p.("peri ok atom keys + extra", fn -> Peri.validate(ps, %{id: 1, kind: "card", x: 1}) end)
p.("peri extra, mode permissive", fn -> Peri.validate(ps, %{"id" => 1, "kind" => "card", "x" => 1}, mode: :permissive) end)
p.("peri missing + wrong", fn -> Peri.validate(ps, %{"id" => "a", "line" => %{}}) end)
p.("peri null required", fn -> Peri.validate(ps, %{"id" => nil, "kind" => "card"}) end)
p.("peri null optional", fn -> Peri.validate(ps, %{"id" => 1, "kind" => "card", "note" => nil}) end)
p.("peri float for int", fn -> Peri.validate(ps, %{"id" => 1.0, "kind" => "card"}) end)
p.("peri not a map", fn -> Peri.validate(ps, [1]) end)
p.("peri oneof fail", fn -> Peri.validate(%{v: {:required, {:oneof, [:integer, :string]}}}, %{"v" => 1.5}) end)
p.("peri either fail", fn -> Peri.validate(%{v: {:required, {:either, {%{r: {:required, :integer}}, %{w: {:required, :integer}}}}}}, %{"v" => %{"q" => 1}}) end)
p.("peri humanize", fn -> {:error, e} = Peri.validate(ps, %{"id" => "a", "line" => %{}}); Enum.map(e, &Exception.message/1) end)
IO.puts("== Zoi")
zs = Zoi.map(%{"id" => Zoi.integer(), "kind" => Zoi.enum(["card", "cash"]), "note" => Zoi.optional(Zoi.string()), "line" => Zoi.optional(Zoi.map(%{"sku" => Zoi.string()}))})
p.("zoi ok + extra", fn -> Zoi.parse(zs, %{"id" => 1, "kind" => "card", "x" => 1}) end)
p.("zoi missing + wrong", fn -> Zoi.parse(zs, %{"id" => "a", "line" => %{}}) end)
p.("zoi null required", fn -> Zoi.parse(zs, %{"id" => nil, "kind" => "card"}) end)
p.("zoi null optional", fn -> Zoi.parse(zs, %{"id" => 1, "kind" => "card", "note" => nil}) end)
p.("zoi nullish", fn -> Zoi.parse(Zoi.map(%{"note" => Zoi.nullish(Zoi.string())}), %{"note" => nil}) end)
p.("zoi float for int", fn -> Zoi.parse(zs, %{"id" => 1.0, "kind" => "card"}) end)
p.("zoi coerce string int", fn -> Zoi.parse(Zoi.integer(coerce: true), "12") end)
p.("zoi not a map", fn -> Zoi.parse(zs, [1]) end)
p.("zoi strict extra (unrecognized_keys: :error)", fn -> Zoi.parse(Zoi.map(%{"id" => Zoi.integer()}, unrecognized_keys: :error), %{"id" => 1, "x" => 1}) end)
p.("zoi strict extra (strict: true)", fn -> Zoi.parse(Zoi.map(%{"id" => Zoi.integer()}, strict: true), %{"id" => 1, "x" => 1}) end)
p.("zoi atom-key schema, string-key input", fn -> Zoi.parse(Zoi.map(%{id: Zoi.integer()}), %{"id" => 1}) end)
p.("zoi atom-key schema, coerce", fn -> Zoi.parse(Zoi.map(%{id: Zoi.integer()}, coerce: true), %{"id" => 1}) end)
p.("zoi union fail", fn -> Zoi.parse(Zoi.union([Zoi.integer(), Zoi.string()]), 1.5) end)
du = fn -> Zoi.discriminated_union("t", [Zoi.map(%{"t" => Zoi.literal("circle"), "r" => Zoi.number()}), Zoi.map(%{"t" => Zoi.literal("square"), "w" => Zoi.number()})]) end
p.("zoi discriminated ok", fn -> Zoi.parse(du.(), %{"t" => "circle", "r" => 1}) end)
p.("zoi discriminated unknown tag", fn -> Zoi.parse(du.(), %{"t" => "tri"}) end)
p.("zoi discriminated missing tag", fn -> Zoi.parse(du.(), %{"r" => 1}) end)
p.("zoi discriminated known tag missing field", fn -> Zoi.parse(du.(), %{"t" => "circle"}) end)
IO.puts("== NimbleOptions")
ns = [id: [type: :integer, required: true], kind: [type: {:in, ["card", "cash"]}, required: true], note: [type: {:or, [:string, nil]}]]
p.("nimble ok", fn -> NimbleOptions.validate([id: 1, kind: "card"], ns) end)
p.("nimble extra", fn -> NimbleOptions.validate([id: 1, kind: "card", x: 1], ns) end)
p.("nimble missing + wrong", fn -> NimbleOptions.validate([id: "a"], ns) end)
p.("nimble wrong only", fn -> NimbleOptions.validate([id: "a", kind: "zz"], ns) end)
p.("nimble map input", fn -> NimbleOptions.validate(%{id: 1, kind: "card"}, ns) end)
p.("nimble string-key map", fn -> NimbleOptions.validate(%{"id" => 1, "kind" => "card"}, ns) end)
IO.puts("== ex_json_schema")
raw = %{"type" => "object", "required" => ["id", "kind"],
  "properties" => %{"id" => %{"type" => "integer"}, "kind" => %{"enum" => ["card", "cash"]}, "note" => %{"type" => ["string", "null"]}}}
s = ExJsonSchema.Schema.resolve(raw)
strict = ExJsonSchema.Schema.resolve(Map.put(raw, "additionalProperties", false))
one = ExJsonSchema.Schema.resolve(%{"oneOf" => [%{"type" => "object", "required" => ["t","r"], "properties" => %{"t" => %{"enum" => ["circle"]}, "r" => %{"type" => "number"}}},
                   %{"type" => "object", "required" => ["t","w"], "properties" => %{"t" => %{"enum" => ["square"]}, "w" => %{"type" => "number"}}}]})
v = &ExJsonSchema.Validator.validate/2
p.("exjs ok + extra (default)", fn -> v.(s, %{"id" => 1, "kind" => "card", "x" => 1}) end)
p.("exjs extra (additionalProperties false)", fn -> v.(strict, %{"id" => 1, "kind" => "card", "x" => 1}) end)
p.("exjs missing + wrong", fn -> v.(s, %{"id" => "a"}) end)
p.("exjs null", fn -> v.(s, %{"id" => nil, "kind" => "card", "note" => nil}) end)
p.("exjs float 1.0 as integer", fn -> v.(s, %{"id" => 1.0, "kind" => "card"}) end)
p.("exjs oneOf unknown tag", fn -> v.(one, %{"t" => "tri"}) end)
p.("exjs oneOf known tag missing field", fn -> v.(one, %{"t" => "circle"}) end)
p.("exjs oneOf raw", fn -> ExJsonSchema.Validator.validate(one, %{"t" => "circle"}, error_formatter: false) end)
p.("exjs atom-key data", fn -> v.(s, %{id: 1, kind: "card"}) end)
IO.puts("== JsonXema")
x = JsonXema.new(raw)
p.("xema ok + extra", fn -> JsonXema.validate(x, %{"id" => 1, "kind" => "card", "x" => 1}) end)
p.("xema missing + wrong", fn -> JsonXema.validate(x, %{"id" => "a"}) end)
p.("xema message", fn -> {:error, e} = JsonXema.validate(x, %{"id" => "a"}); Exception.message(e) end)
IO.puts("== Norm")
Code.eval_string(~S"""
import Norm
ns2 = schema(%{"id" => spec(is_integer()), "kind" => spec(is_binary())})
IO.inspect(Norm.conform(%{"id" => 1, "kind" => "card", "x" => 1}, ns2), label: "norm ok + extra")
IO.inspect(Norm.conform(%{"id" => 1}, ns2), label: "norm missing (plain schema)")
IO.inspect(Norm.conform(%{"id" => "a"}, selection(ns2, ["id", "kind"])), label: "norm missing+wrong with selection")
""")
IO.puts("== Drops")
Code.eval_string(~S"""
defmodule DC do
  use Drops.Contract
  schema do
    %{required("id") => integer(), required("kind") => string(), optional("note") => maybe(:string)}
  end
end
IO.inspect(DC.conform(%{"id" => 1, "kind" => "card", "x" => 1}), label: "drops ok + extra")
IO.inspect(DC.conform(%{"id" => "a"}), label: "drops missing + wrong")
""")
