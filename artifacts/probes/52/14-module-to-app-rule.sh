#!/usr/bin/env bash
# CLAIM (mine): the application cannot be derived from the module atom by any naming rule, so a declaration
# (or a build-machine lookup) is needed.  Measured over every .app installed with this toolchain
# (OTP + Elixir's six apps), using the `modules` key of each .app file.
# Rule tested: app == snake_case(first segment of the module after `Elixir.`) for Elixir modules,
#              app == module name for Erlang modules.
# REFUTED IF: the rule matches (say) >95% of modules.
. "$(dirname "$0")/lib.sh"
find "$SCRATCH/env/lib" -name '*.app' | sort > "$WORK/apps14.txt"
erl -noshell -eval '
{ok,B}=file:read_file("'$WORK'/apps14.txt"), Fs=string:tokens(binary_to_list(B),"\n"),
Snake=fun(S)-> L=re:replace(S,"([a-z0-9])([A-Z])","\\1_\\2",[global,{return,list}]), string:lowercase(L) end,
Rows=lists:flatmap(fun(F)->
  case file:consult(F) of
    {ok,[{application,App,P}]} -> [{App,M}||M<-proplists:get_value(modules,P,[])];
    _ -> [] end end, Fs),
IsEx=fun({_,M})-> lists:prefix("Elixir.",atom_to_list(M)) end,
{Ex,Er}=lists:partition(IsEx,Rows),
Derive=fun({App,M})->
   S=atom_to_list(M),
   D=case lists:prefix("Elixir.",S) of
       true -> [First|_]=string:split(string:slice(S,7),"."), Snake(First);
       false -> S end,
   list_to_atom(D)=:=App end,
Rep=fun(Label,Rs)-> N=length(Rs), Ok=length([R||R<-Rs,Derive(R)]),
   io:format("~-24s modules=~5w  rule-derives-the-right-app=~5w  (~.1f%)~n",[Label,N,Ok,100*Ok/max(1,N)]) end,
Rep("Elixir-compiled modules",Ex), Rep("Erlang modules",Er),
%% the same for the apps a consumer would actually declare: per app, does ANY module match?
Apps=lists:usort([A||{A,_}<-Ex]),
io:format("Elixir apps: ~p~n",[Apps]),
[io:format("  ~-8w e.g. ~s ~s~n",[A,hd([M||{A2,M}<-Ex,A2=:=A]),
   case [M||{A2,M}<-Ex,A2=:=A,Derive({A2,M})] of [] -> "(no module of this app derives)"; _ -> "(derivable)" end])||A<-Apps],
halt().'
