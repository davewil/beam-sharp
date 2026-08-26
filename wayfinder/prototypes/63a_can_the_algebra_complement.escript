#!/usr/bin/env escript
%%! -pa compiler/_build/default/lib/bsc/ebin
%%
%% 63a — Can the type algebra complement?
%%
%% Ticket 63 item 4 asserts: "`bs_types` has no negation node — measured
%% 2026-08-25, and it is why `m_minus({open, _}, {closed, _})` over-approximates
%% rather than computing the difference. A `not` over a refinement predicate may
%% be asking the algebra for exactly the thing it cannot represent. This is the
%% question that could make the answer 'no'."
%%
%% Two claims are welded together there, and they are separable:
%%
%%   (i)  bs_types has no negation node                       -- true
%%   (ii) ...which is why the open-minus-closed arm widens    -- to be measured
%%
%% Run from the REPOSITORY ROOT, never from inside compiler/: a C.beam in that
%% directory shadows stdlib's `c` on macOS and a bare escript/erl dies there.
%%
%%     escript wayfinder/prototypes/63a_can_the_algebra_complement.escript
%%
%% Every measurement below prints its own PASS/FAIL against a stated expectation,
%% and each has a CONTROL beside it, so a result cannot be produced by an
%% operation that behaves the same way on everything.

main(_) ->
    io:format("~n== 63a — can the algebra complement? ==~n~n"),
    R = [m1_atom_complement(),
         m2_refinement_complement(),
         m3_where_it_actually_widens(),
         m4_the_named_cause()],
    io:format("~n-- ~p measurements, ~p as expected --~n",
              [length(R), length([x || true <- R])]),
    case lists:all(fun(X) -> X end, R) of
        true  -> io:format("63a: all measurements as expected~n"), halt(0);
        false -> io:format("63a: A MEASUREMENT DID NOT MATCH~n"),  halt(1)
    end.

%% ---------------------------------------------------------------------------
%% M1 — complement over the atom part is EXACT and TOTAL.
%%
%% Ticket 10 made the atom universe open, so `atom \ :ok` has no finite
%% representation. bs_types holds atoms as finite OR cofinite sets, which is
%% precisely what closes the algebra under complement with no negation node
%% (the module header says so at bs_types.erl:20-23).
%% ---------------------------------------------------------------------------
m1_atom_complement() ->
    hdr("M1", "complement over atoms: exact, and closed under double negation"),

    NotOk = bs_types:subtract(bs_types:atom_top(), bs_types:atom_lit(ok)),
    io:format("    atom \\ :ok            = ~s~n", [bs_types:to_string(NotOk)]),

    %% The test that matters: complementing TWICE must return the original set,
    %% which an over-approximating operation cannot do.
    Back = bs_types:subtract(bs_types:atom_top(), NotOk),
    io:format("    atom \\ (atom \\ :ok)   = ~s~n", [bs_types:to_string(Back)]),
    Exact = bs_types:to_string(Back) =:= bs_types:to_string(bs_types:atom_lit(ok)),

    %% CONTROL — subtracting something disjoint must NOT change the minuend, so
    %% "the answer came back narrowed" is not something subtract does to
    %% everything it is handed.
    Ctl  = bs_types:subtract(bs_types:atom_lit(ok), bs_types:atom_lit(error)),
    CtlOk = bs_types:to_string(Ctl) =:= bs_types:to_string(bs_types:atom_lit(ok)),
    io:format("    CONTROL :ok \\ :error  = ~s (unchanged: ~p)~n",
              [bs_types:to_string(Ctl), CtlOk]),

    verdict(Exact andalso CtlOk,
            "double complement round-trips: the algebra complements atoms EXACTLY").

%% ---------------------------------------------------------------------------
%% M2 — the complement of a REFINEMENT inside its base is representable.
%%
%% This is the case ticket 63 item 4 fears: `not` over a refinement predicate.
%% `string` is a refinement of `binary` (the UTF-8 ones). Its complement inside
%% its base is exactly what a `not` would have to denote.
%% ---------------------------------------------------------------------------
m2_refinement_complement() ->
    hdr("M2", "complement of a refinement inside its base"),

    NotStr = bs_types:subtract(bs_types:binary_top(), bs_types:string()),
    S = bs_types:to_string(NotStr),
    io:format("    binary \\ string       = ~s~n", [S]),
    Represented = (not bs_types:is_none(NotStr)),

    %% CONTROL — the reverse direction must come back empty, because every
    %% string IS a binary. If BOTH directions produced a non-empty answer the
    %% representation would be junk rather than a complement.
    Rev = bs_types:subtract(bs_types:string(), bs_types:binary_top()),
    RevEmpty = bs_types:is_none(Rev),
    io:format("    CONTROL string \\ binary = ~s (empty: ~p)~n",
              [bs_types:to_string(Rev), RevEmpty]),

    verdict(Represented andalso RevEmpty andalso S =:= "binary \\ string",
            "the refinement complement is REPRESENTABLE and has a printed form").

%% ---------------------------------------------------------------------------
%% M3 — where the algebra DOES widen, and whether a negation node would help.
%%
%% The arm ticket 63 blames is `m_minus({open, _}, {closed, _})`. Reached with an
%% OPEN map member as minuend and a CLOSED one as subtrahend.
%% ---------------------------------------------------------------------------
m3_where_it_actually_widens() ->
    hdr("M3", "open-map minus closed-map: the arm ticket 63 names"),

    Open   = bs_types:map_open(#{'Kind' => bs_types:atom_lit(user)}),
    Closed = bs_types:map_closed(#{'Kind' => bs_types:atom_lit(user)}),

    Widened = bs_types:subtract(Open, Closed),
    io:format("    open{Kind::user} \\ closed{Kind::user} = ~s~n",
              [bs_types:to_string(Widened)]),
    KeptWhole = bs_types:to_string(Widened) =:= bs_types:to_string(Open),

    %% CONTROL — the SAME call shape with a closed minuend subtracts EXACTLY.
    %% This is the control that matters: it proves the widening belongs to the
    %% open/closed pairing, not to map subtraction in general and not to
    %% `subtract/2` being incapable of removing anything.
    Exact = bs_types:subtract(Closed, Closed),
    ExactEmpty = bs_types:is_none(Exact),
    io:format("    CONTROL closed \\ closed              = ~s (empty: ~p)~n",
              [bs_types:to_string(Exact), ExactEmpty]),

    verdict(KeptWhole andalso ExactEmpty,
            "open\\closed keeps the minuend WHOLE; closed\\closed is exact").

%% ---------------------------------------------------------------------------
%% M4 — the cause the source itself names.
%%
%% bs_types.erl:657-661 gives the reason in its own words, and it is NOT a
%% missing negation node. Assert the sentence is still there, so this probe
%% fails loudly if the attribution is ever edited.
%% ---------------------------------------------------------------------------
m4_the_named_cause() ->
    hdr("M4", "the reason the source gives for M3's widening"),
    {ok, Bin} = file:read_file("compiler/src/bs_types.erl"),
    Src = binary_to_list(Bin),

    Cause  = "plus at least one more",
    Header = "close the algebra under complement",

    HasCause  = string:find(Src, Cause)  =/= nomatch,
    HasHeader = string:find(Src, Header) =/= nomatch,

    io:format("    bs_types says the open member cannot name~n"),
    io:format("      \"these fields, ~s\"            -> present: ~p~n", [Cause, HasCause]),
    io:format("    and the module header says cofinite sets~n"),
    io:format("      \"~s without a negation node\" -> present: ~p~n", [Header, HasHeader]),

    verdict(HasCause andalso HasHeader,
            "the widening is an unnameable MAP MEMBER, not a missing negation").

%% ---------------------------------------------------------------------------

hdr(Id, What) -> io:format("~s — ~s~n", [Id, What]).

verdict(true,  Why) -> io:format("    PASS: ~s~n~n", [Why]), true;
verdict(false, Why) -> io:format("    FAIL: expected ~s~n~n", [Why]), false.
