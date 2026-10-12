#!/usr/bin/env bash
# Probe 62-05: Elixir CAN define capitalised/odd function names via unquote; Erlang can call them;
# Elixir dot-syntax cannot without the quoted-call form. Erlang -export(['New'/1]) quoted atoms.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W=$(mktemp -d); cp $HERE/w.ex $HERE/e.erl $W/; cd $W
echo "--- elixirc w.ex"; elixirc w.ex 2>&1
echo "--- erlc e.erl"; erlc e.erl 2>&1
echo "--- Erlang calls Elixir-defined capitalised fn"
erl -noshell -pa . -eval 'io:format("~p ~p ~p~n",[(list_to_atom("Elixir.Weird")):'"'"'New'"'"'(1), (list_to_atom("Elixir.Weird")):'"'"'weird name'"'"'(2), (list_to_atom("Elixir.Weird")):selfcall()]), io:format("exports: ~p~n",[(list_to_atom("Elixir.Weird")):module_info(exports)]), halt().'
echo "--- Elixir dot-syntax on its own capitalised fn"
elixir -pa . -e 'IO.inspect(Code.string_to_quoted("Weird.New(1)") |> elem(0)); IO.inspect(Weird."New"(1)); IO.inspect(apply(Weird, :New, [1])); IO.inspect(Weird.module_info(:exports))'
echo "--- Erlang -export(['New'/1]) module e; Elixir calls"
elixir -pa . -e 'IO.inspect(:e.module_info(:exports)); IO.inspect(:e."New"(1)); IO.inspect(:e.new(1))'
rm -rf $W
