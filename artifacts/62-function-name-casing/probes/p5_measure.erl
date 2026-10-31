%% Probe 5: what do snake_case alias exports cost in the .beam?
%% Build:  erlc p5_measure.erl      Run: bash p5_run.sh  (writes p5_measure.out)
%% Generates abstract forms shaped like bsc output (debug_info, -spec, PascalCase
%% exports) for N functions in four variants:
%%   plain      PascalCase only (today)
%%   tramp      + snake alias exported; body = local call to the PascalCase fn
%%   tramp_spec + same, alias carries its own -spec
%%   dup        + snake alias exported; body = full copy of the PascalCase body
-module(p5_measure).
-compile([nowarn_export_all, export_all]).
-define(A, 1).

pascal(I) -> list_to_atom("CalcTotal" ++ integer_to_list(I)).
snake(I)  -> list_to_atom("calc_total" ++ integer_to_list(I)).

order_ty() ->
    {type, ?A, map, [{type, ?A, map_field_exact, [{atom, ?A, 'Kind'}, {atom, ?A, 'Shop.Order'}]},
                     {type, ?A, map_field_exact, [{atom, ?A, 'Id'}, {type, ?A, integer, []}]},
                     {type, ?A, map_field_exact, [{atom, ?A, 'Total'}, {type, ?A, integer, []}]}]}.
spec(Name) ->
    {attribute, ?A, spec, {{Name, 1},
        [{type, ?A, 'fun', [{type, ?A, product, [order_ty()]},
                            {type, ?A, tuple, [{type, ?A, integer, []}, {type, ?A, integer, []}]}]}]}}.

%% 'CalcTotalI'(#{'Kind' := 'Shop.Order', 'Id' := Id, 'Total' := T}) when T > I -> {Id, T + I};
%% 'CalcTotalI'(#{'Kind' := 'Shop.Order', 'Id' := Id}) -> {Id, 0}.
pat(Vars) ->
    {map, ?A, [{map_field_exact, ?A, {atom, ?A, 'Kind'}, {atom, ?A, 'Shop.Order'}},
               {map_field_exact, ?A, {atom, ?A, 'Id'}, {var, ?A, 'Id'}}] ++ Vars}.
body_fun(Name, I) ->
    {function, ?A, Name, 1,
     [{clause, ?A, [pat([{map_field_exact, ?A, {atom, ?A, 'Total'}, {var, ?A, 'T'}}])],
       [[{op, ?A, '>', {var, ?A, 'T'}, {integer, ?A, I}}]],
       [{tuple, ?A, [{var, ?A, 'Id'}, {op, ?A, '+', {var, ?A, 'T'}, {integer, ?A, I}}]}]},
      {clause, ?A, [pat([])], [], [{tuple, ?A, [{var, ?A, 'Id'}, {integer, ?A, 0}]}]}]}.
tramp_fun(Alias, Target) ->
    {function, ?A, Alias, 1,
     [{clause, ?A, [{var, ?A, 'X'}], [], [{call, ?A, {atom, ?A, Target}, [{var, ?A, 'X'}]}]}]}.

forms(Variant, N) ->
    Ps = [pascal(I) || I <- lists:seq(1, N)],
    Ss = [snake(I)  || I <- lists:seq(1, N)],
    Exports = [{P, 1} || P <- Ps] ++ case Variant of plain -> []; _ -> [{S, 1} || S <- Ss] end
              ++ [{'bs@type_atoms', 0}],
    [{attribute, ?A, module, 'ShopM'}, {attribute, ?A, export, Exports}]
    ++ lists:append([[spec(pascal(I)), body_fun(pascal(I), I)] || I <- lists:seq(1, N)])
    ++ [{function, ?A, 'bs@type_atoms', 0, [{clause, ?A, [], [], [{cons, ?A, {atom, ?A, 'Shop.Order'}, {nil, ?A}}]}]}]
    ++ case Variant of
           plain -> [];
           tramp -> [tramp_fun(snake(I), pascal(I)) || I <- lists:seq(1, N)];
           tramp_spec -> lists:append([[spec(snake(I)), tramp_fun(snake(I), pascal(I))] || I <- lists:seq(1, N)]);
           dup -> [body_fun(snake(I), I) || I <- lists:seq(1, N)]
       end.

build(Variant, N, Dir) ->
    {ok, 'ShopM', Bin} = compile:forms(forms(Variant, N), [debug_info, binary, return_errors]),
    File = filename:join(Dir, atom_to_list(Variant) ++ "_" ++ integer_to_list(N) ++ ".beam"),
    ok = file:write_file(File, Bin),
    {ok, _, Chunks} = beam_lib:all_chunks(Bin),
    Sizes = [{Id, byte_size(C)} || {Id, C} <- Chunks],
    {Variant, N, byte_size(Bin), Sizes}.

asm(Variant, N, File) ->
    {ok, 'ShopM', _} = compile:forms(forms(Variant, N), ['S', binary, report_errors, {outdir, filename:dirname(File)}]),
    ok.

%% Fresh-VM measurement: load one file, report atom delta, code-memory delta, load time (us)
load(File) ->
    {ok, Bin} = file:read_file(File),
    garbage_collect(),
    A0 = erlang:system_info(atom_count), M0 = erlang:memory(code),
    T0 = erlang:monotonic_time(nanosecond),
    {module, 'ShopM'} = code:load_binary('ShopM', "x.beam", Bin),
    T1 = erlang:monotonic_time(nanosecond),
    A1 = erlang:system_info(atom_count), M1 = erlang:memory(code),
    NExp = length(proplists:get_value(exports, 'ShopM':module_info())),
    io:format("~p ~p ~p ~p~n", [A1 - A0, M1 - M0, (T1 - T0) div 1000, NExp]).
