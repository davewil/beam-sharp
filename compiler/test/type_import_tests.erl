%%% F44 — a record or type name crosses `using` (ticket 73, ENG-361).
%%%
%%% Driven through the CLI for F11's reason: the subject is what happens across
%%% two modules, and a checker handed one parsed file cannot ask the question.
%%% Every test places each module in the directory its `module` line implies
%%% under a root nobody else writes into, and compiles through `--src-root`.
%%%
%%% The rule under test is ticket 41's, applied to names in type position: a
%%% module-tier import brings a producer's `record` and `type` names in
%%% unqualified, the qualified spelling is legal wherever the module is
%%% reachable, a collision is refused at the use and disambiguated by the
%%% qualified spelling, and a local declaration wins over an import.

-module(type_import_tests).

-include_lib("eunit/include/eunit.hrl").

%%% ---------------------------------------------------------------------------
%%% Helpers, as `modules_tests` has them
%%% ---------------------------------------------------------------------------

in_dir(Files) ->
    Root = bs_test_support:fixture_root(),
    Paths = [bs_test_support:place(Root, N, S) || {N, S} <- Files],
    {Root, hd(Paths)}.

compile_set(Files) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Main).

run(Files, Call) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " " ++ Main ++ " " ++ Call).

api(Files) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " --api " ++ Main).

ok_rc(Out)  -> ?assert(string:find(Out, "rc:0") =/= nomatch).
bad_rc(Out) -> ?assert(string:find(Out, "rc:1") =/= nomatch).
has(Out, S) -> ?assert(string:find(Out, S) =/= nomatch).
lacks(Out, S) -> ?assertEqual(nomatch, string:find(Out, S)).

%% The value the program printed, without the `rc:` line `run_cli/1` appends.
value(Out) -> string:trim(hd(string:split(Out, "\n"))).

%% A producer with one record, one union of records, and a parametric alias
%% whose body names one of its own records — the shape a consumer must see
%% resolved rather than by the producer's private names.
orders_mod() ->
    {"Orders.bs",
     "module Orders\n"
     "record Order   { Id: int, Total: int }\n"
     "record Invoice { Id: int, Total: int }\n"
     "record Meta    { Note: int }\n"
     "type Doc = Order | Invoice\n"
     "type Box<T> = (T, Meta)\n"
     "public Order New(int id)\n"
     "New(id) -> Order{ Id = id, Total = 0 }\n"}.

an_order() -> "\"{ Kind = :'Orders.Order', Id = 1, Total = 7 }\"".

%%% ---------------------------------------------------------------------------
%%% F44.1 — the ticket's program: both of 41's spellings, in type position
%%% ---------------------------------------------------------------------------

billing_src() ->
    "module Billing\n"
    "using Orders\n"
    "public int Due(Order o)\n"
    "Due(o) -> o.Total\n"
    "public int Owed(Orders.Order o)\n"
    "Owed(o) -> o.Total\n".

an_imported_record_name_is_a_type_in_a_signature_test() ->
    Out = run([{"Billing.bs", billing_src()}, orders_mod()], "Due " ++ an_order()),
    ok_rc(Out),
    ?assertEqual("7", value(Out)).

the_qualified_spelling_is_the_same_type_test() ->
    Out = run([{"Billing.bs", billing_src()}, orders_mod()], "Owed " ++ an_order()),
    ok_rc(Out),
    ?assertEqual("7", value(Out)).

%% The producer's own boundary guard still stands on the consumer's function:
%% an `Invoice` wears a different tag, so `Due` refuses it at the door.
the_imported_type_is_the_producers_type_not_its_field_set_test() ->
    Out = run([{"Billing.bs", billing_src()}, orders_mod()],
              "Due \"{ Kind = :'Orders.Invoice', Id = 1, Total = 7 }\""),
    bad_rc(Out),
    %% The guard is F42's: the wrong tag fails the head, not a body.
    has(Out, "function_clause").

%%% ---------------------------------------------------------------------------
%%% F44.2 — a `type` alias crosses by the same mechanism, and its members
%%% dispatch by name in the consumer's clause heads
%%% ---------------------------------------------------------------------------

which_src() ->
    "module Billing\n"
    "using Orders\n"
    "public atom Which(Doc d)\n"
    "Which(Order o)   -> :order\n"
    "Which(Invoice i) -> :invoice\n".

a_union_alias_crosses_and_its_records_name_clause_heads_test() ->
    Out = run([{"Billing.bs", which_src()}, orders_mod()], "Which " ++ an_order()),
    ok_rc(Out),
    ?assertEqual(":order", value(Out)).

%% Exhaustiveness is checked against the imported union exactly as against a
%% local one, and the missing head is named in the consumer's scope.
an_imported_union_is_checked_exhaustive_test() ->
    Out = compile_set([{"Billing.bs",
                        "module Billing\n"
                        "using Orders\n"
                        "public atom Which(Doc d)\n"
                        "Which(Order o) -> :order\n"},
                       orders_mod()]),
    bad_rc(Out),
    has(Out, "Which(Invoice i)").

%%% ---------------------------------------------------------------------------
%%% F44.3 — a parametric alias crosses with its own names resolved
%%% ---------------------------------------------------------------------------

%% `Box<T>` names `Meta`, which is the producer's and not in the consumer's
%% scope by that name unless imported. Both spellings must expand it.
a_parametric_alias_crosses_with_its_body_resolved_test() ->
    Out = run([{"Billing.bs",
                "module Billing\n"
                "using Orders\n"
                "public int Peek(Orders.Box<int> b)\n"
                "Peek((n, m)) -> n + m.Note\n"},
               orders_mod()],
              "Peek \"(3, { Kind = :'Orders.Meta', Note = 4 })\""),
    ok_rc(Out),
    ?assertEqual("7", value(Out)).

a_parametric_alias_crosses_unqualified_too_test() ->
    Out = run([{"Billing.bs",
                "module Billing\n"
                "using Orders\n"
                "public int Peek(Box<int> b)\n"
                "Peek((n, m)) -> n + m.Note\n"},
               orders_mod()],
              "Peek \"(3, { Kind = :'Orders.Meta', Note = 4 })\""),
    ok_rc(Out),
    ?assertEqual("7", value(Out)).

%%% ---------------------------------------------------------------------------
%%% F44.4 — collisions inherit 41 §2: refused at the use, qualified to resolve
%%% ---------------------------------------------------------------------------

archive_mod() ->
    {"Archive.bs",
     "module Archive\n"
     "record Order { Id: int, Year: int }\n"}.

an_unqualified_name_two_imports_supply_is_refused_at_the_use_test() ->
    Out = compile_set([{"Billing.bs",
                        "module Billing\n"
                        "using Orders\n"
                        "using Archive\n"
                        "public int Due(Order o)\n"
                        "Due(o) -> o.Total\n"},
                       orders_mod(), archive_mod()]),
    bad_rc(Out),
    has(Out, "Order is ambiguous"),
    has(Out, "Orders.Order"),
    has(Out, "Archive.Order").

%% ...and an unused collision is no error at all, as for functions.
two_imports_supplying_a_name_nobody_uses_is_not_an_error_test() ->
    Out = compile_set([{"Billing.bs",
                        "module Billing\n"
                        "using Orders\n"
                        "using Archive\n"
                        "public int Year(Archive.Order o)\n"
                        "Year(o) -> o.Year\n"},
                       orders_mod(), archive_mod()]),
    ok_rc(Out).

the_qualified_spelling_disambiguates_test() ->
    Out = run([{"Billing.bs",
                "module Billing\n"
                "using Orders\n"
                "using Archive\n"
                "public int Due(Orders.Order o)\n"
                "Due(o) -> o.Total\n"},
               orders_mod(), archive_mod()],
              "Due " ++ an_order()),
    ok_rc(Out),
    ?assertEqual("7", value(Out)).

%%% ---------------------------------------------------------------------------
%%% F44.5 — a local declaration wins over an import (41 §2's resolution order)
%%% ---------------------------------------------------------------------------

a_local_type_wins_over_an_imported_one_test() ->
    Out = run([{"Billing.bs",
                "module Billing\n"
                "using Orders\n"
                "record Order { Id: int }\n"
                "public int Id(Order o)\n"
                "Id(o) -> o.Id\n"},
               orders_mod()],
              "Id \"{ Kind = :'Billing.Order', Id = 9 }\""),
    ok_rc(Out),
    ?assertEqual("9", value(Out)).

%%% ---------------------------------------------------------------------------
%%% F44.6 — the refusal names the `using` that would supply the name
%%% ---------------------------------------------------------------------------

%% The namespace tier reaches `Shop.Orders` without bringing `Order` in
%% unqualified, which is exactly the situation where the hint is worth having.
shop_orders_mod() ->
    {"Orders.bs",
     "module Shop.Orders\n"
     "record Order { Id: int, Total: int }\n"}.

an_unknown_type_names_the_import_that_would_supply_it_test() ->
    Out = compile_set([{"Billing.bs",
                        "module Shop.Billing\n"
                        "using Shop\n"
                        "public int Due(Order o)\n"
                        "Due(o) -> o.Total\n"},
                       shop_orders_mod()]),
    bad_rc(Out),
    has(Out, "no type named Order"),
    has(Out, "using Shop.Orders"),
    has(Out, "Orders.Order").

%% A qualified name whose module was never imported is refused in the words
%% the qualified CALL uses (41 §2): the `using` lines are the dependency list.
a_qualified_type_from_a_module_never_imported_is_refused_test() ->
    Out = compile_set([{"Billing.bs",
                        "module Billing\n"
                        "public int Due(Orders.Order o)\n"
                        "Due(o) -> o.Total\n"},
                       orders_mod()]),
    bad_rc(Out),
    has(Out, "Orders"),
    has(Out, "never imported").

a_qualified_name_the_module_does_not_declare_says_so_test() ->
    Out = compile_set([{"Billing.bs",
                        "module Billing\n"
                        "using Orders\n"
                        "public int Due(Orders.Receipt o)\n"
                        "Due(o) -> o.Total\n"},
                       orders_mod()]),
    bad_rc(Out),
    has(Out, "Orders declares no type named Receipt").

%%% ---------------------------------------------------------------------------
%%% F44.7 — the namespace tier and the full dotted path
%%% ---------------------------------------------------------------------------

a_dotted_producer_is_named_by_its_full_path_test() ->
    Out = run([{"Billing.bs",
                "module Shop.Billing\n"
                "using Shop.Orders\n"
                "public int Due(Shop.Orders.Order o)\n"
                "Due(o) -> o.Total\n"},
               shop_orders_mod()],
              "Due \"{ Kind = :'Shop.Orders.Order', Id = 1, Total = 7 }\""),
    ok_rc(Out),
    ?assertEqual("7", value(Out)).

a_namespace_import_short_qualifies_its_types_test() ->
    Out = run([{"Billing.bs",
                "module Shop.Billing\n"
                "using Shop\n"
                "public int Due(Orders.Order o)\n"
                "Due(o) -> o.Total\n"},
               shop_orders_mod()],
              "Due \"{ Kind = :'Shop.Orders.Order', Id = 1, Total = 7 }\""),
    ok_rc(Out),
    ?assertEqual("7", value(Out)).

%%% ---------------------------------------------------------------------------
%%% F44.8 — ticket 16's refusal does not move: naming the union is legal,
%%% widening it and handing it back is refused at the call (ENG-261)
%%% ---------------------------------------------------------------------------

shapes_mod() ->
    {"Shapes.bs",
     "module Shapes\n"
     "record Circle { Radius: int }\n"
     "record Square { Side: int }\n"
     "type Shape = Circle | Square\n"
     "public atom Name(Shape s)\n"
     "Name(Circle c) -> :circle\n"
     "Name(Square s) -> :square\n"}.

a_consumer_may_name_the_union_and_hand_it_back_test() ->
    Out = run([{"Draw.bs",
                "module Draw\n"
                "using Shapes\n"
                "public atom Go(Shape s)\n"
                "Go(s) -> Shapes.Name(s)\n"},
               shapes_mod()],
              "Go \"{ Kind = :'Shapes.Square', Side = 2 }\""),
    ok_rc(Out),
    ?assertEqual(":square", value(Out)).

a_widened_union_is_refused_where_it_meets_the_closed_clause_set_test() ->
    Out = compile_set([{"Draw.bs",
                        "module Draw\n"
                        "using Shapes\n"
                        "record Triangle { Base: int }\n"
                        "type Wide = Shapes.Shape | Triangle\n"
                        "public atom Go(Wide w)\n"
                        "Go(w) -> Shapes.Name(w)\n"},
                       shapes_mod()]),
    bad_rc(Out),
    has(Out, "does not accept"),
    has(Out, "Draw.Triangle").

%%% ---------------------------------------------------------------------------
%%% F44.9 — `--api` is a second declaration pass (ENG-320), and it prints
%%% the resolved type, never the producer's name, as F17 always has
%%% ---------------------------------------------------------------------------

the_api_prints_the_resolved_type_for_an_imported_name_test() ->
    Out = api([{"Billing.bs", billing_src()}, orders_mod()]),
    ok_rc(Out),
    has(Out, "int Due({ Kind: :'Orders.Order', Id: int, Total: int })"),
    has(Out, "int Owed({ Kind: :'Orders.Order', Id: int, Total: int })"),
    lacks(Out, "Due(Order)").

the_api_refuses_the_ambiguous_name_too_test() ->
    Out = api([{"Billing.bs",
                "module Billing\n"
                "using Orders\n"
                "using Archive\n"
                "public int Due(Order o)\n"
                "Due(o) -> o.Total\n"},
               orders_mod(), archive_mod()]),
    bad_rc(Out),
    has(Out, "Order is ambiguous").

%% F17.12 still holds: a `using` naming a module that exists nowhere is not
%% read, so the query answers about what it can see.
the_api_still_answers_when_a_dependency_is_absent_test() ->
    Out = api([{"Dependent.bs",
                "module Dependent\n"
                "using Absent.Somewhere\n"
                "public int Local(int n)\n"
                "Local(n) -> n + 1\n"}]),
    ok_rc(Out),
    has(Out, "int Local(int)").
