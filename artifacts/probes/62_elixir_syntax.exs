# see 62_elixir_syntax.sh for the claim and the refutation condition
Code.prepend_path(System.get_env("BS_EBIN"))
rows = [
  # the ticket's table (controls: expected SYNTAX_ERROR / parses)
  ~S{:Shop.New(1)},
  ~S{:"BSharp.Shop".New(1)},
  ~S{:"Elixir.Shop".New(1)},
  ~S{:"Shop.Reports".Totals(1)},
  ~S{:"BSharp.Shop".new(1)},
  ~S{apply(:Shop, :New, [1])},
  ~S{Kernel.apply(:Shop, :New, [1])},
  ~S{(&:Shop.New/1).(1)},
  # NOT in the ticket: quoted function names
  ~S{:Shop."New"(1)},
  ~S{:Shop.'New'(1)},
  ~S{:"Shop"."New"(1)},
  ~S{:"Shop.Reports"."Totals"(1)},
  ~S{(&:Shop."New"/1).(1)},
  ~S{1 |> :Shop."New"()},
  ~S{m = :Shop; m."New"(1)},
  ~S{m = :Shop; m.New(1)},
  ~S{n = :New; apply(:Shop, n, [1])},
  ~S{n = "New"; :Shop.unquote(String.to_atom(n))(1)},
  ~S{Module.concat([:Shop]) |> then(& &1)},
  ~S{:erlang.apply(:Shop, :New, [1])},
  ~S{:"Shop.Reports".Restate(3)},
  ~S{:"Shop.Reports"."Restate"(3)},
  ~S{:Shop.new(1)},
  # control: a deliberately nonexistent function through the quoted form
  ~S{:Shop."Nope"(1)},
]
for src <- rows do
  parse = case Code.string_to_quoted(src) do {:ok, _} -> "parses"; {:error, _} -> "SYNTAX_ERROR" end
  run =
    if parse == "parses" do
      try do
        {v, _} = Code.eval_string(src)
        "ok -> " <> inspect(v) |> String.slice(0, 60)
      rescue
        e -> "raised " <> inspect(e.__struct__) <> " " <> (Exception.message(e) |> String.slice(0, 70))
      end
    else
      "-"
    end
  IO.puts(String.pad_trailing(src, 52) <> String.pad_trailing(parse, 13) <> run)
end
# macro-time: a quoted name built with unquote inside a quote/defmodule
defmodule Dyn do
  for {n, a} <- [{"New", 1}] do
    args = Macro.generate_arguments(a, __MODULE__)
    def unquote(:"call_#{String.downcase(n)}")(unquote_splicing(args)),
      do: :Shop.unquote(String.to_atom(n))(unquote_splicing(args))
  end
end
IO.puts("macro unquote wrapper Dyn.call_new(1) -> " <> inspect(Dyn.call_new(1)))
