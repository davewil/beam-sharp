%%% Imported types
%%% The CLI resolves dependencies across modules. Fixtures follow module paths
%%% under an isolated source root.

%%% Scenarios: compiler/features/F44-type-names-cross-using.md
%%% Scenarios: compiler/features/F49-validation-error-record.md
%%% Scenarios: compiler/features/F17-compiler-query-mode.md
-module(type_import_tests).

-include_lib("eunit/include/eunit.hrl").

%%% Helpers

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

value(Out) -> string:trim(hd(string:split(Out, "\n"))).

%% The alias body must resolve Meta in the producer's scope.
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

%%% F44.1 — imported record names work unqualified and qualified.

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

%% Equal field sets do not make Invoice acceptable as Order.
the_imported_type_is_the_producers_type_not_its_field_set_test() ->
    Out = run([{"Billing.bs", billing_src()}, orders_mod()],
              "Due \"{ Kind = :'Orders.Invoice', Id = 1, Total = 7 }\""),
    bad_rc(Out),
    %% A wrong tag fails the boundary head, not the body.
    has(Out, "function_clause").

%% F49.8 — construction in the consumer carries the producer's record tag.
built_src() ->
    "module Billing\n"
    "using Orders\n"
    "public int Due(Order o)\n"
    "Due(o) -> o.Total\n"
    "public Order Make(int id)\n"
    "Make(id) -> Order { Id = id, Total = 5 }\n"
    "public int Built(int id)\n"
    "Built(id) -> Due(Make(id))\n".

a_constructed_imported_record_carries_the_producers_tag_test() ->
    Out = run([{"Billing.bs", built_src()}, orders_mod()], "Make 1"),
    ok_rc(Out),
    ?assertEqual("{Kind = :'Orders.Order', Id = 1, Total = 5}", value(Out)).

a_constructed_imported_record_passes_the_producers_guard_test() ->
    Out = run([{"Billing.bs", built_src()}, orders_mod()], "Built 1"),
    ok_rc(Out),
    ?assertEqual("5", value(Out)).

%%% F44.2 — imported union members name the consumer's clause heads.

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

an_imported_union_is_checked_exhaustive_test() ->
    Out = compile_set([{"Billing.bs",
                        "module Billing\n"
                        "using Orders\n"
                        "public atom Which(Doc d)\n"
                        "Which(Order o) -> :order\n"},
                       orders_mod()]),
    bad_rc(Out),
    has(Out, "Which(Invoice i)").

%%% F44.3 — imported parametric aliases resolve their own names.

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

%%% F44.4 — collisions fail at use; qualified names disambiguate.

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

%%% F44.5 — a local declaration wins over an import.

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

%%% F44.6 — an unknown type names the import that supplies it.

%% A namespace import reaches Shop.Orders without importing Order unqualified.
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

%%% F44.7 — namespace imports permit short and full qualification.

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

%%% F44.8 — an imported union is accepted; widening it fails at the call.

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

%%% F44.9 — the API prints resolved imported types and rejects ambiguity.

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

%% F17.12 — the API answers without loading an unused dependency.
the_api_still_answers_when_a_dependency_is_absent_test() ->
    Out = api([{"Dependent.bs",
                "module Dependent\n"
                "using Absent.Somewhere\n"
                "public int Local(int n)\n"
                "Local(n) -> n + 1\n"}]),
    ok_rc(Out),
    has(Out, "int Local(int)").
