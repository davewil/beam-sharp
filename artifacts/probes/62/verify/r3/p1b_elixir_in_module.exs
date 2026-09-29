# PROBE 1b — does the quoted-call spelling survive real Elixir tooling? (Elixir 1.14)
# Env: BS_EBIN.
#
# EXPECTED (before run):
#   - a defmodule containing :Api."New"(1), a pipe `1 |> :Api."New"()`, and a
#     capture compiles with NO warning on stderr, and runs.
#   - Code.format_string! keeps the quotes (a formatter that unquoted it would produce
#     the SYNTAX_ERROR form): output still contains `:Api."New"(1)`.
#   - the compiled module's stacktrace on a crash names the function as 'New' (Elixir
#     Exception.format_mfa quotes it or prints raw) - recorded, no prediction.
Code.prepend_path(System.get_env("BS_EBIN"))
src = ~S'''
defmodule Caller do
  def direct(i), do: :Api."New"(i)
  def piped(i), do: i |> :Api."New"()
  def captured, do: &:Api."New"/1
  def crash, do: :Api."Total"(%{Kind: :"Wrong.Order", Id: 1, Total: 1})
end
'''
fmt = src |> Code.format_string!() |> IO.iodata_to_binary() |> String.split("\n") |> Enum.at(1)
IO.puts("format: " <> fmt)
[{Caller, _}] = Code.compile_string(src)
IO.inspect(Caller.direct(1), label: "direct")
IO.inspect(Caller.piped(2), label: "piped")
IO.inspect(Caller.captured().(3), label: "captured")
try do Caller.crash() rescue e -> IO.puts("crash: " <> Exception.message(e)); IO.puts(Exception.format_stacktrace(__STACKTRACE__) |> String.split("\n") |> Enum.take(2) |> Enum.join("\n")) end
IO.puts(Exception.format_mfa(:Api, :New, 1))
