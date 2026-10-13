-module(erl_neg).
-export([main/0]).
main() ->
  P = fun(S) -> {ok,T,_}=erl_scan:string(S), {ok,F}=erl_parse:parse_form(T), io:format("~s~n   ~p~n",[S,F]) end,
  P("f(X) when X >= -5 -> X."),
  P("f(-5) -> a."),
  %% what the compiler's own passes do with it: compile to abstract code after lint, look for the folded form
  {ok,Ts,_}=erl_scan:string("f(-5) -> a. g(X) when X >= -5 -> X."),
  io:format("~s~n",["-- after sys_pre_expand/v3 core? show Core via compile 'dcore'"]).
