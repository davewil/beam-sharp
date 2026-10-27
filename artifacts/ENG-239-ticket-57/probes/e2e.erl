%% Source -> real lexer(shim)/parser/checker -> real bs_emit:forms -> compile:forms -> load -> call.
-module(e2e).
-export([main/0]).
build(Src) -> try build1(Src) catch error:{opaque_refinement, L} -> {declaration_refused, opaque_refinement, L} end.
build1(Src) ->
  D = drv:parse(Src),
  case bs_check:check(D) of
    {ok, Module, _} ->
      Forms = bs_emit:forms(Module),
      case compile:forms(Forms, [return_errors, binary]) of
        {ok, Mod, Bin} -> {module, Mod} = code:load_binary(Mod, "m.beam", Bin), {ok, Mod};
        Err -> {erlc_refused, Err}
      end;
    {error, Errs} -> {bsc_refused, [element(1, element(4, E)) || E <- Errs]}
  end.
call(Mod, F, Args) -> try {ok, apply(Mod, F, Args)} catch C:R -> {C, R} end.
main() ->
  P1 = "module M\ntype NonPos = int where value <= 0\npublic NonPos Back()\nBack() -> -1\n"
       "public atom Band(int n)\nBand(n) when n >= -1 -> :high\nBand(n) when n < -1 -> :low\n",
  case build(P1) of
    {ok, M} -> io:format("P1 Back()=~p Band(-1)=~p Band(-2)=~p Band(0)=~p~n",
                         [call(M,'Back',[]), call(M,'Band',[-1]), call(M,'Band',[-2]), call(M,'Band',[0])]);
    X -> io:format("P1 ~p~n", [X])
  end,
  P2 = "module M\npublic int Div(int n)\nDiv(n) -> n / -0\n",
  case build(P2) of
    {ok, M2} -> io:format("P2 Div(10) -> ~p~n", [call(M2,'Div',[10])]);
    X2 -> io:format("P2 ~p~n", [X2])
  end,
  P3 = "module M\ntype Delta = int where value >= -10 and value <= 10\npublic Delta Clamp(int n)\n"
       "Clamp(n) when n < -10 -> -10\nClamp(n) when n > 10 -> 10\nClamp(n) -> n\n",
  case build(P3) of
    {ok, M3} -> io:format("P3 Clamp(-99)=~p Clamp(4)=~p Clamp(99)=~p~n", [call(M3,'Clamp',[-99]), call(M3,'Clamp',[4]), call(M3,'Clamp',[99])]);
    X3 -> io:format("P3 ~p~n", [X3])
  end.
