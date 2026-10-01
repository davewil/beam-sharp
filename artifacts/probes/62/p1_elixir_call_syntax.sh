#!/usr/bin/env bash
# Ticket 62, claim 1: "Elixir cannot call a PascalCase export, and no module prefix fixes it".
# Builds a beam whose module is `Shop` and whose exports are PascalCase (what bsc emits), then
# tries every Elixir call spelling. Run as: bash p1_elixir_call_syntax.sh
set -u
W=$(mktemp -d); cd "$W"
cat > Shop.erl <<'EOF'
-module('Shop').
-export(['New'/1, 'Total'/1, new/1]).
'New'(Id) -> #{'Kind' => 'Shop.Order', 'Id' => Id, 'Total' => 0}.
'Total'(#{'Kind' := 'Shop.Order', 'Total' := T}) -> T.
new(Id) -> 'New'(Id).
EOF
erlc Shop.erl || exit 1
try() { # label, elixir source
  printf '%-48s -> ' "$1"
  out=$(elixir -pa . -e "$2" 2>&1); rc=$?
  if [ $rc -ne 0 ]; then echo "FAIL: $(echo "$out" | head -2 | tr '\n' ' ')"; else echo "OK: $out"; fi
}
try ':Shop.New(1)'                       'IO.inspect(:Shop.New(1))'
try ':Shop."New"(1)   (quoted fun name)' 'IO.inspect(:Shop."New"(1))'
try ':"Shop"."New"(1)'                   'IO.inspect(:"Shop"."New"(1))'
try 'apply(:Shop, :New, [1])'            'IO.inspect(apply(:Shop, :New, [1]))'
try ':Shop.new(1)  (hand-written alias)' 'IO.inspect(:Shop.new(1))'
try 'Kernel.then pipe: 1 |> :Shop."New"()' 'IO.inspect(1 |> :Shop."New"())'
try 'Total on a struct-like arg'         'IO.inspect(:Shop."Total"(:Shop."New"(5)))'
try 'import :Shop, only: [..] ?'         'import :Shop, only: [new: 1]; IO.inspect(new(3))'
try 'defdelegate in an Elixir wrapper'   'defmodule W do
  defdelegate new_order(id), to: :Shop, as: :New
end
IO.inspect(W.new_order(2))'
