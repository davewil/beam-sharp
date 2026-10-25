#!/usr/bin/env bash
# P6: export table is all-or-nothing per function; size cost of exported vs local. Ticket 18 s5 re-check.
export PATH=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/beam/bin:$PATH LANG=C.UTF-8
cd "$(dirname "$0")/export"; rm -f *.beam
erlc +no_inline m_all.erl m_one.erl m_friend.erl 2>&1
erl -noshell -eval '
[begin
   {ok, B} = file:read_file(atom_to_list(M) ++ ".beam"),
   {ok, {M, Ch}} = beam_lib:chunks(B, [exports, locals, "ExpT", "LocT"]),
   io:format("~-9s beam=~p bytes exports=~p locals=~p ExpT=~p LocT=~p~n",
     [M, byte_size(B), [E || E={N,_} <- proplists:get_value(exports, Ch), N =/= module_info],
      proplists:get_value(locals, Ch), byte_size(proplists:get_value("ExpT", Ch)),
      byte_size(proplists:get_value("LocT", Ch))])
 end || M <- [m_all, m_friend, m_one]],
%% callers: any module can reach an exported function; nothing restricts WHICH
true = code:add_patha("."),
io:format("m_friend:g(1) from the shell (an arbitrary caller): ~p~n", [m_friend:g(1)]),
io:format("m_one:g(1) (local): ~p~n", [catch m_one:g(1)]),
halt().'
