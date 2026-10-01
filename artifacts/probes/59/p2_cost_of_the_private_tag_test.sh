#!/usr/bin/env bash
# Ticket 59 cost half: bytes and ns/call of the tag test on a PRIVATE function, HEAD vs the exported-only variant.
# Usage: BSC_HEAD=<bsc> BSC_VARIANT=<bsc> bash p2_cost_of_the_private_tag_test.sh
set -u; here=$(cd "$(dirname "$0")" && pwd)
H=${BSC_HEAD:?}; V=${BSC_VARIANT:?}
d=$(mktemp -d); mkdir -p $d/head $d/var
"$H" -o $d/head "$here/prog/Shop59" || exit 1; "$V" -o $d/var "$here/prog/Shop59" || exit 1
for k in head var; do printf '%-8s Shop59.beam = %s bytes\n' $k "$(stat -c%s $d/$k/Shop59.beam)"; done
cat > $d/b.erl <<'EOF'
-module(b).
-export([run/1]).
run(Dir) ->
  L = [#{'Kind' => 'Shop59.Order', 'Id' => I, 'Total' => I} || I <- lists:seq(1, 100000)],
  [begin
     code:purge('Shop59'), code:delete('Shop59'),
     {module, _} = code:load_abs(filename:join([Dir, Name, "Shop59"])),
     Ts = lists:sort([begin {U, _} = timer:tc(fun() -> [ 'Shop59':'SumAll'(L) || _ <- lists:seq(1, 20) ] end), U*1000/(20*100000) end || _ <- lists:seq(1, 7)]),
     io:format("~-6s SumAll over 100k orders: ~p ns/element (min/median/max of 7)~n", [Name, [round(X*100)/100 || X <- [hd(Ts), lists:nth(4, Ts), lists:last(Ts)]]])
   end || Name <- ["head", "var", "head", "var"]].
EOF
erlc -o $d $d/b.erl && erl -noshell -pa $d -eval 'b:run("'$d'"), halt().'
echo "--- disassembly: the private function One/1, HEAD vs variant (instruction count)"
for k in head var; do erl -noshell -eval '{beam_file,_,_,_,_,Fs}=beam_disasm:file("'$d/$k/Shop59.beam'"), [io:format("'$k' ~p: ~p instructions~n",[{N,A},length(Is)]) || {function,N,A,_,Is} <- Fs, N=:='"'"'One'"'"'], halt().'; done
