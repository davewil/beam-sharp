-module(gl_forge).
-export([main/0]).
main() ->
  F = fun(L,Th) -> io:format("~-34s ~p~n",[L, (catch Th())]) end,
  Forged = {quote, <<"x">>, <<"free">>},
  F("pub_total(forged tuple)", fun() -> probe:pub_total(Forged) end),
  F("pub_total(not even a tuple)", fun() -> probe:pub_total(foo) end),
  F("pub_total(wrong tag, right arity)", fun() -> probe:pub_total({quote, 1, 2}) end),
  F("pub_total(valid order)", fun() -> probe:pub_total({order,1,2}) end),
  F("first([forged payload])", fun() -> probe:first([{order, 1, <<"free">>}]) end),
  F("pub_int(1.5)", fun() -> probe:pub_int(1.5) end),
  F("pub_secret(forged opaque)", fun() -> probe:pub_secret({other, <<"x">>}) end).
