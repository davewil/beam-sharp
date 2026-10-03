#!/bin/sh
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
cd "$(dirname "$0")"; W=${WORK:-/tmp/bs59-work}/erl; mkdir -p $W; erlc -o $W erl_head.erl
echo "-- private head with a record pattern (disassembled):"
erl -noshell -eval '{beam_file,_,_,_,_,Fs}=beam_disasm:file("'$W'/erl_head.beam"), [io:format("~p~n",[I]) || {function,amount,1,_,Is} <- Fs, I <- Is, element(1,I)=:=test orelse element(1,I)=:=get_tuple_element], halt().'
erl -noshell -pa $W -eval '
R = fun(F) -> try {returned, F()} catch C:E -> {C, E} end end,
io:format("via_cart({cart,{invoice,1,999},1})   => ~p~n", [R(fun() -> erl_head:via_cart({cart,{invoice,1,999},1}) end)]),
io:format("via_cart({cart,{order,1,999},1})     => ~p~n", [R(fun() -> erl_head:via_cart({cart,{order,1,999},1}) end)]),
io:format("spec_only(1.5)  (-spec integer())    => ~p~n", [R(fun() -> erl_head:spec_only(1.5) end)]),
io:format("gen_server exports try_handle_call/4? => ~p~n", [lists:member({try_handle_call,4}, gen_server:module_info(exports))]),
halt().'
