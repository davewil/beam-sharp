#!/usr/bin/env bash
# P03: what does the INSTALLED Elixir tokenizer/parser do with `.Capitalised` after an atom?
# No Elixir .ex/.erl sources are installed (beams only), so this is behavioural evidence: real error text + real AST.
# CLAIM (ticket 62 §1): "Elixir's parser reads `.Capitalized` as an alias".
# REFUTED IF: `:Shop.New` (no parens) parses to a plain remote call/field access instead of an
# `__aliases__`-shaped node or an error; CONFIRMED IF it is an alias node or a syntax error.
. "$(dirname "$0")/lib.sh"
cat > "$SCRATCH/p03.exs" <<'EXEOF'
show = fn src ->
  r = case Code.string_to_quoted(src) do
        {:ok, ast} -> "OK  " <> inspect(ast, limit: :infinity)
        {:error, {meta, msg, tok}} -> "ERR " <> inspect({meta[:line], meta[:column]}) <> " " <> inspect(msg) <> " " <> inspect(tok)
      end
  IO.puts(String.pad_trailing(src, 24) <> r)
end
for s <- [~S':Shop.New(1)', ~S':Shop.New', ~S':Shop.new(1)', ~S':Shop."New"(1)', ~S':Shop.N(1)',
          ~S'Foo.Bar(1)', ~S'foo.Bar(1)', ~S':Shop._New(1)', ~S':Shop.New_(1)', ~S':Shop.Ne_w(1)'] do
  show.(s)
end
IO.puts("\n-- the full human-facing error from eval (what a user sees):")
try do Code.eval_string(":Shop.New(1)") rescue e -> IO.puts(Exception.message(e)) end
EXEOF
elixir "$SCRATCH/p03.exs" 2>&1
