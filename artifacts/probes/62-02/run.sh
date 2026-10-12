#!/usr/bin/env bash
# Probe 62-02: the quoted-call rescue `:Shop."New"(1)` in real files: warnings, formatter,
# pipes, import, tokens, capture, @compile/dialyzer-free use inside a module; plus the
# Elixir-alias trap (Shop."New" resolves to Elixir.Shop, not B#'s atom `Shop`).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BSC=/home/user/beam-sharp/compiler/_build/default/bin/bsc
EX=/home/user/beam-sharp/compiler/examples
W=$(mktemp -d); mkdir -p $W/ebin
$BSC --src-root $EX -o $W/ebin $EX/Shop >/dev/null 2>&1
cp "$HERE/use.ex" $W/use.ex
cd $W
echo "--- elixirc use.ex (warnings are shown, then run)"
elixirc -pa ebin use.ex 2>&1
elixir -pa ebin -pa . -e 'IO.inspect(UseIt.run())' 2>&1
echo "--- mix format style (Code.format_string!) of the quoted call"
elixir -e 'IO.puts(Code.format_string!(~S|x = :Shop."New"(1)|)); IO.puts(Code.format_string!(~S|x = :Shop.'"'"'New'"'"'(1)|))'
echo "--- tokens"
elixir -e 'for s <- [~S|:Shop.New(1)|, ~S|:Shop."New"(1)|, ~S|:Shop.new(1)|], do: (IO.puts(s); IO.inspect(:elixir_tokenizer.tokenize(String.to_charlist(s), 1, []), limit: :infinity))'
rm -rf $W
