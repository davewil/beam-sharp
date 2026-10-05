# Elixir: the parser's AST for -5 in expression, pattern and guard position.
# REFUTES "Elixir keeps a uniform unary node": any of these printing a bare -5.
for src <- ["-5", "def f(-5), do: 1", "def g(x) when x >= -5, do: 1", "-5.0", "-x", "-(5)", "- -5", "2 - 5", "2 + 3"] do
  IO.inspect(Code.string_to_quoted!(src), label: String.pad_trailing(src, 30))
end
