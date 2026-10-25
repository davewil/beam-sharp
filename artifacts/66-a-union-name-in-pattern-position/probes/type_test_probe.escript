#!/usr/bin/env escript
%% Does bs_emit:type_test/3 (F42's foreign-return guard) already decide "membership in a named type" as ONE guard?
%% Types are built directly with bs_types so no source is involved. Run with the stock ebin + a copy of bs_emit
%% compiled with export_all (scratch/66/te).
main([Ebin, Te]) ->
    code:add_patha(Ebin), code:add_patha(Te),
    A = bs_types:map_closed(#{'Kind' => bs_types:atom_lit('M.A'), 'Id' => bs_types:int()}),
    B = bs_types:map_closed(#{'Kind' => bs_types:atom_lit('M.B'), 'Id' => bs_types:int()}),
    Cases = [{"C = A | B", bs_types:union(A, B)},
             {"D = A | B | :none", bs_types:union([A, B, bs_types:atom_lit(none)])},
             {"Amount = int | float", bs_types:union(bs_types:int(), bs_types:float_top())},
             {"Meters = int where >=0 (range)", bs_types:range(0, pos_inf)},
             {"int | :none", bs_types:union(bs_types:int(), bs_types:atom_lit(none))},
             {"list<int>", bs_types:list(bs_types:int())},
             {"string", bs_types:string()}],
    V = {var, 1, 'V'},
    [begin
        R = try erl_pp:expr(bs_emit_x:type_test(V, Ty, 1)) of G -> lists:flatten(G)
            catch C:E -> io_lib:format("REFUSED ~p:~p", [C, E]) end,
        io:format("~-34s ~s~n", [N, R])
     end || {N, Ty} <- Cases].
