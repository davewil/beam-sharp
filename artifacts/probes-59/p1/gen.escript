#!/usr/bin/env escript
%% Generates modules modelling emitted shapes; compiles; reports size deltas.
%% Shape (from bs_emit:tag_test/3 line 590): exported f(O) when map_get('Kind',O) == 'M.Order'
main(_) ->
  Ns = [1,5,20],
  io:format("~-6s ~-22s ~8s ~8s ~8s ~8s~n",["N","variant","beam","stripped","Code","instrs"]),
  [ [row(N,V) || V <- [none, tag_guard, tag_pattern, is_integer_only, int_unguarded_ctl]] || N <- Ns ].

fields(N) -> [list_to_atom("f"++integer_to_list(I)) || I <- lists:seq(1,N)].

src(N, V) ->
  Fs = fields(N),
  Build = string:join([io_lib:format("~p => ~p",[F,I]) || {F,I} <- lists:zip(Fs, lists:seq(1,N))], ", "),
  Mk = io_lib:format("mk() -> #{'Kind' => 'M.Order', ~s}.~n", [Build]),
  Body = "map_get(f1, O)",
  Fun = case V of
    none        -> io_lib:format("total(O) -> ~s.~n",[Body]);
    tag_guard   -> io_lib:format("total(O) when map_get('Kind', O) == 'M.Order' -> ~s.~n",[Body]);
    tag_pattern -> io_lib:format("total(#{'Kind' := 'M.Order'} = O) -> ~s.~n",[Body]);
    %% int-kind test on an int param: body is arithmetic
    is_integer_only -> "total(O) when is_integer(O) -> O + 1.\n";
    int_unguarded_ctl -> "total(O) -> O + 1.\n"   %% negative control for the is_integer variant: same body, no guard
  end,
  lists:flatten(["-module(m).\n-export([mk/0,total/1]).\n", Mk, Fun]).

row(N, V) ->
  Dir = "out", ok = filelib:ensure_dir(Dir++"/x"),
  File = lists:flatten(io_lib:format("~s/m_~w_~w.erl",[Dir,N,V])),
  ok = file:write_file(File, src(N,V)),
  %% module name must be m; compile each from its own dir to keep names right
  D2 = lists:flatten(io_lib:format("~s/d_~w_~w",[Dir,N,V])), ok = filelib:ensure_dir(D2++"/x"),
  ok = file:write_file(D2++"/m.erl", src(N,V)),
  {ok,m,Bin} = compile:file(D2++"/m.erl",[binary,no_line_info]),
  {ok,m,Asm} = compile:file(D2++"/m.erl",[binary,'S',no_line_info]),
  {ok,{m,[{"Code",Code}]}} = beam_lib:chunks(Bin,["Code"]),
  {ok,{m,Stripped}} = beam_lib:strip(Bin), 
  ok = file:write_file(D2++"/m.S", io_lib:format("~p.~n",[Asm])),
  {Funs,_} = {proplists:get_value(function_decls,[]),0},
  _ = Funs,
  Instrs = count_total(Asm),
  io:format("~-6w ~-22w ~8w ~8w ~8w ~8w~n",[N,V,byte_size(Bin),byte_size(Stripped),byte_size(Code),Instrs]).

count_total({m,_Ex,_At,Fs,_}) ->
  %% instructions inside the function total/1 only
  [Code] = [C || {function,total,1,_,C} <- Fs],
  length([I || I <- Code, element(1,I) =/= label, element(1,I) =/= line]).
