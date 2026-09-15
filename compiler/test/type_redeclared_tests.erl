%%% A type name is declared once per module (ENG-352; features README, F3's
%%% third finding). `record`, `type` and a refinement all declare a type
%%% name, and ticket 26 §1 makes a record an alias for a tagged map, so the
%%% three spellings share ONE namespace. Before this check `type_env/3` built
%%% the environment with `maps:from_list/1`, which keeps the rightmost
%%% duplicate: a record beat an alias of the same name whichever was written
%%% first, and between two of a kind the later one won. The losing
%%% declaration's fields vanished, and the function declared over the name
%%% was then checked against a type its author never wrote.
%%%
%%% Tested at the CLI boundary, like F11.11's `name_redeclared`: source in, a
%%% status and a message out. `bsc --api` is a second declaration pass through
%%% `exports_of/2` and must refuse what a compile refuses, or it prints an API
%%% for a module that cannot be built (F31, F40).
-module(type_redeclared_tests).
-include_lib("eunit/include/eunit.hrl").
-import(bs_test_support, [fixture_root/0, place/3, run_cli/1,
                          run_cli_split_result/1]).

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

compile_set(Files) ->
    {Root, Main} = in_dir(Files),
    run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Main).

in_dir(Files) ->
    Root = fixture_root(),
    Paths = [place(Root, N, S) || {N, S} <- Files],
    {Root, hd(Paths)}.

ok_rc(Out)  -> ?assert(string:find(Out, "rc:0") =/= nomatch).
bad_rc(Out) -> ?assert(string:find(Out, "rc:1") =/= nomatch).
has(Out, S) -> ?assert(string:find(Out, S) =/= nomatch).
lacks(Out, S) -> ?assertEqual(nomatch, string:find(Out, S)).

%% One term per line on stdout (F16.1): parse each as a consumer would.
terms(S) ->
    [begin
         {ok, Toks, _} = erl_scan:string(L ++ "."),
         {ok, Term} = erl_parse:parse_term(Toks),
         Term
     end || L <- string:split(string:trim(S), "\n", all), L =/= ""].

%% The ENG-352 program as filed, line for line: `record Name` at line 4 and
%% `type Name` at line 8, with a function declared over the name so the OLD
%% behaviour has something to say — two `return_not_declared` errors against
%% the surviving `Name`, which is the misleading remark this check replaces.
accounts_src() ->
    "module AccountsDup\n"
    "\n"
    "// A person's name, as the accounts module stores it.\n"
    "record Name { First: binary, Last: binary }\n"
    "\n"
    "record Name1 { Value: map<string, int> }\n"
    "record Name2 { Value: map<string, binary> }\n"
    "type Name = Name1 | Name2\n"
    "\n"
    "public Name Balances(int account_id, bool adjusting, map<string, binary> form)\n"
    "\n"
    "Balances(id, false, form) -> Name1{ Value = Ledger(id) }\n"
    "Balances(id, true, form)  -> Name2{ Value = form }\n"
    "\n"
    "private map<string, int> Ledger(int id)\n"
    "Ledger(id) -> Ledger(id)\n".

%%% ---------------------------------------------------------------------------
%%% F3.13 — a type name is declared once, whatever spells it
%%% ---------------------------------------------------------------------------

%% The error lands at the SECOND declaration and names the first, so the
%% author is sent to both lines and neither is reported as the other's
%% consequence.
a_record_and_an_alias_of_one_name_are_refused_test() ->
    Out = compile_set([{"AccountsDup.bs", accounts_src()}]),
    bad_rc(Out),
    has(Out, "AccountsDup.bs:8:1: error: Name is declared twice"),
    has(Out, "line 4"),
    %% The point of the check is the DIAGNOSIS: before it the program was
    %% also refused, twice, for a return type its author never wrote.
    lacks(Out, "returns a value its signature does not declare").

two_aliases_of_one_name_are_refused_test() ->
    Out = compile_set([{"Twice.bs",
                        "module Twice\n"
                        "type Doc = int\n"
                        "type Doc = binary\n"
                        "public Doc Pick(int n)\n"
                        "Pick(n) -> n\n"}]),
    bad_rc(Out),
    has(Out, "Twice.bs:3:1: error: Doc is declared twice"),
    has(Out, "line 2").

two_records_of_one_name_are_refused_test() ->
    Out = compile_set([{"Ledger.bs",
                        "module Ledger\n"
                        "record Order { Id: int }\n"
                        "record Order { Id: int, Total: int }\n"
                        "public Order Draft()\n"
                        "Draft() -> Order { Id = 1 }\n"}]),
    bad_rc(Out),
    has(Out, "Ledger.bs:3:1: error: Order is declared twice"),
    has(Out, "line 2").

%% A refinement is the third spelling, and the order of the two does not
%% matter: the later line is the second declaration whichever kind it is.
a_refinement_after_a_record_of_one_name_is_refused_test() ->
    Out = compile_set([{"Ports.bs",
                        "module Ports\n"
                        "record Port { Number: int }\n"
                        "type Port = int where value > 0 and value < 65536\n"
                        "public Port Open(int n)\n"
                        "Open(n) -> Port { Number = n }\n"}]),
    bad_rc(Out),
    has(Out, "Ports.bs:3:1: error: Port is declared twice"),
    has(Out, "line 2").

%% The reverse order of the first test. Before the check a RECORD won
%% whichever was written first (records are the right operand of the `++`
%% the environment was built from), so source order was not even the rule
%% being silently applied; now the later line is the second declaration.
a_record_after_an_alias_of_one_name_is_refused_test() ->
    Out = compile_set([{"Names.bs",
                        "module Names\n"
                        "type Name = int\n"
                        "record Name { First: int, Last: int }\n"
                        "public Name Make()\n"
                        "Make() -> Name { First = 1, Last = 2 }\n"}]),
    bad_rc(Out),
    has(Out, "Names.bs:3:1: error: Name is declared twice"),
    has(Out, "line 2").

%% Three declarations report ONE error, at the second: the third is the same
%% defect again, and a second message would send the author to fix the same
%% name twice.
three_declarations_report_the_second_test() ->
    Out = compile_set([{"Thrice.bs",
                        "module Thrice\n"
                        "type Id = int\n"
                        "record Id { Value: int }\n"
                        "type Id = binary\n"
                        "public Id Make()\n"
                        "Make() -> 1\n"}]),
    bad_rc(Out),
    has(Out, "Thrice.bs:3:1: error: Id is declared twice"),
    ?assertEqual(1, length(string:split(Out, "declared twice", all)) - 1).

%% `bsc --api` runs the declaration pass on its own (F17) and must surface
%% the refusal a compile does, or it answers about a module that cannot be
%% built: stdout empty, the refusal on stderr, status 1.
the_api_query_refuses_it_too_test() ->
    {Root, Main} = in_dir([{"AccountsDup.bs", accounts_src()}]),
    {Rc, Out, Err} = run_cli_split_result("--src-root " ++ Root ++ " --api " ++ Main),
    ?assertEqual(1, Rc),
    ?assertEqual("", Out),
    ?assertNotEqual(nomatch, string:find(Err, "Name is declared twice")).

%% The term carries both positions as data (F16), each with both halves
%% (F35), so an editor can mark the first declaration as well as the one the
%% error sits on.
the_term_carries_both_lines_test() ->
    {Root, Main} = in_dir([{"AccountsDup.bs", accounts_src()}]),
    {Rc, Out, _Err} = run_cli_split_result("--diagnostics term --src-root " ++
                                           Root ++ " " ++ Main),
    ?assertEqual(1, Rc),
    [Desc] = [D || D = #{tag := type_redeclared} <- terms(Out)],
    ?assertMatch(#{severity := error, line := 8, column := 1,
                   type := 'Name', first_line := 4, first_column := 1}, Desc).

%% The namespace is TYPE names. A function may share a name with a type
%% (ticket 40 keeps functions in their own namespace), and the same type name
%% in two modules is two qualified names (ticket 26 §1) — neither is a
%% redeclaration, and a check that grouped by the bare name across the world
%% would refuse both.
a_function_named_like_a_type_is_accepted_test() ->
    Out = compile_set([{"Drafts.bs",
                        "module Drafts\n"
                        "record Draft { Id: int }\n"
                        "public Draft Draft()\n"
                        "Draft() -> Draft { Id = 1 }\n"}]),
    ok_rc(Out).

one_name_in_two_modules_is_accepted_test() ->
    Out = compile_set([{"Sales.bs",
                        "module Sales\n"
                        "using Billing\n"
                        "record Order { Id: int }\n"
                        "public Order Draft()\n"
                        "Draft() -> Order { Id = Billing.Next() }\n"},
                       {"Billing.bs",
                        "module Billing\n"
                        "record Order { Ref: int }\n"
                        "public int Next()\n"
                        "Next() -> 7\n"}]),
    ok_rc(Out).
