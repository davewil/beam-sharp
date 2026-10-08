-module(kinds).
-export([main/0]).
%% Probe 59c': the int KIND/RANGE test has the same private-function hole as the tag test:
%% a float or out-of-range int that sits inside an aggregate the exported boundary does not walk.
call(Label, F) ->
    R = try {ok, F()} catch C:E -> {C, case E of {function_clause,_}->function_clause; _->E end} end,
    io:format("  ~-46s ~p~n", [Label, R]).
main() -> [run(V) || V <- ["base", "B", "E"]], halt(0).
run(V) ->
    code:purge('Kinds'), code:delete('Kinds'),
    {module, 'Kinds'} = code:load_abs("out/Kinds/" ++ V ++ "/Kinds"),
    io:format("== emitter ~s ==~n", [V]),
    call("DoubleP(1.5)   [exported int, control]",   fun() -> 'Kinds':'DoubleP'(1.5) end),
    call("DoubleP(2)     [control]",                 fun() -> 'Kinds':'DoubleP'(2) end),
    call("Doubled([1.5]) [list elem -> private fun]", fun() -> 'Kinds':'Doubled'([1.5]) end),
    call("Doubled([2])   [control]",                 fun() -> 'Kinds':'Doubled'([2]) end),
    call("FromField(#{Level=1.5}) [map field]",      fun() -> 'Kinds':'FromField'(#{'Level'=>1.5,'Note'=>x}) end),
    call("Picker(x)(1.5) [escaped private fun]",     fun() -> ('Kinds':'Picker'(x))(1.5) end),
    call("Bands([300]) [out-of-range elem, Octet]",  fun() -> 'Kinds':'Bands'([300]) end),
    call("Bands([-5])  [out-of-range elem, Octet]",  fun() -> 'Kinds':'Bands'([-5]) end),
    call("Bands([100]) [control]",                    fun() -> 'Kinds':'Bands'([100]) end),
    call("Bands([foo]) [atom elem]",                 fun() -> 'Kinds':'Bands'([foo]) end).
