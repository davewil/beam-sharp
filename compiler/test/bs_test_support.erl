%%% End-to-end tests for the walking skeleton.
%%%
%%% Tested at the boundary — source text in, a callable `.beam` out — rather than
%%% against the checker's internals, so a change to how the type algebra is
%%% represented does not break the suite. The one exception is the algebra's own
%%% laws, which have no boundary to be reached through.

-module(bs_test_support).

-include_lib("eunit/include/eunit.hrl").

-export([compile/1, build_and_load/2, check_only/1, errors/1, project_root/0,
         escript/0, run_cli/1, with_src/3,
         showcase_src/0, shop_src/0, an_order/0, count/2]).

-define(OUT, "/tmp/bsc_eunit").

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

compile(Src) ->
    ok = filelib:ensure_dir(?OUT ++ "/x"),
    Path = ?OUT ++ "/in.bs",
    ok = file:write_file(Path, Src),
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
    bs_check:check(Decls).

showcase_src() ->
    "module Readings\n"
    "type Verdict = :positive | :zero | :negative | :unknown\n"
    "type Reading = (:ok, int) | (:error, atom)\n"
    "Verdict Classify(Reading r)\n"
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
    Out = ?OUT ++ "/run",
    ok = filelib:ensure_dir(Out ++ "/x"),
    Path = Out ++ "/" ++ Name,
    ok = file:write_file(Path, Src),
    Fun(Path, Out).

shop_src() ->
    "module Shop\n"
    "record Order { Id: int, Total: int }\n"
    "record Invoice { Id: int, Total: int }\n"
    "type Doc = Order | Invoice\n"
    "Order Draft()\n"
    "Draft() -> Order { Id = 1, Total = 0 }\n"
    "Order Pay(Order o)\n"
    "Pay(o) -> o with { Total = 500 }\n"
    "int Amount(Order o)\n"
    "Amount(o) -> o.Total\n"
    "int Either(Doc d)\n"
    "Either(d) -> d.Total\n"
    "atom Which(Doc)\n"
    "Which({ Kind: :'Shop.Order' }) -> :order\n"
    "Which({ Kind: :'Shop.Invoice' }) -> :invoice\n"
    "int Total(int n)\n"
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
