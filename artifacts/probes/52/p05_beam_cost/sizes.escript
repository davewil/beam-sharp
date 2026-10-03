#!/usr/bin/env escript
%% usage: sizes.escript Probe.abstr
%% Builds provenance variants from the .abstr bsc wrote and reports bytes per chunk.
%% Variants are made by adding forms to the real forms list, so only the added form differs.
main([Abstr]) ->
    {ok, [M0 | Rest]} = file:consult(Abstr),
    {attribute,_,module,Mod} = M0,
    Pairs = [{elixir,'Elixir.String'},{elixir,'Elixir.Path'}],
    Variants = [
      {"none",                                         [M0 | Rest]},
      {"attr: [elixir]  (once per module, apps only)", [M0, {attribute,0,bs_needs,[elixir]} | Rest]},
      {"attr: [{elixir,Mod}x2]  (per block, app+module)", [M0, {attribute,0,bs_needs,Pairs} | Rest]},
      {"attr x2 + on_load check fun (2 code:which)",   [M0, {attribute,0,bs_needs,Pairs}, {attribute,0,on_load,{'bs@needs',0}} | Rest]
                                                         ++ [onload_fun(Pairs)]}
    ],
    [report(L, Mod, F) || {L, F} <- Variants],
    %% scaling: 1 vs 10 vs 50 pairs in one attribute / one on_load
    [begin
         Ps = [{app, list_to_atom("Elixir.Mod" ++ integer_to_list(I))} || I <- lists:seq(1,N)],
         report("scale: attr with " ++ integer_to_list(N) ++ " pairs", Mod, [M0, {attribute,0,bs_needs,Ps} | Rest])
     end || N <- [1, 10, 50]].

onload_fun(Needs) ->
    Body = lists:foldr(
        fun({App, M}, Acc) ->
            {'case',0,{call,0,{remote,0,{atom,0,code},{atom,0,which}},[{atom,0,M}]},
              [{clause,0,[{atom,0,non_existing}],[],
                 [{call,0,{remote,0,{atom,0,erlang},{atom,0,error}},
                   [{tuple,0,[{atom,0,bs_missing_dependency},{atom,0,App},{atom,0,M}]}]}]},
               {clause,0,[{var,0,'_'}],[],[Acc]}]}
        end, {atom,0,ok}, Needs),
    {function,0,'bs@needs',0,[{clause,0,[],[],[Body]}]}.

report(Label, Mod, Forms) ->
    {ok, Mod, Bin} = compile:forms(Forms, [binary, debug_info, return_errors]),
    {ok, Mod, Bin2} = compile:forms(Forms, [binary, return_errors]),
    {ok, Mod, Chunks} = beam_lib:all_chunks(Bin),
    Sz = fun(N) -> case lists:keyfind(N, 1, Chunks) of {_, C} -> byte_size(C); _ -> 0 end end,
    io:format("~-52s total=~5B (stripped of debug_info: ~5B)  Attr=~4B Dbgi=~4B Code=~4B AtU8=~4B~n",
              [Label, byte_size(Bin), byte_size(Bin2), Sz("Attr"), Sz("Dbgi"), Sz("Code"), Sz("AtU8")]).
