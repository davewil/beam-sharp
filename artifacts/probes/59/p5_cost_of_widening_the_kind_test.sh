#!/usr/bin/env bash
# Ticket 59, cost of the widened int KIND test on a private function: ns per element through Total/1 -> private Band/1,
# HEAD vs variant_kind_test_on_private_too.patch. Run on an otherwise idle machine; alternates builds 4x.
# Usage: BSC_HEAD=<bsc> BSC_VARIANT=<bsc> bash p5_cost_of_widening_the_kind_test.sh
set -u; here=$(cd "$(dirname "$0")" && pwd); H=${BSC_HEAD:?}; V=${BSC_VARIANT:?}
d=$(mktemp -d); mkdir -p $d/head $d/var
"$H" -o $d/head "$here/prog/Kind59" || exit 1; "$V" -o $d/var "$here/prog/Kind59" || exit 1
for k in head var; do printf '%-6s Kind59.beam = %s bytes\n' $k "$(stat -c%s $d/$k/Kind59.beam)"; done
cat > $d/b.erl <<'EOF'
-module(b).
-export([run/1]).
run(Dir) ->
  L = [I rem 20 || I <- lists:seq(1, 100000)],
  [begin
     code:purge('Kind59'), code:delete('Kind59'),
     {module, _} = code:load_abs(filename:join([Dir, Name, "Kind59"])),
     Ts = lists:sort([begin {U, _} = timer:tc(fun() -> [ 'Kind59':'Total'(L) || _ <- lists:seq(1, 20) ] end), U*1000/(20*100000) end || _ <- lists:seq(1, 7)]),
     io:format("~-6s Total over 100k ints: ~p ns/element (min/median/max of 7)~n", [Name, [round(X*100)/100 || X <- [hd(Ts), lists:nth(4, Ts), lists:last(Ts)]]])
   end || Name <- ["head", "var", "head", "var", "head", "var"]].
EOF
erlc -o $d $d/b.erl && erl -noshell -pa $d -eval 'b:run("'$d'"), halt().'
