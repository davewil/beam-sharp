#!/usr/bin/env escript
%% (d) cost in .beam bytes (and compile time) of carrying a dependency attribute.
%% usage: m2_beam_size.escript Dir.abstr   -- hand-edits the abstract forms bsc emitted, recompiles with compile:forms
main([Abstr, ModAtom]) ->
  {ok, Forms0} = file:consult(Abstr),
  Usings = usings(ModAtom),
  io:format("module ~s: ~w forms; foreign modules declared = ~w~n", [Abstr, length(Forms0), length(Usings)]),
  Variants = [
    {"V0 baseline (no attribute)",                       fun(F) -> F end},
    {"V1 one attr per using: -bs_dep({Mod,elixir,App})", fun(F) -> ins(F, [{attribute,1,bs_dep,{M,elixir,A}} || {M,A} <- Usings]) end},
    {"V2 one attr per module, deduped apps: -bs_deps([App..])", fun(F) -> ins(F, [{attribute,1,bs_deps,lists:usort([A || {_,A} <- Usings])}]) end},
    {"V3 one attr per using, WITH version string", fun(F) -> ins(F, [{attribute,1,bs_dep,{M,elixir,A,"~> 0.7"}} || {M,A} <- Usings]) end},
    {"V4 attr per using, long names (control: big payload)", fun(F) -> ins(F, [{attribute,1,bs_dep,{M,elixir,list_to_atom(lists:duplicate(40,$x)++atom_to_list(A))}} || {M,A} <- Usings]) end}
  ],
  Base = size(Forms0, fun(F) -> F end),
  lists:foreach(fun({Name, Fun}) ->
    Forms = Fun(Forms0),
    Bytes = [size(Forms, Dbg) || Dbg <- [[], [debug_info]]],
    {B0, B1} = list_to_tuple(Bytes),
    Attr = [A || {attribute,_,K,A} <- Forms, lists:member(K,[bs_dep,bs_deps])],
    io:format("~-62s  no-debug_info=~6w B (delta ~s)   debug_info=~6w B (delta ~s)   attr term flat_size=~w words~n",
              [Name, B0, d(B0 - element(1,Base)), B1, d(B1 - element(2,Base)), erts_debug:flat_size(Attr)])
  end, Variants),
  %% compile time, 30 runs each of V0 vs V1
  Time = fun(Fun) ->
     Fs = Fun(Forms0),
     Ts = lists:sort([element(1, timer:tc(fun() -> {ok,_,_} = compile:forms(Fs,[binary,debug_info]) end)) || _ <- lists:seq(1,30)]),
     {lists:nth(15,Ts), hd(Ts), lists:last(Ts)}
  end,
  [io:format("compile:forms time (30 runs, us): ~-58s median=~w min=~w max=~w~n", [N, M, Mi, Ma])
   || {N,Fn} <- [hd(Variants), lists:nth(2,Variants), lists:nth(3,Variants)], {M,Mi,Ma} <- [Time(Fn)]],
  %% is the attribute readable without loading? and loaded?
  {ok,_,Bin} = compile:forms(ins(Forms0, [{attribute,1,bs_deps,lists:usort([A || {_,A} <- Usings])}]),[binary,debug_info]),
  {ok,{_,[{attributes,At}]}} = beam_lib:chunks(Bin,[attributes]),
  io:format("beam_lib:chunks(Bin,[attributes]) without loading: ~p~n", [[X || {K,_}=X <- At, K =/= vsn]]).

d(N) when N >= 0 -> "+" ++ integer_to_list(N);
d(N) -> integer_to_list(N).

size(Forms, Opts) when is_list(Opts) -> {ok,_,B} = compile:forms(Forms, [binary|Opts]), byte_size(B);
size(Forms, Fun) when is_function(Fun) ->
  S = fun(Opts) -> {ok,_,B} = compile:forms(Fun(Forms), [binary|Opts]), byte_size(B) end,
  {S([]), S([debug_info])}.

%% the attributes go after `-module` and `-export` (first two forms)
ins([M, E | Rest], Attrs) -> [M, E | Attrs] ++ Rest.

%% Which foreign modules does the module declare? Read from the B# source's `using` lines; app name = lowercased tail.
usings(_ModAtom) ->
  Src = os:getenv("BS_SRC"),
  {ok, Bin} = file:read_file(Src),
  {match, Ms} = re:run(Bin, "using :('[^']+'|[a-z_]+)", [global, {capture, [1], list}]),
  [{list_to_atom(strip(M)), app_of(strip(M))} || [M] <- Ms].
strip(S) -> lists:filter(fun(C) -> C =/= $' end, S).
app_of("Elixir." ++ Rest) -> list_to_atom(string:lowercase(Rest));
app_of(Other) -> list_to_atom(Other).
