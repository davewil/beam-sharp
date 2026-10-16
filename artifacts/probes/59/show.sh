#!/usr/bin/env bash
# show.sh ABSTR — print the emitted Erlang for each function (the .abstr is text Erlang terms)
erl -noshell -eval '{ok,F}=file:consult(hd(init:get_plain_arguments())), [io:format("~s~n",[erl_pp:form(X)]) || X<-F, element(1,X)=:=function], halt().' -extra "$1"
