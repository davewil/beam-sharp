#!/usr/bin/env bash
# P07: what an Elixir caller can write against an alias-exporting module (BS_ALIAS=thin, rule S).
# CLAIM (ticket 62 option 2): "`:Shop.new(1)` works from Elixir while `New` still works from Erlang and B#."
# REFUTED IF: any unquoted snake alias still needs quoting, i.e. a SyntaxError for e.g. `:Casing.http_get(1)`.
# Expected partial refutation: derived names that are Elixir RESERVED words (`do`, `end`, `fn`, `nil`, `true`, `when`, `and`, `not`, `of`?) .
. "$(dirname "$0")/lib.sh"; build_alias_compiler || exit 1
B="$HERE/b"; O="$SCRATCH/p07"; rm -rf "$O"; mkdir -p "$O"
BS_ALIAS=thin "$BSC_ALIAS" --src-root "$B" -o "$O" "$B/Casing" 2>&1 | head -3
cat > "$SCRATCH/p07.exs" <<'EXEOF'
Code.prepend_path(System.get_env("BS_EBIN"))
for n <- ~w(http_get to_json add2 vec3_dot foo_bar get_http_response io_list new spawn abs do end if fn nil true when and not case receive of) do
  src = ":Casing.#{n}(1)"
  parses =
    case Code.string_to_quoted(src) do
      {:ok, _} -> :parses
      {:error, {_, msg, _}} -> {:SYNTAX_ERROR, msg |> String.split(".") |> hd |> String.slice(0, 50)}
    end
  runs =
    case parses do
      :parses -> try do {:ok, elem(Code.eval_string(src), 0)} rescue e -> {:raised, e.__struct__} end
      _ -> :skipped
    end
  quoted = try do {:ok, elem(Code.eval_string(":Casing.\"#{n}\"(1)"), 0)} rescue e -> {:raised, e.__struct__} end
  IO.puts(String.pad_trailing(src, 26) <> String.pad_trailing(inspect(parses), 62) <> String.pad_trailing(inspect(runs), 10) <> " quoted-form: " <> inspect(quoted))
end
EXEOF
cat >> "$SCRATCH/p07.exs" <<'EXEOF'
imp = try do {:ok, elem(Code.eval_string("import :Casing, only: [http_get: 1]; http_get(1)"), 0)} rescue e -> {:raised, e.__struct__} end
IO.puts("import :Casing, only: [http_get: 1]; http_get(1)  -> " <> inspect(imp))
EXEOF
BS_EBIN="$O" elixir "$SCRATCH/p07.exs" 2>&1 | grep -v "^warning\|^└─\|^$"
