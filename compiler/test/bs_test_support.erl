%%% End-to-end tests for the walking skeleton.
%%%
%%% Tested at the boundary — source text in, a callable `.beam` out — rather than
%%% against the checker's internals, so a change to how the type algebra is
%%% represented does not break the suite. The one exception is the algebra's own
%%% laws, which have no boundary to be reached through.

-module(bs_test_support).

-include_lib("eunit/include/eunit.hrl").

-export([compile/1, build_and_load/2, check_only/1, errors/1, project_root/0,
         escript/0, run_cli/1, with_src/3, fixture_root/0, place/3,
         showcase_src/0, shop_src/0, an_order/0, count/2]).

-define(OUT, "/tmp/bsc_eunit").

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

%%% F15 — A FIXTURE IS A DIRECTORY NOW, AND IT IS NAMED FOR ITS MODULE.
%%%
%%% Two separate rules force this, and conflating them makes the second one look
%%% arbitrary.
%%%
%%% AGGREGATION forces "its own directory". `with_src/3` wrote every fixture into
%%% one shared `/tmp/bsc_eunit/run`, which was harmless while one file was one
%%% module and is nonsense now: twenty unrelated fixtures in one directory are one
%%% module with twenty `module` lines. `modules_tests` had already learned exactly
%%% this in F11 — "two tests sharing a directory would see each other's modules,
%%% and the failure would be order-dependent, which is the worst kind to debug" —
%%% and F15 makes it true for every fixture rather than only for the ones that
%%% happened to be about modules.
%%%
%%% TICKET 41 §5's PATH CHECK forces "named for its module". Anything driving the
%%% CLI is checked, so a fixture sitting in `run-4711/` and declaring
%%% `module Readings` would fail on its path rather than on what the test is
%%% about — a whole suite failing for a reason none of its tests mention.
%%%
%%% The name is read out of the source rather than passed in, so no call site has
%%% to repeat what its own first line already says.

%% A root nobody else is writing into — INCLUDING A PREVIOUS RUN.
%%
%% `erlang:unique_integer/1` is unique within a node and every `rebar3 eunit` is a
%% fresh one, so the counter restarts and run two writes into run one's
%% directories. That is not a stale-file annoyance now that a directory is a
%% module: a leftover `repl.bs` beside a fresh `in.bs` in the same module
%% directory is one module declaring both files' functions, and the suite fails
%% with `name_redeclared` in whichever tests happened to collide. Measured: two
%% consecutive runs of the same tree failed 2 and then 4, in different modules.
%% The OS pid is what makes the root new on every run.
fixture_root() ->
    D = ?OUT ++ "/fx-" ++ os:getpid() ++ "-" ++
        integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_dir(D ++ "/x"),
    D.

%% Write `Src` as `Name` under `Root`, in the directory its `module` line implies.
%% A dotted module becomes nested directories, which is what 41 §5 means by a
%% declaration matching its path — those callers pass `--src-root Root`.
place(Root, Name, Src) ->
    Dir = filename:join([Root | module_segments(Src)]),
    ok = filelib:ensure_dir(Dir ++ "/x"),
    Path = filename:join(Dir, Name),
    ok = file:write_file(Path, Src),
    Path.

module_segments(Src) ->
    Lines = [string:trim(L) || L <- string:lexemes(Src, "\n")],
    case [string:trim(R) || L <- Lines, (R = string:prefix(L, "module ")) =/= nomatch] of
        [M | _] -> string:lexemes(M, ".");
        []      -> ["Main"]
    end.

compile(Src) ->
    Path = place(fixture_root(), "in.bs", Src),
    %% `bsc:file_to_dir/2` rather than a hand-built `{opts, ...}` tuple: the
    %% suite should not know the shape of a private record, and did — adding a
    %% field to it broke six tests that were otherwise unaffected.
    Result = bsc:file_to_dir(Path, ?OUT),
    code:add_patha(?OUT),
    Result.

%% Compile, load, and hand back the module so a test can call into it.
build_and_load(Src, Mod) ->
    {ok, _} = compile(Src),
    code:purge(Mod),
    {module, Mod} = code:load_abs(?OUT ++ "/" ++ atom_to_list(Mod)),
    Mod.

check_only(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    %% F14. `bsc` runs this between parsing and checking, so a helper that skips
    %% it is not testing the compiler — it is testing a compiler that does not
    %% exist. The failure would be SILENT in the direction that matters: an
    %% unlowered `e_valve` falls through `type_of/3`'s catch-all to `term()` with
    %% no diagnostics, so every valve assertion about clean source would pass
    %% while nothing was checked at all.
    bs_check:check(bs_lower:valves(Decls)).

showcase_src() ->
    "module Readings\n"
    "type Verdict = :positive | :zero | :negative | :unknown\n"
    "type Reading = (:ok, int) | (:error, atom)\n"
    "public Verdict Classify(Reading r)\n"
    "Classify((:ok, n)) when n > 0 -> :positive\n"
    "Classify((:ok, 0))            -> :zero\n"
    "Classify((:ok, n))            -> :negative\n"
    "Classify((:error, e))         -> :unknown\n".

%% The escript, under whichever profile actually built it.
%%
%% This used to name `_build/default/bin/bsc` outright, which is where
%% `rebar3 escriptize` puts it — but eunit runs under the TEST profile, so
%% rebar.config's pre-eunit `escriptize` hook writes `_build/test/bin/bsc`
%% instead and the hardcoded path never saw it. Checking the test profile
%% first is what makes a plain `rebar3 eunit` green on a fresh clone;
%% measured before the fix, the suite reported `Failed: 3. Passed: 205.`
%%
%% The default path stays as the fallback AND as the not-found value, so the
%% failure message still names the artefact CI builds explicitly.
escript() ->
    Default = project_root() ++ "/_build/default/bin/bsc",
    Candidates = [project_root() ++ "/_build/test/bin/bsc", Default],
    case [P || P <- Candidates, filelib:is_regular(P)] of
        [Found | _] -> Found;
        []          -> Default
    end.

run_cli(Args) ->
    os:cmd(escript() ++ " " ++ Args ++ " 2>&1; echo rc:$?").

with_src(Name, Src, Fun) ->
    Root = fixture_root(),
    Fun(place(Root, Name, Src), Root).

shop_src() ->
    "module Shop\n"
    "record Order { Id: int, Total: int }\n"
    "record Invoice { Id: int, Total: int }\n"
    "type Doc = Order | Invoice\n"
    "public Order Draft()\n"
    "Draft() -> Order { Id = 1, Total = 0 }\n"
    "public Order Pay(Order o)\n"
    "Pay(o) -> o with { Total = 500 }\n"
    "public int Amount(Order o)\n"
    "Amount(o) -> o.Total\n"
    "public int Either(Doc d)\n"
    "Either(d) -> d.Total\n"
    "public atom Which(Doc)\n"
    "Which({ Kind: :'Shop.Order' }) -> :order\n"
    "Which({ Kind: :'Shop.Invoice' }) -> :invoice\n"
    "public int Total(int n)\n"
    "Total(n) -> n + 1\n".

an_order() -> #{'Kind' => 'Shop.Order', 'Id' => 1, 'Total' => 0}.

%% How many times does an atom appear anywhere in a nested term?
count(Atom, Atom) -> 1;
count(T, Atom) when is_tuple(T) -> count(tuple_to_list(T), Atom);
count(L, Atom) when is_list(L) -> lists:sum([count(E, Atom) || E <- L]);
count(_, _) -> 0.

errors(Src) ->
    {error, Diags} = check_only(Src),
    [D || D <- Diags, element(1, D) =:= error].

%% eunit runs from _build/test/lib/bsc, so walk back to the project.
project_root() ->
    filename:join(lists:takewhile(fun(C) -> C =/= "_build" end,
                                  filename:split(element(2, file:get_cwd())))).
