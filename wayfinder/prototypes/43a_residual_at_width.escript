#!/usr/bin/env escript
%%! -pa compiler/_build/default/lib/bsc/ebin
%%
%% PROTOTYPE 43a — what does an inexhaustive diagnostic cost to read at width?
%%
%% Throwaway. Ticket 43, raised by F2 scenario F2.4. Run from the repo root:
%%
%%     (cd compiler && rebar3 escriptize) && ./wayfinder/prototypes/43a_residual_at_width.escript
%%
%% Two halves, because two different things are in question and only one of them
%% is answerable from the compiler as it stands today.
%%
%%   PART 1 drives the real `bsc` over generated `.bs` files and measures what it
%%   actually prints. This is the artefact ticket 43 exists about, at its real
%%   width, rather than at 25c's remembered width.
%%
%%   PART 2 works in `bs_types` directly, because the shapes the ticket proposes
%%   are functions of the residual TERM and three of the four cannot be computed
%%   from the printed line. It also reaches the case the surface cannot state
%%   yet — a CLOSED residual over a bounded domain — which is F2's whole point
%%   and the case 25c was actually about.
%%
%% Requires: OTP 28, rebar3, and `bsc` escriptized.

main(_) ->
    Root = root(),
    Bsc  = filename:join([Root, "compiler", "_build", "default", "bin", "bsc"]),
    case filelib:is_regular(Bsc) of
        false -> io:format("build bsc first: (cd compiler && rebar3 escriptize)~n"), halt(1);
        true  -> ok
    end,
    Work = mktemp(),
    part1(Bsc, Work),
    part2(),
    part3(),
    os:cmd("rm -rf " ++ Work),
    ok.

%%% ---------------------------------------------------------------------------
%%% Part 1 — what `bsc` prints today
%%% ---------------------------------------------------------------------------

part1(Bsc, Work) ->
    hdr("PART 1 — the diagnostic the compiler prints today"),
    io:format("Hole 1 asserts a 41-interval residual \"lowers to 41 heads\". Measured, it does~n"
              "not: `heads/2` in bsc.erl splits on the TUPLE part (one product per arity~n"
              "position), and a union of intervals lives inside ONE argument. So a 41-interval~n"
              "residual is one head with a union in argument position. The 41-head claim is a~n"
              "statement about ticket 23 §2's lowering, which is unbuilt.~n~n"),
    [probe(Bsc, Work, N, S, C) || {N, S, C} <- sources()],
    ok.

sources() ->
    Scattered = [integer_to_list(I * 10) || I <- lists:seq(1, 40)],
    [{"contiguous", src([integer_to_list(I) || I <- lists:seq(1, 40)], []),
      "40 singleton clauses, 1..40. The algebra COALESCES them."},
     {"scattered", src(Scattered, []),
      "40 singleton clauses, 10,20..400. Nothing coalesces. This is 25c's case."},
     {"open_tail", src(Scattered, ["Classify(n) when n >= 401 -> :known\n"]),
      "the same, plus a guarded clause covering an unbounded tail."}].

src(Pats, Extra) ->
    ["module P\n\natom Classify(int n)\n\n"
     | [["Classify(", P, ") -> :known\n"] || P <- Pats]] ++ Extra.

probe(Bsc, Work, Name, Src, Note) ->
    File = filename:join(Work, Name ++ ".bs"),
    ok = file:write_file(File, unicode:characters_to_binary(Src)),
    Out = os:cmd(Bsc ++ " -o " ++ Work ++ " " ++ File ++ " 2>&1"),
    Lines = [L || L <- string:split(Out, "\n", all), L =/= ""],
    io:format("--- ~ts ---~n~ts~n", [Name, Note]),
    [io:format("  ~4w chars | ~ts~n", [length(L), elide(L, 96)]) || L <- Lines],
    io:format("~n").

%%% ---------------------------------------------------------------------------
%%% Part 2 — the candidate shapes, computed from the residual term
%%% ---------------------------------------------------------------------------

part2() ->
    hdr("PART 2 — the four candidate shapes, against the real algebra"),
    io:format("`Covered` is `Domain \\ Residual` — `bs_types:subtract/2`, already exported and~n"
              "already used by the checker. The complement candidate therefore needs NO new~n"
              "machinery; it is one call on a term the diagnostic already holds.~n~n"),
    Int   = bs_types:int(),
    Octet = bs_types:range(0, 255),
    Cases =
        [{"open / contiguous", Int,   [{I, I} || I <- lists:seq(1, 40)]},
         {"open / scattered",  Int,   [{I * 10, I * 10} || I <- lists:seq(1, 40)]},
         {"open / unbounded covered", Int,
          [{I * 10, I * 10} || I <- lists:seq(1, 40)] ++ [{401, pos_inf}]},
         %% The case F2 creates and the surface cannot state yet: a refinement
         %% closes the domain, so ticket 12 §2 makes a catch-all an ERROR and
         %% every interval in the residual is a clause somebody must write.
         {"CLOSED / octet, 40 named", Octet, [{I, I} || I <- lists:seq(1, 40)]},
         {"CLOSED / octet, scattered", Octet,
          [{I * 5, I * 5} || I <- lists:seq(1, 40)]}],
    [shapes(N, D, Cs) || {N, D, Cs} <- Cases],
    ok.

shapes(Name, Domain, ClauseRanges) ->
    Matched  = bs_types:union([range(R) || R <- ClauseRanges]),
    Residual = bs_types:subtract(Domain, Matched),
    Covered  = bs_types:subtract(Domain, Residual),
    Ints     = maps:get(ints, Residual),
    io:format("--- ~ts ---~n", [Name]),
    io:format("  domain      ~ts~n", [bs_types:to_string(Domain)]),
    io:format("  intervals   ~p   cardinality ~ts~n", [length(Ints), card(Ints)]),
    row("exact", bs_types:to_string(Residual)),
    row("bounds+count", bounds_and_count(Ints)),
    row("head+remainder", head_and_remainder(Ints)),
    row("complement", ["every ", bs_types:to_string(Domain), " except ",
                       bs_types:to_string(Covered)]),
    row("cardinality", [card(Ints), " unnamed values"]),
    io:format("~n").

%%% ---------------------------------------------------------------------------
%%% Part 3 — does the threshold's UNIT change any verdict?
%%%
%%% Hole 3 says interval count and character length "disagree: three intervals
%%% over `int` render longer than twenty over `0..255`". That is a claim about
%%% rendered text and it is measurable. The adversarial row is built on purpose:
%%% few intervals, enormous literals, which is the shape that would make the two
%%% units disagree if anything does.
%%% ---------------------------------------------------------------------------

part3() ->
    hdr("PART 3 — interval count against character length"),
    Int   = bs_types:int(),
    Octet = bs_types:range(0, 255),
    Rows =
        [{"2 over int",              Int,   [{I, I} || I <- lists:seq(1, 40)]},
         {"3 over int",              Int,   [{1, 40}, {100, 140}]},
         {"20 over 0..255",          Octet, [{I * 2, I * 2} || I <- lists:seq(1, 19)]},
         {"41 over int",             Int,   [{I * 10, I * 10} || I <- lists:seq(1, 40)]},
         %% Hole 3's counterexample, built as large as a real program plausibly
         %% gets: three intervals whose bounds are 19-digit literals.
         {"3 over int, huge bounds", Int,
          [{-4611686018427387904, -1}, {1, 4611686018427387904}]}],
    io:format("  ~-26ts ~9ts ~ts~n", ["case", "intervals", "chars"]),
    [begin
         R = bs_types:subtract(D, bs_types:union([range(C) || C <- Cs])),
         S = lists:flatten(bs_types:to_string(R)),
         io:format("  ~-26ts ~9w ~w~n", [N, length(maps:get(ints, R)), length(S)])
     end || {N, D, Cs} <- Rows],
    io:format("~nSame ORDER under both units means no threshold in either unit sorts these~n"
              "differently, so the unit is not load-bearing and the testable one wins.~n"),
    ok.

row(Label, Text) ->
    Flat = lists:flatten(Text),
    io:format("  ~-14s ~4w chars | ~ts~n", [Label, length(Flat), elide(Flat, 76)]).

range({Lo, Hi}) -> bs_types:range(Lo, Hi).

%% `to_string/1` on a residual whose int part is a prefix of the real one — the
%% honest way to render "the first few", since it reuses the printer rather than
%% inventing a second spelling for an interval.
head_and_remainder(Ints) when length(Ints) =< 4 ->
    [bs_types:to_string(from_ints(Ints)), "   (no remainder at this width)"];
head_and_remainder(Ints) ->
    {First, Rest} = lists:split(3, Ints),
    [bs_types:to_string(from_ints(First)), " | … (",
     integer_to_list(length(Rest)), " more)"].

bounds_and_count(Ints) ->
    [integer_to_list(length(Ints)), " intervals spanning ",
     bound(element(1, hd(Ints))), "..", bound(element(2, lists:last(Ints))),
     ", ", card(Ints), " values"].

from_ints(Ints) -> maps:put(ints, Ints, bs_types:none()).

card(Ints) ->
    case lists:any(fun({Lo, Hi}) -> Lo =:= neg_inf orelse Hi =:= pos_inf end, Ints) of
        true  -> "unbounded";
        false -> integer_to_list(lists:sum([Hi - Lo + 1 || {Lo, Hi} <- Ints]))
    end.

bound(neg_inf) -> "-inf";
bound(pos_inf) -> "+inf";
bound(N)       -> integer_to_list(N).

%%% ---------------------------------------------------------------------------

hdr(S) -> io:format("~n=== ~ts ===~n~n", [S]).

elide(S, N) when length(S) =< N -> S;
elide(S, N) -> lists:sublist(S, N - 3) ++ "...".

mktemp() -> string:trim(os:cmd("mktemp -d")).

root() ->
    filename:dirname(filename:dirname(filename:dirname(escript:script_name()))).
