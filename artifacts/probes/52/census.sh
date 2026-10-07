#!/usr/bin/env bash
# Census of `using :<atom> {` foreign blocks in the repo, split by file kind, then
# whether each module resolves on a stock OTP+Elixir code path (code:which/1).
# A module that does not resolve would be refused by a compile-time "is it on the path" check.
set -u
export PATH=$HOME/.nix-profile/bin:$PATH
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$ROOT"
pat="^using :('[^']+'|\"[^\"]+\"|[a-z_A-Z0-9]+) *\{"
for kind in bs md; do
  echo "== *.$kind (excluding _build and artifacts/)"
  grep -rEH "$pat" --include="*.$kind" . 2>/dev/null | grep -v '/_build/' | grep -v '^./artifacts/' \
    | sed -E "s/^([^:]+):.*using :(.*) *\{.*/\2/" | sed -E "s/ +$//" | sort | uniq -c | sort -rn
done > /tmp/census_raw.$$
cat /tmp/census_raw.$$
echo "== resolves on stock path? (OTP 28 + Elixir 1.18.5 lib dirs, no deps)"
EL=$(elixir -e 'IO.puts Path.dirname(:code.lib_dir(:elixir))' 2>/dev/null)
mods=$(grep -E "^ +[0-9]+ " /tmp/census_raw.$$ | awk '{print $2}' | sort -u)
for m in $mods; do
  a=$(echo "$m" | sed -E "s/^'(.*)'$/\1/; s/^\"(.*)\"$/\1/")
  ERL_LIBS=$EL erl -noshell -eval "A = list_to_atom(\"$a\"), io:format(\"~-28s ~p~n\", [\"$m\", code:which(A) =/= non_existing]), halt()."
done
rm -f /tmp/census_raw.$$
