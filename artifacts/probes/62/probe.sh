#!/usr/bin/env bash
# ticket 62: which Elixir call spellings reach a PascalCase export?
set -u; cd "$(dirname "$0")"; mkdir -p out; erlc -o out Shop.erl 2>&1 | grep -v '^$'
run(){ printf '%-44s -> ' "$1"; elixir -pa out -e "$1" 2>&1 | head -2 | tr '\n' ' '; echo; }
run 'IO.inspect(:Shop.New(1))'
run 'IO.inspect(:Shop."New"(1))'
run 'IO.inspect(:"Elixir.Shop"."New"(1))'
run 'IO.inspect(apply(:Shop, :New, [1]))'
run 'IO.inspect(:Shop.new(1))'
run 'f = :Shop; IO.inspect(f."New"(1))'
run 'IO.inspect(&:Shop."New"/1)'
run 'm = :Shop; IO.inspect(m.New(1))'
run 'IO.inspect(:Shop."Total"(:Shop."New"(3)))'
