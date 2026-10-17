#!/usr/bin/env escript
%% usage: attr_cost.escript Module.abstr
%% Re-compiles the SAME forms bsc emitted, with and without a -bs_requires attribute,
%% under the options bsc uses (from_abstr, debug_info). Prints bytes and whether the
%% attribute survives load (module_info/1) and is readable without loading (beam_lib).
main([Abstr]) ->
    {ok, Forms} = file:consult(Abstr),
    [{attribute, A, module, Mod} | Rest] = Forms,
    Opts = [binary, debug_info, return_errors],
    Size = fun(Fs) -> {ok, Mod, B} = compile:forms(Fs, Opts), {byte_size(B), B} end,
    {Base, _} = Size(Forms),
    With = fun(Name, Val) ->
        {S, B} = Size([{attribute, A, module, Mod}, {attribute, A, Name, Val} | Rest]),
        {S, B} end,
    Variants = [
      {"none",                         Forms},
      {"-bs_requires([req])",          [{attribute,A,module,Mod},{attribute,A,bs_requires,[req]}|Rest]},
      {"-bs_requires([req,jason,plug_cowboy])",
                                       [{attribute,A,module,Mod},{attribute,A,bs_requires,[req,jason,plug_cowboy]}|Rest]},
      {"-bs_requires([{req,\"~> 0.7\"}]) (version)",
                                       [{attribute,A,module,Mod},{attribute,A,bs_requires,[{req,"~> 0.7"}]}|Rest]},
      {"3 attrs, one per using block", [{attribute,A,module,Mod},{attribute,A,bs_requires,[req]},
                                        {attribute,A,bs_requires,[jason]},{attribute,A,bs_requires,[plug]}|Rest]}],
    io:format("module ~p, forms ~p~n", [Mod, length(Forms)]),
    lists:foreach(fun({N, Fs}) ->
        {S, B} = Size(Fs),
        io:format("~-46s ~6B bytes  (+~p)~n", [N, S, S - Base]),
        case N of
          "-bs_requires([req])" ->
              {ok, {_, [{attributes, At}]}} = beam_lib:chunks(B, [attributes]),
              io:format("   beam_lib:chunks(attributes) (no load) -> ~p~n", [proplists:get_value(bs_requires, At)]),
              {module, Mod} = code:load_binary(Mod, "x.beam", B),
              io:format("   module_info(attributes) after load    -> ~p~n", [proplists:get_value(bs_requires, Mod:module_info(attributes))]);
          _ -> ok
        end
      end, Variants),
    _ = With.
