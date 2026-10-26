#!/usr/bin/env escript
main(_) ->
    Pairs = [{"tag test (map_get('Kind') == order), 1 fn", s_tag0, s_tag1},
             {"int test (is_integer), 1 fn",               s_int0, s_int1},
             {"g_none -> g_pub  (exported-only guards, 2 fn pairs)", g_none, g_pub},
             {"g_pub  -> g_both (adds guards to the two private fns)", g_pub, g_both}],
    [begin
         {ok, {_, [{"Code", C0}]}} = beam_lib:chunks("ebin/" ++ atom_to_list(A) ++ ".beam", ["Code"]),
         {ok, {_, [{"Code", C1}]}} = beam_lib:chunks("ebin/" ++ atom_to_list(B) ++ ".beam", ["Code"]),
         S0 = filelib:file_size("ebin/" ++ atom_to_list(A) ++ ".beam"),
         S1 = filelib:file_size("ebin/" ++ atom_to_list(B) ++ ".beam"),
         io:format("~-58s code ~4B -> ~4B (~s)   beam ~4B -> ~4B (~s)~n",
                   [Name, byte_size(C0), byte_size(C1), d(byte_size(C1)-byte_size(C0)), S0, S1, d(S1-S0)])
     end || {Name, A, B} <- Pairs].
d(X) -> lists:flatten(io_lib:format("~s~B", [if X >= 0 -> "+"; true -> "" end, X])).
