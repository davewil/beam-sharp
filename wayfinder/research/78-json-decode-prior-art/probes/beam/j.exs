Mix.install([{:jason, "1.4.5"}, {:poison, "~> 6.0"}, {:ecto, "~> 3.13"}])
IO.puts("jason #{Application.spec(:jason, :vsn)} poison #{Application.spec(:poison, :vsn)} ecto #{Application.spec(:ecto, :vsn)}")
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
  {"1E400", "1E400"}, {"BOM", <<0xEF,0xBB,0xBF,?1>>}, {"-0", "-0"}
]
IO.puts("== Jason.decode/1")
for {l, s} <- cases, do: p.(l, fn -> Jason.decode(s) end)
IO.puts("== Jason messages")
for {l, s} <- cases, do: (case Jason.decode(s) do {:error, e} -> IO.puts("#{l}: #{Exception.message(e)}"); _ -> :ok end)
p.("Jason iodata", fn -> Jason.decode([~s({"a"), ~s(:1})]) end)
p.("Jason keys: :atoms", fn -> Jason.decode(~s({"zzq_never_seen_1":1}), keys: :atoms) end)
p.("Jason keys: :atoms!", fn -> Jason.decode(~s({"zzq_never_seen_2":1}), keys: :atoms!) end)
p.("Jason objects: :ordered_objects dup", fn -> Jason.decode(~s({"a":1,"a":2}), objects: :ordered_objects) end)
p.("Jason floats: :decimals", fn -> Jason.decode("1.10", floats: :decimals) end)
p.("Jason decode!", fn -> Jason.decode!("hello") end)
IO.puts("== Elixir JSON")
for {l, s} <- cases, do: p.(l, fn -> JSON.decode(s) end)
p.("JSON.decode!", fn -> JSON.decode!("hello") end)
p.("JSON.decode! trailing", fn -> JSON.decode!(~s({"a":1} x)) end)
p.("JSON.decode! truncated", fn -> JSON.decode!(~s({"a":)) end)
p.("JSON.decode iodata", fn -> JSON.decode([~s({"a"), ~s(:1})]) end)
p.("JSON.decode/3", fn -> JSON.decode(~s({"a":1} x), :acc, []) end)
IO.puts("== Poison")
defmodule Addr do
  defstruct [:city]
end
defmodule Person do
  @derive [Poison.Encoder]
  defstruct [:name, :age, address: nil, tags: []]
end
for {l, s} <- cases, do: p.(l, fn -> Poison.decode(s) end)
p.("Poison as: extra+missing", fn -> Poison.decode(~s({"name":"a","extra":1}), as: struct(Person)) end)
p.("Poison as: wrong type", fn -> Poison.decode(~s({"name":42,"age":"old"}), as: struct(Person)) end)
p.("Poison as: nested", fn -> Poison.decode(~s({"name":"a","address":{"city":"X","zip":1}}), as: struct(Person, address: struct(Addr))) end)
p.("Poison as: not an object", fn -> Poison.decode(~s([1,2]), as: struct(Person)) end)
p.("Poison as: null field", fn -> Poison.decode(~s({"name":null}), as: struct(Person, name: "dflt")) end)
p.("Poison keys: :atoms!", fn -> Poison.decode(~s({"zzq_never_seen_3":1}), keys: :atoms!) end)
p.("Poison decode! msg", fn -> Poison.decode!("hello") end)
IO.puts("== Ecto")
defmodule Line do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key false
  embedded_schema do
    field :sku, :string
    field :qty, :integer
  end
  def changeset(s, p), do: s |> cast(p, [:sku, :qty]) |> validate_required([:sku, :qty])
end
defmodule Order do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key false
  embedded_schema do
    field :id, :integer
    field :note, :string
    field :total, :float
    field :kind, Ecto.Enum, values: [:card, :cash]
    embeds_many :lines, Line
  end
  def changeset(p), do: struct(Order) |> cast(p, [:id, :note, :total, :kind]) |> cast_embed(:lines, required: true) |> validate_required([:id, :kind])
  def decode(p), do: p |> changeset() |> apply_action(:insert)
end
errs = fn cs -> Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
  Regex.replace(~r"%{(\w+)}", msg, fn _, key -> opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string() end) end) end
show = fn label, json ->
  cs = Order.changeset(Jason.decode!(json))
  IO.puts("#{label}\n    valid?=#{cs.valid?}\n    errors=#{inspect(cs.errors)}\n    traverse=#{inspect(errs.(cs))}\n    changes=#{inspect(cs.changes, limit: :infinity)}")
end
show.("ecto ok + extra key", ~s({"id":1,"kind":"card","bogus":true,"lines":[{"sku":"a","qty":2}]}))
show.("ecto missing + wrong types", ~s({"id":"abc","total":"x","kind":"crypto","lines":[{"sku":"a"},{"sku":1,"qty":"z"}]}))
show.("ecto null required", ~s({"id":null,"kind":null,"lines":[]}))
show.("ecto lines absent", ~s({"id":1,"kind":"cash"}))
show.("ecto lines wrong type", ~s({"id":1,"kind":"cash","lines":"nope"}))
show.("ecto string-int coercion", ~s({"id":"12","total":3,"kind":"cash","lines":[{"sku":"a","qty":"2"}]}))
show.("ecto float for int", ~s({"id":1.5,"kind":"cash","lines":[{"sku":"a","qty":1}]}))
p.("ecto apply_action ok", fn -> Order.decode(Jason.decode!(~s({"id":1,"kind":"card","lines":[{"sku":"a","qty":2}]}))) end)
p.("ecto params not a map (list)", fn -> Order.changeset(Jason.decode!("[1]")) end)
p.("ecto mixed keys", fn -> Order.changeset(%{"id" => 1, kind: "card"}) end)
