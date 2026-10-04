-module(drive).
-export([main/0]).
good() -> #{'Kind' => 'Forge.Order', 'Id' => 1, 'Total' => 7}.
bad_tag() -> #{'Kind' => 'Forge.Invoice', 'Id' => 1, 'Total' => 7}.   %% wrong tag, right shape
no_tag() -> #{'Id' => 1, 'Total' => 7}.                                 %% missing tag
cart(Item, Qty, Items) -> cart(Item, Qty, Items, 5).
cart(Item, Qty, Items, Oct) -> #{'Kind' => 'Forge.Cart', 'Item' => Item, 'Qty' => Qty, 'Items' => Items, 'Oct' => Oct}.
run(Label, F) ->
    R = try {ok, F()} catch C:E:St ->
            [{M,Fn,A,_}|_] = St,
            io_lib:format("CRASH ~w:~w  in ~w:~w/~w", [C, E, M, Fn, arity(A)]) end,
    case R of {ok, V} -> io:format("~-34s -> RETURNED ~w  (silent)~n", [Label, V]);
              _ -> io:format("~-34s -> ~s~n", [Label, R]) end.
arity(A) when is_integer(A) -> A; arity(A) -> length(A).
main() ->
    io:format("--- control: good values~n"),
    run("Direct(good)",            fun() -> 'Forge':'Direct'(good()) end),
    run("Nested(cart(good,..))",   fun() -> 'Forge':'Nested'(cart(good(), 3, [])) end),
    io:format("--- path 1: forged whole parameter (exported guard sees it)~n"),
    run("Direct(bad_tag)",         fun() -> 'Forge':'Direct'(bad_tag()) end),
    run("Direct(no_tag)",          fun() -> 'Forge':'Direct'(no_tag()) end),
    io:format("--- path 2: forged record NESTED in the parameter~n"),
    run("Nested(cart(bad_tag,..))",fun() -> 'Forge':'Nested'(cart(bad_tag(), 3, [])) end),
    run("Nested(cart(no_tag,..))", fun() -> 'Forge':'Nested'(cart(no_tag(), 3, [])) end),
    io:format("--- path 3: forged int FIELD (1.5 / atom) into private Scale~n"),
    run("Field(cart(good,1.5))",   fun() -> 'Forge':'Field'(cart(good(), 1.5, [])) end),
    run("Field(cart(good,foo))",   fun() -> 'Forge':'Field'(cart(good(), foo, [])) end),
    io:format("--- path 3d: Octet-typed field (kind AND range) into private ScaleO(Octet)~n"),
    run("Oct(cart(..,Oct=5))  control",  fun() -> 'Forge':'Oct'(cart(good(), 1, [], 5)) end),
    run("Oct(cart(..,Oct=300))",         fun() -> 'Forge':'Oct'(cart(good(), 1, [], 300)) end),
    run("Oct(cart(..,Oct=1.5))",         fun() -> 'Forge':'Oct'(cart(good(), 1, [], 1.5)) end),
    io:format("--- path 3b: forged int field into a private function that only compares~n"),
    run("FieldBig(cart(good,foo))",fun() -> 'Forge':'FieldBig'(cart(good(), foo, [])) end),
    run("FieldBig(cart(good,<<>>))",fun() -> 'Forge':'FieldBig'(cart(good(), <<>>, [])) end),
    io:format("--- path 4: forged element deep in list<Order>~n"),
    run("Sum(items=[good,bad_tag])",fun() -> 'Forge':'Sum'(cart(good(), 1, [good(), bad_tag()])) end),
    run("SumList([good,bad_tag])",  fun() -> 'Forge':'SumList'([good(), bad_tag()]) end),
    io:format("--- path 4c: private fn passed as a value~n"),
    run("Mapped([good,bad_tag])",   fun() -> 'Forge':'Mapped'([good(), bad_tag()]) end),
    io:format("--- path 3c: no private callee at all - projection hole independent of scope~n"),
    run("Compare(cart(good,foo))",  fun() -> 'Forge':'Compare'(cart(good(), foo, [])) end),
    run("Compare(cart(good,1.5))",  fun() -> 'Forge':'Compare'(cart(good(), 1.5, [])) end),
    io:format("--- path 5: plain exported int guard~n"),
    run("ViaInt(1.5)",             fun() -> 'Forge':'ViaInt'(1.5) end),
    io:format("--- private functions are not callable from outside~n"),
    run("Forge:'Inner'(bad_tag)",  fun() -> 'Forge':'Inner'(bad_tag()) end),
    io:format("--- error shape: the full stacktrace of path 2 (guard on the PRIVATE callee) vs path 1 (guard on the exported entry)~n"),
    [begin try F() catch C:E:St -> io:format("~w:~w~n  ~p~n", [C, E, [{M, Fn, A, proplists:get_value(line, L)} || {M, Fn, A, L} <- St]]) end end
     || F <- [fun() -> 'Forge':'Nested'(cart(bad_tag(), 3, [])) end, fun() -> 'Forge':'Direct'(bad_tag()) end]],
    ok.
