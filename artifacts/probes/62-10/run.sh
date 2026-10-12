#!/usr/bin/env bash
# Probe 62-10: with the alias prototype (62-06/alias.patch), does Elixir dot syntax work, and what
# do collisions / acronyms / behaviour callbacks do?
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO=/home/user/beam-sharp; W=$(mktemp -d); mkdir -p $W/c $W/src/Names2 $W/o; cd $W
(cd $REPO/compiler && tar --exclude=_build --exclude=examples --exclude=test --exclude=bench -cf - .) | tar -xf - -C $W/c
patch -s $W/c/src/bs_emit.erl < $HERE/../62-06/alias.patch && (cd $W/c && rebar3 escriptize >/dev/null 2>&1) || { echo BUILD FAILED; exit 1; }
B=$W/c/_build/default/bin/bsc; EX=$REPO/compiler/examples
echo "=== 1. Shop with aliases: Elixir dot syntax"
BS_ALIAS=spec $B --src-root $EX -o $W/o $EX/Shop >/dev/null 2>&1
elixir -pa $W/o -e '
IO.inspect(:Shop.new(7), label: ":Shop.new(7)")
IO.inspect(:Shop.which(%{Kind: :"Shop.Order", Id: 9, Total: 5}), label: ":Shop.which(...)")
IO.inspect(:Shop.module_info(:exports) |> Enum.sort(), label: "exports")'
echo "=== 2. a module whose names collide / are acronyms"
cat > $W/src/Names2/names2.bs <<'BS'
module Names2

public int GetId(int x)

GetId(x) -> x + 1

public int GetID(int x)

GetID(x) -> x + 2

public int HTTPGet(int x)

HTTPGet(x) -> x + 3

public int ToJson(int x)

ToJson(x) -> x + 4

public int Sha256Hash(int x)

Sha256Hash(x) -> x + 5
BS
BS_ALIAS=spec $B --src-root $W/src -o $W/o $W/src/Names2 2>&1 | head
erl -noshell -pa $W/o -eval 'io:format("exports: ~p~n",[[E || {N,_}=E <- '"'"'Names2'"'"':module_info(exports), is_atom(N), hd(atom_to_list(N)) >= $a]]), io:format("get_id(1) = ~p  (GetId says 2, GetID says 3: whichever alias won)~n",['"'"'Names2'"'"':get_id(1)]), halt().'
echo "=== 3. GenServer module: Init/HandleCall already lower to init/handle_call, alias must skip them"
cp -r $EX/Counter $W/src/ 2>/dev/null; BS_ALIAS=spec $B --src-root $EX -o $W/o $EX/Counter 2>&1 | head -5
erl -noshell -pa $W/o -eval 'io:format("Counter exports: ~p~n",['"'"'Counter'"'"':module_info(exports)]), halt().'
rm -rf $W
