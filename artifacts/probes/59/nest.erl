-module(nest).
-export([main/0]).
c(L, F) -> R = try {ok, F()} catch C:E -> {C, case E of {function_clause,_}->function_clause; _->E end} end, io:format("  ~-62s ~p~n", [L, R]).
main() ->
    [begin
       code:purge('Nest'), code:delete('Nest'), {module,'Nest'} = code:load_abs("out/Nest/" ++ V ++ "/Nest"),
       io:format("== emitter ~s ==~n", [V]),
       Forged  = #{'Kind' => 'Nest.Invoice', 'Id' => 1, 'Total' => 100},
       Genuine = #{'Kind' => 'Nest.Order', 'Id' => 1, 'Total' => 100},
       c("Unwrap(Wrapper{Item=forged Invoice})  [record in record]", fun() -> 'Nest':'Unwrap'(#{'Kind'=>'Nest.Wrapper','Item'=>Forged,'Count'=>1}) end),
       c("Unwrap(Wrapper{Item=genuine}) [control]",                  fun() -> 'Nest':'Unwrap'(#{'Kind'=>'Nest.Wrapper','Item'=>Genuine,'Count'=>1}) end),
       c("FromList([forged Invoice])  [lambda -> direct call to Inner]", fun() -> 'Nest':'FromList'([Forged]) end),
       c("FromField(Cfg{Level=1.5})  [float in record field -> Twice]", fun() -> 'Nest':'FromField'(#{'Kind'=>'Nest.Cfg','Level'=>1.5}) end),
       c("FromField(Cfg{Level=2})    [control]", fun() -> 'Nest':'FromField'(#{'Kind'=>'Nest.Cfg','Level'=>2}) end),
       c("Unwrap(forged Wrapper tag) [control: outer tag test]",     fun() -> 'Nest':'Unwrap'(#{'Kind'=>'Nest.Nope','Item'=>Genuine,'Count'=>1}) end)
     end || V <- ["base", "A", "B", "E"]], halt().
