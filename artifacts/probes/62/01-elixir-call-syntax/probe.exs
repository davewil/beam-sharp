Code.prepend_path(System.get_env("BS_EBIN"))
IO.puts("Elixir " <> System.version() <> " / OTP " <> System.otp_release())
# 1. does it PARSE?  (the ticket's six claims, then quoted-function-name forms the ticket did not try)
syn = fn s ->
  case Code.string_to_quoted(s) do
    {:ok, _} -> "parses"
    {:error, {_, msg, tok}} -> "SYNTAX_ERROR: " <> inspect(msg) <> inspect(tok)
  end
end
for s <- File.read!(Path.join(__DIR__, "parse_cases.txt")) |> String.split("\n", trim: true)  do
  IO.puts(String.pad_trailing(s, 36) <> " -> " <> syn.(s))
end
# 2. does it RUN?  (only the forms that parse)
run = fn s ->
  r = try do {v, _} = Code.eval_string(s); inspect(v) rescue e -> "RAISED " <> inspect(e.__struct__) catch k, v -> "#{k} #{inspect v}" end
  IO.puts(String.pad_trailing(s, 36) <> " => " <> r)
end
IO.puts("--- run")
for s <- File.read!(Path.join(__DIR__, "run_cases.txt")) |> String.split("\n", trim: true)  do
  run.(s)
end
# 3. what does the compiler say if you try the dot-capitalised form in a real file?
File.write!(System.tmp_dir!() <> "/p62_cap.exs", ":Shop.New(1)\n")
try do Code.eval_file(System.tmp_dir!() <> "/p62_cap.exs") rescue e -> IO.puts("file eval: " <> inspect(e.__struct__) <> " " <> String.slice(Exception.message(e), 0, 140)) end
# 4. does `mix format`'s engine (Code.format_string!) keep the quotes, and is there a compile-time warning?
IO.puts("--- formatter")
for s <- [~S[:Shop."New"(1)], ~S[:Shop."new"(1)], ~S[:Shop.new(1)]] do
  IO.puts(String.pad_trailing(s, 22) <> " formats to " <> IO.iodata_to_binary(Code.format_string!(s)))
end
IO.puts("--- warnings when compiling a module that uses the quoted form")
Code.eval_string(~S"""
defmodule P62Caller do
  def go(id), do: :Shop."New"(id)
end
""")
IO.inspect(P62Caller.go(3), label: "P62Caller.go(3)")
