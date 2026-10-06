#!/usr/bin/env bash
# p2 — is the syntax the ticket proposes extending the syntax the compiler has?
# Ticket 52 writes   [external: elixir, app: req] using :'Elixir.Req' { ... }
# Ticket 32 decided  [external: erlang, "ets"] module Ets { ... }
# Claims tested against the CURRENT compiler:
#   S1  CONTROL: the shipped form `using :'Elixir.Req' { ... }` compiles (quoted atom is lexed; LANGUAGE.md §11's "not lexed yet" is stale)
#   S2  the ticket's literal `[external: elixir, app: req] using ...` is a syntax error
#   S3  32's `[external: erlang, "ets"] module Ets {...}` is a syntax error (the shipped construct is `using :ets {...}`)
#   S4  there is no declaration-attribute grammar at all: even `[app: req]` alone before `using` is refused
#   S5  `[module: GenServer]` (cited by 32 as the existing attribute syntax) is refused; behaviours are `behaviour GenServer`
#   S6  grep: the parser's only '[' productions are list/pattern/comprehension, none at declaration level
source "$(dirname "$0")/common.sh"
try () { # try <name> <body>  -> prints the first diagnostic line, or ACCEPTED
  bs_module "$1" "$2"; out=$($BSC --src-root "$WORK/src" -o "$WORK/o_$1" "$WORK/src/$1" 2>&1); if [ -z "$out" ]; then echo ACCEPTED; else echo "$out" | head -1 | sed "s|$WORK/||"; fi; }
r=$(try S1 "using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
public term Go()
Go() -> :'Elixir.Req'.new([])"); echo "S1 shipped form: $r"; expect "S1 control: shipped form accepted" ACCEPTED "$r"
r=$(try S2 "[external: elixir, app: req] using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
public term Go()
Go() -> :'Elixir.Req'.new([])"); echo "S2 ticket's literal form: $r"; expect_not "S2 ticket form is refused" ACCEPTED "$r"
r=$(try S3 '[external: erlang, "ets"]
module Ets {
    list<term> Lookup(atom, term)
}'); echo "S3 ticket 32's form: $r"; expect_not "S3 ticket 32 form is refused" ACCEPTED "$r"
r=$(try S4 "[app: req]
using :lists {
    int sum(list<int> xs)
}
public int Go()
Go() -> :lists.sum([1])"); echo "S4 bare attribute: $r"; expect_not "S4 no attribute grammar" ACCEPTED "$r"
r=$(try S5 "[module: GenServer]
public int Go()
Go() -> 1"); echo "S5 [module: GenServer]: $r"; expect_not "S5 module attribute refused" ACCEPTED "$r"
echo "S6 parser productions mentioning '[' :"
grep -n "'\['" compiler/src/bs_parser.yrl | sed 's/^/   /'
n=$(grep -n "'\['" compiler/src/bs_parser.yrl | grep -c "^[0-9]*:decl\|foreign_decl\|using_decl\|module_decl"); echo "   declaration-level '[' productions: $n"
expect "S6 none at declaration level" "declaration-level '[' productions: 0" "declaration-level '[' productions: $n"
finish
