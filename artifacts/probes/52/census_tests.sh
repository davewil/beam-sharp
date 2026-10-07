#!/usr/bin/env bash
# How many compiler tests and compile-checked docs name a foreign module that does NOT resolve
# on a stock OTP path? Each would be refused by an unconditional "module must be on the code path" check.
export PATH=$HOME/.nix-profile/bin:$PATH
ROOT=$(cd "$(dirname "$0")/../../.." && pwd); cd "$ROOT"
EL=$(elixir -e 'IO.puts Path.dirname(:code.lib_dir(:elixir))' 2>/dev/null)
grep -rhoE "using :('[^']+'|[a-z_A-Z0-9]+) *\{" compiler/test/*.erl compiler/test/*/* LANGUAGE.md compiler/examples --include='*' 2>/dev/null \
  | grep -v _build | sed -E "s/using :(.*) *\{/\1/; s/ +$//; s/^'(.*)'$/\1/" | sort | uniq -c | sort -rn > /tmp/c.$$
total=0; bad=0
while read n m; do
  ok=$(ERL_LIBS=$EL erl -noshell -eval "io:format(\"~p\", [code:which(list_to_atom(\"$m\")) =/= non_existing]), halt().")
  printf '%5s  %-22s %s\n' "$n" "$m" "$ok"
  total=$((total+n)); [ "$ok" = false ] && bad=$((bad+n))
done < /tmp/c.$$
echo "foreign blocks: $total; naming a module absent from the stock path: $bad"
rm -f /tmp/c.$$
