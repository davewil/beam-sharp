-module(forge).
-export([main/0]).
%% Probe 59b/c: a forged record reaching a PRIVATE record-taking function through an EXPORTED function.
%% The forged value wears the Invoice tag but has every Order field.
forged()  -> #{'Kind' => 'Ledger.Invoice', 'Id' => 1, 'Total' => 100}.
genuine() -> #{'Kind' => 'Ledger.Order',   'Id' => 1, 'Total' => 100}.
call(Label, F) ->
    R = try {ok, F()} catch C:E -> {C, element(1, norm(E))} end,
    io:format("  ~-44s ~p~n", [Label, R]).
norm({function_clause, _} = X) -> X;
norm(E) -> {E}.
main() ->
    [run(V) || V <- ["base", "A"]],
    halt(0).
run(V) ->
    code:purge('Ledger'), code:delete('Ledger'),
    {module, 'Ledger'} = code:load_abs("out/" ++ V ++ "/Ledger"),
    io:format("== emitter ~s ==~n", [V]),
    call("Handle(forged)  [exported rec param]",   fun() -> 'Ledger':'Handle'(forged()) end),
    call("Handle(genuine) [control]",              fun() -> 'Ledger':'Handle'(genuine()) end),
    call("Unwrap(#{Item=forged}) [nested field]",  fun() -> 'Ledger':'Unwrap'(#{'Item' => forged(), 'Note' => x}) end),
    call("Unwrap(#{Item=genuine}) [control]",      fun() -> 'Ledger':'Unwrap'(#{'Item' => genuine(), 'Note' => x}) end),
    call("Totals([forged]) [list elem]",           fun() -> 'Ledger':'Totals'([forged()]) end),
    call("Totals([genuine]) [control]",            fun() -> 'Ledger':'Totals'([genuine()]) end),
    call("Sum(#{Orders=[forged]}) [lambda->Inner]", fun() -> 'Ledger':'Sum'(#{'Orders' => [forged()], 'Note' => x}) end),
    call("Picker(x)(forged) [escaped private fun]", fun() -> (('Ledger':'Picker'(x)))(forged()) end),
    call("Picker(x)(genuine) [control]",           fun() -> (('Ledger':'Picker'(x)))(genuine()) end),
    call("Totals([#{Kind=Order,Id=1}]) [missing Total]", fun() -> 'Ledger':'Totals'([#{'Kind'=>'Ledger.Order','Id'=>1}]) end),
    call("Totals([<<bin>>]) [not a map]",          fun() -> 'Ledger':'Totals'([<<"x">>]) end).
