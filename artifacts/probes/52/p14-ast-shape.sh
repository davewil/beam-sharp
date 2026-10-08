#!/usr/bin/env bash
# P14: parse tree of a foreign declaration, stock vs prototype 52x. Shows the AST change that is the root of the compiler delta.
# stock must refuse the `in :req` form (syntax error) = negative control; proto must accept both.
W=$(mktemp -d)
printf "module M\nusing :'Elixir.Req' {\n    term new(list<term> o)\n}\n" > $W/plain.bs
printf "module M\nusing :'Elixir.Req' in :req {\n    term new(list<term> o)\n}\n" > $W/app.bs
for b in stock:/tmp/bsbuild/ebin proto:/tmp/bsb_52_x/ebin; do for f in plain app; do
  printf '%-5s %-5s -> ' ${b%%:*} $f
  erl -noshell -pa ${b#*:} -eval '
    {ok,B}=file:read_file("'$W/$f.bs'"), {ok,T,_}=bs_lexer:string(binary_to_list(B)),
    case bs_parser:parse(T) of {ok,A} -> io:format("~p~n",[[X||X<-A, element(1,X)==foreign]]); {error,{L,_,[M|_]}} -> io:format("parse error line ~p: ~s~n",[L,M]) end, halt().'
done; done
