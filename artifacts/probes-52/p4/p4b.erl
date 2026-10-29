-module(p4b). -export([main/0]).
main() ->
  [begin {ok,_} = compile:file(M, [report, {outdir,"."}]), {ok,B} = file:read_file(atom_to_list(M)++".beam"),
         {ok,{_,[{attributes,A}]}} = beam_lib:chunks(atom_to_list(M)++".beam",[attributes]),
         io:format("~-10s beam bytes ~p  attrs ~p~n",[M, byte_size(B), [X || {K,_}=X <- A, K==bs_requires]])
   end || M <- [base, withattr, withattr3]],
  %% negative control: does the attribute change anything at run time? (module info / code loading)
  {ok,Bin} = file:read_file("withattr.beam"), {module,withattr} = code:load_binary(withattr,"withattr.beam",Bin),
  io:format("module_info(attributes) = ~p~n",[withattr:module_info(attributes)]).
