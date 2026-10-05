#!/usr/bin/env bash
# gen_shop.sh DIR NAME MODE  -- writes a Req-sized foreign surface: 4 apps, 10 `using` blocks.
# MODE=using  -> `[app: X]` on every block ; MODE=module -> one `[app: a, b, c, d]` on the module ; MODE=none -> no markers
D=$1; N=$2; MODE=$3; mkdir -p "$D"
declare -A APP=( [Elixir.Req]=req [Elixir.Req.Request]=req [Elixir.Req.Response]=req [Elixir.Req.Steps]=req
                 [Elixir.Finch]=finch [Elixir.Finch.Request]=finch [Elixir.Mint.HTTP]=mint [Elixir.Mint.Types]=mint
                 [Elixir.Jason]=jason [Elixir.Jason.Encoder]=jason )
ORDER=(Elixir.Req Elixir.Req.Request Elixir.Req.Response Elixir.Req.Steps Elixir.Finch Elixir.Finch.Request Elixir.Mint.HTTP Elixir.Mint.Types Elixir.Jason Elixir.Jason.Encoder)
{
  if [ "$MODE" = module ]; then echo "[app: req, finch, mint, jason] module $N"; else echo "module $N"; fi
  echo
  for m in "${ORDER[@]}"; do
    if [ "$MODE" = using ]; then echo "[app: ${APP[$m]}] using :'$m' {"; else echo "using :'$m' {"; fi
    echo "    term call(term a)"
    echo "}"
    echo
  done
  echo "public term Go(term a)"
  echo "Go(a) -> :'Elixir.Req'.call(a)"
} > "$D/$N.bs"
