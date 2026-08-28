%%% 49a — what arm would the valve have to emit, under each candidate shape?
%%%
%%% Run from the REPO ROOT (a bare `erl` inside `compiler/` picks up `C.beam`
%%% and dies):
%%%
%%%   erlc -o /tmp -pa compiler/_build/default/lib/bsc/ebin \
%%%        wayfinder/prototypes/49a-what-the-arm-must-be/algebra.erl
%%%   erl -noshell -pa compiler/_build/default/lib/bsc/ebin -pa /tmp \
%%%       -s algebra main -s init stop
%%%
%%% Under shape B the valve short-circuits on `Subject \ ParamType`. That
%%% residual is a TYPE and the emitter needs a runtime TEST for it, so the
%%% question this answers is: for pairs a stage could plausibly be declared
%%% over, what is the residual, how many arms does it take, and can it be
%%% tested at all?
%%%
%%% Spellable is not the same as discriminable — `bs_emit` is not limited to
%%% forms the surface can spell — so the arm count is evidence and not the
%%% verdict. Row 4's verdict comes from `guard.erl` beside this file, which
%%% asks `erlc` directly.
-module(algebra).
-export([main/0]).

show(Label, Sub, Par) ->
    R = bs_types:subtract(Sub, Par),
    Heads = try bs_types:head_parts(R, #{}) catch C:E -> {raised, C, E} end,
    N = case Heads of L when is_list(L) -> length(L); _ -> unknown end,
    io:format("~s~n", [Label]),
    io:format("  subject  = ~s~n", [bs_types:to_string(Sub)]),
    io:format("  param    = ~s~n", [bs_types:to_string(Par)]),
    io:format("  residual = ~s   (empty=~p)~n",
              [bs_types:to_string(R), bs_types:is_none(R)]),
    io:format("  arms     = ~p~n~n", [N]).

atom_(A) -> bs_types:atom_lit(A).
tup(Ts)  -> bs_types:tuple(Ts).
u(A, B)  -> bs_types:union(A, B).

main() ->
    Bin = bs_types:binary_top(),
    Str = bs_types:string(),
    Int = bs_types:int(),
    Err = tup([atom_(error), Int]),
    Nothing = atom_(nothing),

    %% 1. Today's valve, expressed as a subtraction. One arm, as shipped.
    show("1. ordinary: subject minus the success member", u(Int, Err), Int),

    %% 2. The `option<T>` chain ticket 17 borrowed the operator for, and which
    %%    the valve refuses today. Shape B and shape C both serve it.
    show("2. option<int>, stage over int", u(Int, Nothing), Int),

    %% 3. A residual spanning MORE than one member. The valve stops being
    %%    two-armed, and a chain's type becomes a union of per-stage residuals.
    show("3. residual spans two members", u(u(Int, Nothing), Err), Int),

    %% 4. The refinement case. Non-empty residual, NO head — and `guard.erl`
    %%    shows no BEAM guard behind it either. Shape B has no arm to emit.
    show("4. binary minus string", Bin, Str),

    %% 5. Shape C's exposure. `option<atom>` normalises to bare `atom`, so a
    %%    fixed short-circuit set would stop on a legitimate success. Ticket 15
    %%    Sec 1 refuses this AT THE DECLARATION — decided, and measured unbuilt.
    Atom = bs_types:atom_top(),
    OptAtom = u(Atom, Nothing),
    io:format("5. option<atom> collapses to atom = ~p~n",
              [bs_types:is_subtype(Atom, OptAtom)
               andalso bs_types:is_subtype(OptAtom, Atom)]),
    io:format("   :nothing survives in it        = ~s~n~n",
              [bs_types:to_string(bs_types:intersect(OptAtom, Nothing))]),

    %% 6. Shape C's SECOND exposure, and this one has no decision behind it.
    %%    `:found | :nothing` does not collapse, so 15 Sec 1 passes it even once
    %%    built — yet a fixed set still short-circuits on `:nothing`, and
    %%    `valve_on_infallible` does not fire because the meet is non-empty.
    Enum = u(atom_(found), Nothing),
    io:format("6. subject                = ~s~n", [bs_types:to_string(Enum)]),
    io:format("   collapses?             = ~p~n",
              [bs_types:is_subtype(Enum, atom_(found))]),
    io:format("   subject ^ :nothing     = ~s  (valve_on_infallible fires? ~p)~n",
              [bs_types:to_string(bs_types:intersect(Enum, Nothing)),
               bs_types:is_none(bs_types:intersect(Enum, Nothing))]),
    ok.
