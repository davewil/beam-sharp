#!/usr/bin/env bash
# Elixir 1.14 is OTP25-only. Extract the Erlang abstract forms Elixir generates (OTP25 erl),
# then recompile them with the OTP 28 compiler so Elixir's *generated code* gets OTP 28's optimiser/type chunk.
. "$(dirname "$0")/env.sh"
PATH=/usr/bin:/usr/lib/elixir/bin:$PATH
erl -noshell -pa /usr/lib/elixir/lib/elixir/ebin -eval '
 {ok,{_,[{debug_info,{debug_info_v1,B,D}}]}} = beam_lib:chunks("'$W'/ex25/Elixir.BenchEx.beam",[debug_info]),
 {ok,Forms} = B:debug_info(erlang_v1,'"'"'Elixir.BenchEx'"'"',D,[]),
 file:write_file("'$W'/ex_forms.term", io_lib:format("~p.~n",[Forms])),
 io:format("backend ~p, ~p forms~n",[B,length(Forms)]), halt().'
PATH=/opt/otp28/bin:$PATH erl -noshell -eval '
 {ok,[Forms]} = file:consult("'$W'/ex_forms.term"),
 {ok,M,Bin} = compile:forms(Forms,[return_errors]),
 file:write_file("'$W'/ebin/Elixir.BenchEx.beam",Bin), io:format("compiled ~p with OTP28~n",[M]), halt().'
