-module(foreign_return_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, escript/0, with_src/3]).

%%% ---------------------------------------------------------------------------
%%% F40 — a foreign return may promise only what one guard decides
%%%
%%% Ticket 18 §2, decided 2026-08-13 and built here (ENG-354): a foreign
%%% function's declared RETURN type may mention only what a BEAM guard decides
%%% in O(1). Anything a walk would be needed for -- a list with an element
%%% type narrower than `term`, a map with a key or value narrower than `term`,
%%% a named record, a recursive type, a `string` -- is refused at the
%%% declaration, by name, with the route through: declare the part a guard
%%% cannot decide as `term`, then `ValidateAs<T>` where it is used.
%%%
%%% Every assertion here is at the CLI boundary: what `bsc` prints and what it
%%% exits with. Nothing pins a function in `bs_check`.
%%% ---------------------------------------------------------------------------

%% What `bsc` prints for a program, and its exit status.
refused(Mod, Src) ->
    with_src(Mod ++ ".bs", Src,
             fun(Path, Out) ->
                 bs_test_support:run_cli_result("-o " ++ Out ++ " " ++ Path)
             end).

found(Text, R) -> string:find(R, Text) =/= nomatch.

%% The term form, so the tag and its parts can be asserted as a consumer sees
%% them, and not only as prose.
diagnostic_term(Mod, Src) ->
    with_src(Mod ++ ".bs", Src,
             fun(Path, Out) ->
                 {_, StdOut, _} = bs_test_support:run_cli_split_result(
                                    "--diagnostics term -o " ++ Out ++ " " ++ Path),
                 [L | _] = [L || L <- string:split(string:trim(StdOut), "\n", all),
                                 L =/= ""],
                 {ok, Toks, _} = erl_scan:string(L ++ "."),
                 {ok, Term} = erl_parse:parse_term(Toks),
                 Term
             end).

%%% ---------------------------------------------------------------------------
%%% F40.1 – F40.3 — the containers: a list, a map, and 18 §2's own example
%%% ---------------------------------------------------------------------------

%% F40.1. The example that shipped for three weeks: `list<int>` from
%% `:lists.reverse` promises every element is an integer, and no guard reads
%% every element.
a_list_narrower_than_term_is_refused_test() ->
    {Rc, R} = refused("Rev", "module Rev\n"
                             "using :lists {\n"
                             "    list<int> reverse(list<int> xs)\n"
                             "}\n"
                             "public list<int> Backwards(list<int> xs)\n"
                             "Backwards(xs) -> :lists.reverse(xs)\n"),
    ?assertEqual(1, Rc),
    ?assert(found(":lists.reverse returns `list<int>`, which one guard cannot decide", R)),
    ?assert(found("every element of this list would need inspecting", R)),
    ?assert(found("declare it `list<term>`, then `ValidateAs<list<int>>` where it is used", R)).

%% F40.2. Ticket 18 §2's own refused example, verbatim.
a_list_of_records_is_refused_at_the_declaration_test() ->
    {Rc, R} = refused("Orders", "module Orders\n"
                                "record Order { Id: int, Total: int }\n"
                                "using :ets {\n"
                                "    list<Order> lookup(atom tab, term key)\n"
                                "}\n"
                                "public list<Order> Find(int id)\n"
                                "Find(id) -> :ets.lookup(:orders, id)\n"),
    ?assertEqual(1, Rc),
    ?assert(found(":ets.lookup returns `list<Order>`, which one guard cannot decide", R)),
    ?assert(found("declare it `list<term>`, then `ValidateAs<list<Order>>` where it is used", R)).

%% F40.3. The map that printed `{not_a_binary = :not_an_int}` from a function
%% declared `map<binary, int>` -- ticket 06's outcome 3, which 18 exists to
%% rule out. `binary` keys are as unbounded a promise as `string` ones.
a_map_narrower_than_term_is_refused_test() ->
    {Rc, R} = refused("Counts", "module Counts\n"
                                "using :maps {\n"
                                "    map<binary, int> from_list(list<term> pairs)\n"
                                "}\n"
                                "public map<binary, int> Counts()\n"
                                "Counts() -> :maps.from_list([(:not_a_binary, :not_an_int)])\n"),
    ?assertEqual(1, Rc),
    ?assert(found(":maps.from_list returns `map<binary, int>`, which one guard cannot decide", R)),
    ?assert(found("every key and value of this map would need inspecting", R)),
    ?assert(found("declare it `map<term, term>`, then `ValidateAs<map<binary, int>>` where it is used", R)).

%%% ---------------------------------------------------------------------------
%%% F40.4 – F40.5 — a record, and a recursive type
%%% ---------------------------------------------------------------------------

%% F40.4. A named record is refused with its own sentence (ENG-351 grill, Q8):
%% its `Kind` is a key this compiler mints and Erlang never writes, so no
%% guard on a foreign value can find it. The edit is the inline field form,
%% which IS decided by a fixed guard sequence -- and not `ValidateAs<Order>`,
%% whose validator demands the `Kind` too.
a_record_is_refused_with_its_own_sentence_test() ->
    {Rc, R} = refused("Users", "module Users\n"
                               "record Account { Id: int, Owner: binary }\n"
                               "using :users_db {\n"
                               "    Account fetch(int id)\n"
                               "}\n"
                               "public int N()\n"
                               "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found(":users_db.fetch returns `Account`, which one guard cannot decide", R)),
    ?assert(found("`Account` is a record, and Erlang cannot produce its `Kind`", R)),
    ?assert(found("write its fields instead, `{ Id: int, Owner: binary }`", R)),
    ?assertNot(found("ValidateAs<Account>", R)).

%% F40.5. ENG-355, absorbed here: a foreign recursive return crashed the
%% compiler in `error_members/1` with a stack trace, because the wrapper pass
%% ran before the refusal. Now it is refused by name, before anything asks
%% what the type's members are.
a_recursive_return_is_refused_and_not_a_crash_test() ->
    {Rc, R} = refused("Rec", "module Rec\n"
                             "type Tree = :leaf | (Tree, Tree)\n"
                             "using :trees {\n"
                             "    Tree grow(int n)\n"
                             "}\n"
                             "public int N()\n"
                             "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found(":trees.grow returns `Tree`, which one guard cannot decide", R)),
    ?assert(found("`Tree` is recursive", R)),
    ?assert(found("declare it `term`, then `ValidateAs<Tree>` where it is used", R)),
    ?assertNot(found("exception", R)),
    ?assertNot(found("error_members", R)).

%%% ---------------------------------------------------------------------------
%%% F40.6 – F40.7 — the offender inside a tuple or a union, and the edit
%%% ---------------------------------------------------------------------------

%% F40.6. The container is a tuple member: the edit cannot name the whole
%% return's replacement, so it names the part.
a_container_inside_a_result_is_refused_test() ->
    {Rc, R} = refused("Cart", "module Cart\n"
                              "record Order { Id: int, Total: int }\n"
                              "using :session_store {\n"
                              "    result<list<Order>, atom> cart(binary sid)\n"
                              "}\n"
                              "public int N()\n"
                              "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found(":session_store.cart returns `result<list<Order>, atom>`, which one guard cannot decide", R)),
    ?assert(found("declare the part a guard cannot decide as `term`", R)),
    ?assert(found("then `ValidateAs<result<list<Order>, atom>>` where it is used", R)).

%% F40.7. Through the prelude's alias: `option<list<int>>` is
%% `list<int> | :nothing`, and the list member is the offender.
a_container_under_an_alias_is_refused_test() ->
    {Rc, R} = refused("Opt", "module Opt\n"
                             "using :store {\n"
                             "    option<list<int>> find(atom key)\n"
                             "}\n"
                             "public int N()\n"
                             "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found(":store.find returns `option<list<int>>`, which one guard cannot decide", R)),
    ?assert(found("every element of this list would need inspecting", R)).

%%% ---------------------------------------------------------------------------
%%% F40.8 – F40.10 — the admissible set builds AND runs
%%% ---------------------------------------------------------------------------

admissible_src() ->
    "module Adm\n"
    "type Whereis = (:ok, int) | :undefined\n"
    "using :lists {\n"
    "    list<term> reverse(list<term> xs)\n"
    "    int sum(list<int> xs)\n"
    "}\n"
    "using :maps {\n"
    "    map<term, term> from_list(list<term> pairs)\n"
    "}\n"
    "using :erlang {\n"
    "    result<int, foreign_error> binary_to_integer(binary b)\n"
    "    Whereis element(int n, term t)\n"
    "}\n"
    "public list<term> Backwards(list<term> xs)\n"
    "Backwards(xs) -> :lists.reverse(xs)\n"
    "public int Total(list<int> xs)\n"
    "Total(xs) -> :lists.sum(xs)\n"
    "public map<term, term> Cart()\n"
    "Cart() -> :maps.from_list([(\"sku-7\", 2)])\n"
    "public result<int, foreign_error> Parse(binary b)\n"
    "Parse(b) -> :erlang.binary_to_integer(b)\n"
    "public Whereis Pick(term t)\n"
    "Pick(t) -> :erlang.element(1, t)\n".

%% F40.8. `list<term>`, `map<term, term>`, a tuple-and-atom union and the
%% wrapped channel all cross: each is one guard, and none needs a walk.
the_admissible_forms_build_and_run_test() ->
    M = build_and_load(admissible_src(), 'Adm'),
    ?assertEqual([3, 2, 1], M:'Backwards'([1, 2, 3])),
    ?assertEqual(#{<<"sku-7">> => 2}, M:'Cart'()),
    ?assertEqual(8080, M:'Parse'(<<"8080">>)),
    ?assertEqual({ok, 4}, M:'Pick'({{ok, 4}, x})).

%% F40.9. The wrapper still fires on a wrapped channel: the refusal runs
%% before the wrapper pass now, and must not have stopped it running.
the_wrapper_still_fires_after_the_refusal_moved_test() ->
    M = build_and_load(admissible_src(), 'Adm'),
    ?assertMatch({error, {error, badarg}}, M:'Parse'(<<"abc">>)).

%% F40.10. PARAMETER POSITION IS NOT BARRED. `int sum(list<int> xs)` hands a
%% list OUT, already established by the signature that produced it. The rule
%% is return-only, and `Total` above compiles beside the refusals.
a_parameter_narrower_than_term_is_not_checked_test() ->
    M = build_and_load(admissible_src(), 'Adm'),
    ?assertEqual(10, M:'Total'([1, 2, 3, 4])).

%% F40.11. A fixed field set is admissible (ENG-351 grill, Q8): an inline map
%% type is decided by `is_map` and one value test per declared field, the same
%% shape as `(:ok, int)`. A named record is not, because of `Kind`; this is
%% the form the record refusal recommends, so it had better compile.
an_inline_map_type_is_admissible_test() ->
    M = build_and_load("module Web\n"
                       "using :maps {\n"
                       "    { Method: binary, Path: binary } from_list(list<term> pairs)\n"
                       "}\n"
                       "public binary PathOf()\n"
                       "PathOf() -> :maps.from_list([(:'Method', \"GET\"), (:'Path', \"/x\")]) switch {\n"
                       "    { Method: \"GET\", Path: p } => p,\n"
                       "    { Method: m }              => m\n"
                       "}\n", 'Web'),
    ?assertEqual(<<"/x">>, M:'PathOf'()).

%%% ---------------------------------------------------------------------------
%%% F40.12 – F40.14 — one diagnostic, the term form, and the query mode
%%% ---------------------------------------------------------------------------

%% F40.12. The `string` slice (F9.11) retired into this rule: one tag for the
%% whole of 18 §2, with the edit line varying by what was found (Q7). A
%% `string` one guard reaches keeps its `binary` edit.
a_string_return_is_the_same_rule_with_a_binary_edit_test() ->
    {Rc, R} = refused("Fs", "module Fs\n"
                            "using :file {\n"
                            "    string read_file(term path)\n"
                            "}\n"
                            "public int N()\n"
                            "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found(":file.read_file returns `string`, which one guard cannot decide", R)),
    ?assert(found("declare it `binary`", R)),
    ?assertNot(found("ValidateAs", R)).

%% F40.13. The term a consumer dispatches on. `why` is what was found and
%% `at` whether it is the whole return, which is what chooses the edit.
the_term_form_names_what_was_found_test() ->
    T = diagnostic_term("Counts", "module Counts\n"
                                  "using :maps {\n"
                                  "    map<binary, int> from_list(list<term> pairs)\n"
                                  "}\n"
                                  "public int N()\n"
                                  "N() -> 1\n"),
    ?assertMatch(#{tag := foreign_ret_beyond_one_guard, severity := error,
                   module := ":maps", function := from_list,
                   type := "map<binary, int>", why := map, at := whole}, T).

%% F40.14. `bsc --api` runs the declaration pass on its own (F17) and must
%% surface this refusal as a compile does, or it prints an API for a module
%% that does not compile -- the hole F31 closed for a collapsed channel.
the_query_mode_refuses_the_same_declaration_test() ->
    with_src("Q.bs",
             "module Q\n"
             "using :lists {\n"
             "    list<int> reverse(list<int> xs)\n"
             "}\n"
             "public int N()\n"
             "N() -> 1\n",
             fun(Path, Root) ->
                 {Rc, R} = bs_test_support:run_cli_result(
                             "--api --src-root " ++ Root ++ " " ++ Path),
                 ?assertEqual(1, Rc),
                 ?assert(found("returns `list<int>`, which one guard cannot decide", R)),
                 ?assertNot(found("int N()", R))
             end).
