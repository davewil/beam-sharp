#!/usr/bin/env escript
%%! -pa compiler/_build/default/lib/bsc/ebin
%%
%% 37a — Instantiation is matching: does the algebra support the algorithm?
%%
%% Ticket 37 asks what "match `list<Order>` against `list<TSource>`, read off
%% `TSource = Order`" actually IS. Ticket 63 settled two of 27 §1's three
%% adjectives — `structural` and `cheap` — by measuring that the guard fragment
%% is closed under complement. **Uniqueness is the sole survivor**: for
%% `T | :nothing = int | :nothing`, both `T = int` and `T = int | :nothing`
%% satisfy the equation, and an exact subtraction yields the SMALLEST solution
%% without establishing that smallest is INTENDED.
%%
%% WHAT THIS MEASURES, AND WHAT IT DOES NOT.
%%
%% This probes the **algebra**, not the compiler. There is no type variable in
%% `bs_types` — measured, `ty()` has exactly six parts and none of them is one —
%% and the surface cannot spell a `<T>` declaration list on a signature at all.
%% So the candidate algorithm is implemented HERE, in the probe, over the real
%% exported operations (`subtract/2`, `union/2`, `is_subtype/2`, `list_elem/1`).
%% A green run says the algorithm is expressible on the algebra that exists
%% today; it says nothing about `bs_check`, which does not solve for a variable.
%%
%% Run from the REPOSITORY ROOT, never from inside compiler/: a C.beam in that
%% directory shadows stdlib's `c` on macOS and a bare escript/erl dies there.
%%
%%     escript wayfinder/prototypes/37a_instantiation_by_matching.escript
%%
%% Every measurement prints PASS/FAIL against a stated expectation and carries a
%% CONTROL, so a result cannot be produced by an operation that behaves the same
%% way on everything.
%%
%% THE CANDIDATE ALGORITHM, stated before it is measured:
%%
%%   1. SOLVE, least, per occurrence. Walk the parameter template against the
%%      argument type. A bare variable takes the whole share. Under `list<_>`,
%%      take `list_elem`. Under a tuple component, take that component's
%%      projection. Inside a UNION, a member's share is the argument MINUS the
%%      union of every other member's MAXIMAL EXTENT (that member with all its
%%      variables set to `term`). That subtraction is what 63 proved exact.
%%   2. JOIN, across occurrences. A variable occurring more than once takes the
%%      union of its per-occurrence solutions. Licensed by 27 §2 — a variable is
%%      opaque in clause heads, so the body cannot inspect what it widened to.
%%   3. SUBSTITUTE, then CONTAIN. Site 1's ordinary `subtract`+`is_none` check
%%      runs against the substituted parameter type.
%%
%% M4 is the load-bearing one: it tries to FALSIFY step 3 being able to fail.

-mode(compile).

main(_) ->
    io:format("~n== 37a — instantiation by matching, over the real algebra ==~n~n"),
    R = [m1_the_interval_is_real(),
         m2_least_is_what_makes_the_return_informative(),
         m3_the_corpus_cases_reproduce(),
         m4_can_containment_fail_after_a_solve(),
         m5_a_variable_twice_joins(),
         m6_which_parameters_can_reject_at_all()],
    io:format("~n-- ~p measurements, ~p as expected --~n",
              [length(R), length([x || true <- R])]),
    case lists:all(fun(X) -> X end, R) of
        true  -> io:format("37a: all measurements as expected~n"), halt(0);
        false -> io:format("37a: A MEASUREMENT DID NOT MATCH~n"),  halt(1)
    end.

%%% ---------------------------------------------------------------------------
%%% Templates. A parameter type with holes, as `bs_check` stores a `{parametric,
%%% Params, Body}` alias body — a SURFACE form with `{t_ref, V}` in it. The
%%% probe's spelling is its own; the shape is the tree's.
%%% ---------------------------------------------------------------------------

v(V)      -> {v, V}.                       % a bare type variable
g(Ty)     -> {g, Ty}.                      % a ground type
lst(T)    -> {lst, T}.                     % list<T>
tup(Ts)   -> {tup, Ts}.                    % (T1, ..., Tn)
un(Ts)    -> {un, Ts}.                     % T1 | ... | Tn

%% The prelude's two parametric aliases, spelled exactly as `bs_check:713-718`
%% has them. BOTH put a BARE variable directly inside a union, which is the
%% shape the whole uniqueness question is about.
opt(T)    -> un([T, g(bs_types:atom_lit(nothing))]).
res(T, E) -> un([T, tup([g(bs_types:atom_lit(error)), E])]).

%% Maximal extent — the template with every variable at `term`. This is what
%% lets a union member say how much of the argument could POSSIBLY be its share.
extent({v, _})     -> bs_types:term();
extent({g, Ty})    -> Ty;
extent({lst, T})   -> bs_types:list(extent(T));
extent({tup, Ts})  -> bs_types:tuple([extent(T) || T <- Ts]);
extent({un, Ts})   -> lists:foldl(fun(T, A) -> bs_types:union(extent(T), A) end,
                                  bs_types:none(), Ts).

%% STEP 1 — solve, least, per occurrence. Returns #{Var => [ty()]}.
solve({g, _}, _A, Acc) -> Acc;
solve({v, V}, A, Acc)  -> maps:update_with(V, fun(L) -> [A | L] end, [A], Acc);
solve({lst, T}, A, Acc) -> solve(T, bs_types:list_elem(A), Acc);
solve({tup, Ts}, A, Acc) ->
    N = length(Ts),
    {_, Out} = lists:foldl(
                 fun(T, {I, Ac}) -> {I + 1, solve(T, tuple_proj(A, N, I), Ac)} end,
                 {1, Acc}, Ts),
    Out;
solve({un, Ts}, A, Acc) ->
    %% A member's share is the argument minus every OTHER member's maximal
    %% extent. Exact, by 63. This is the step 27 §1 called "read off" and never
    %% specified, and it is the only step where the answer is a CHOICE.
    lists:foldl(
      fun({I, T}, Ac) ->
              Others = [extent(O) || {J, O} <- index(Ts), J =/= I],
              Blocked = lists:foldl(fun bs_types:union/2, bs_types:none(), Others),
              solve(T, bs_types:subtract(A, Blocked), Ac)
      end, Acc, index(Ts)).

%% STEP 2 — join across occurrences.
join(Acc) ->
    maps:map(fun(_, Tys) ->
                     lists:foldl(fun bs_types:union/2, bs_types:none(), Tys)
             end, Acc).

%% STEP 3 — substitute.
subst({g, Ty}, _)   -> Ty;
subst({v, V}, S)    -> maps:get(V, S, bs_types:none());
subst({lst, T}, S)  -> bs_types:list(subst(T, S));
subst({tup, Ts}, S) -> bs_types:tuple([subst(T, S) || T <- Ts]);
subst({un, Ts}, S)  -> lists:foldl(fun(T, A) -> bs_types:union(subst(T, S), A) end,
                                   bs_types:none(), Ts).

%% The whole thing: templates against arguments.
instantiate(Params, Args) ->
    Acc = lists:foldl(fun({P, A}, Ac) -> solve(P, A, Ac) end, #{},
                      lists:zip(Params, Args)),
    join(Acc).

%% Site 1's own containment, spelled as `bs_check:2117-2119` spells it —
%% `subtract` then `is_none`, keeping the residual.
contains(P, A) ->
    R = bs_types:subtract(A, P),
    {bs_types:is_none(R), R}.

check(Params, Args) ->
    S = instantiate(Params, Args),
    Fails = [{I, R} || {I, {P, A}} <- index(lists:zip(Params, Args)),
                       {false, R} <- [contains(subst(P, S), A)]],
    {S, Fails}.

%%% ---------------------------------------------------------------------------
%%% M1 — the interval is real, both endpoints are computable, and the CONTROL
%%%      shows it is specific to a bare variable inside a union.
%%% ---------------------------------------------------------------------------

m1_the_interval_is_real() ->
    io:format("M1 — is the solution really an interval, and is it computable?~n"),
    IntOrNothing = bs_types:union(bs_types:int(), bs_types:atom_lit(nothing)),

    %% option<T> against `int | :nothing`.
    Least = maps:get(t, instantiate([opt(v(t))], [IntOrNothing])),
    Greatest = IntOrNothing,
    LeastOk  = element(1, contains(subst(opt(v(t)), #{t => Least}), IntOrNothing)),
    GreatOk  = element(1, contains(subst(opt(v(t)), #{t => Greatest}), IntOrNothing)),
    Differ   = not bs_types:is_subtype(Greatest, Least),

    io:format("  option<T> vs `int | :nothing`~n"),
    io:format("    least    T = ~ts   (contains: ~p)~n", [bs_types:to_string(Least), LeastOk]),
    io:format("    greatest T = ~ts   (contains: ~p)~n", [bs_types:to_string(Greatest), GreatOk]),
    A = LeastOk andalso GreatOk andalso Differ,
    io:format("    => two DISTINCT solutions, both sound: ~p~n", [A]),

    %% CONTROL — the same machinery on `list<T>`, where the variable is under a
    %% constructor rather than bare in a union. If the ambiguity showed up here
    %% too, M1 would be measuring the machinery and not the shape.
    LstInt = bs_types:list(bs_types:int()),
    CL = maps:get(t, instantiate([lst(v(t))], [LstInt])),
    CUnique = bs_types:is_subtype(CL, bs_types:int())
        andalso bs_types:is_subtype(bs_types:int(), CL),
    io:format("  CONTROL list<T> vs `list<int>`: T = ~ts, unique: ~p~n",
              [bs_types:to_string(CL), CUnique]),
    report(A andalso CUnique,
           "the interval exists ONLY where a bare variable shares a union").

%%% ---------------------------------------------------------------------------
%%% M2 — the reason to prefer LEAST. Both endpoints are sound; only the least
%%%      one keeps the RETURN type worth having.
%%% ---------------------------------------------------------------------------

m2_least_is_what_makes_the_return_informative() ->
    io:format("~nM2 — least vs greatest: what does the RETURN type become?~n"),
    Nothing = bs_types:atom_lit(nothing),

    %% `option<T> First<T>(option<T> o)` handed exactly `:nothing`.
    Least = maps:get(t, instantiate([opt(v(t))], [Nothing])),
    Greatest = bs_types:term(),
    RetLeast = subst(opt(v(t)), #{t => Least}),
    RetGreat = subst(opt(v(t)), #{t => Greatest}),
    BothSound = element(1, contains(RetLeast, Nothing))
        andalso element(1, contains(RetGreat, Nothing)),
    io:format("  option<T> First<T>(option<T>) given `:nothing`~n"),
    io:format("    least    -> returns ~ts~n", [bs_types:to_string(RetLeast)]),
    io:format("    greatest -> returns ~ts~n", [bs_types:to_string(RetGreat)]),
    io:format("    both sound at site 1: ~p~n", [BothSound]),

    %% The least return is exactly `:nothing` — the caller learns the function
    %% cannot have returned anything else. The greatest is the top, and a
    %% `switch` over it is not exhaustible.
    Precise = bs_types:is_subtype(RetLeast, Nothing)
        andalso bs_types:is_subtype(Nothing, RetLeast),
    Useless = bs_types:is_subtype(bs_types:int(), RetGreat),
    io:format("    least return IS `:nothing` exactly: ~p~n", [Precise]),
    io:format("    greatest return admits `int`:       ~p~n", [Useless]),
    report(BothSound andalso Precise andalso Useless,
           "soundness does not choose; the return type does — LEAST").

%%% ---------------------------------------------------------------------------
%%% M3 — the two corpus shapes. 25d's `Prepend` and 25e's `Reverse`, the second
%%%      from ONE template at BOTH of the instantiations the module needs.
%%% ---------------------------------------------------------------------------

m3_the_corpus_cases_reproduce() ->
    io:format("~nM3 — do the corpus's own §(c) shapes come out right?~n"),
    OrderRow   = bs_types:atom_lit(order_row),
    FetchError = bs_types:atom_lit(fetch_error),

    %% 25d rows.bs:38 — `Prepend<T, E>(T, result<list<T>, E>) -> result<list<T>, E>`
    PrependP = [v(t), res(lst(v(t)), v(e))],
    ArgRest  = bs_types:union(bs_types:list(OrderRow),
                              bs_types:tuple([bs_types:atom_lit(error), FetchError])),
    {S1, F1} = check(PrependP, [OrderRow, ArgRest]),
    Ret1 = subst(res(lst(v(t)), v(e)), S1),
    Want1 = ArgRest,
    P1 = (F1 =:= []) andalso bs_types:is_subtype(Ret1, Want1)
        andalso bs_types:is_subtype(Want1, Ret1),
    io:format("  Prepend: T = ~ts, E = ~ts~n",
              [bs_types:to_string(maps:get(t, S1)), bs_types:to_string(maps:get(e, S1))]),
    io:format("    return = ~ts~n", [bs_types:to_string(Ret1)]),
    io:format("    equals the hand-written signature: ~p~n", [P1]),

    %% 25e — `Reverse<T>(list<T>, list<T>) -> list<T>`, the pair the module
    %% REFUSES as two monomorphic copies (`Reverse/2 declared more than once`).
    RevP = [lst(v(t)), lst(v(t))],
    Bin  = bs_types:binary_top(),
    Iod  = bs_types:atom_lit(iodata),          % stand-in; only distinctness matters
    {S2a, F2a} = check(RevP, [bs_types:list(Bin), bs_types:list(Bin)]),
    {S2b, F2b} = check(RevP, [bs_types:list(Iod), bs_types:list(Iod)]),
    P2 = (F2a =:= []) andalso (F2b =:= [])
        andalso bs_types:is_subtype(maps:get(t, S2a), Bin)
        andalso bs_types:is_subtype(maps:get(t, S2b), Iod),
    io:format("  Reverse, ONE template, TWO instantiations: ~ts and ~ts~n",
              [bs_types:to_string(maps:get(t, S2a)), bs_types:to_string(maps:get(t, S2b))]),
    io:format("    both check: ~p~n", [P2]),

    %% CONTROL — the same template given an argument with no list part at all.
    %% If this passed, M3 would not be discriminating.
    {S2c, F2c} = check(RevP, [bs_types:int(), bs_types:list(Bin)]),
    CtlFails = F2c =/= [],
    io:format("  CONTROL Reverse(int, list<binary>): T = ~ts, fails: ~p~n",
              [bs_types:to_string(maps:get(t, S2c, bs_types:none())), CtlFails]),
    report(P1 andalso P2 andalso CtlFails,
           "both corpus shapes reproduce; the control fails").

%%% ---------------------------------------------------------------------------
%%% M4 — THE FALSIFICATION. 27 §5 settled NO VARIANCE, so every variable
%%%      position is covariant; join only widens; widening a variable only
%%%      widens the substituted parameter. So the claim is:
%%%
%%%        containment cannot fail unless the solve found NO part for some
%%%        variable at some occurrence (i.e. that occurrence's share was empty).
%%%
%%%      If true, sub-question 3's answer is "ONE operation, and the failure is
%%%      raised at the position with no matching part" — not "solve then
%%%      contain, and the diagnostic must say which half failed."
%%%
%%%      This searches a grid for a counterexample rather than hand-picking.
%%% ---------------------------------------------------------------------------

m4_can_containment_fail_after_a_solve() ->
    io:format("~nM4 — can containment fail after a solve that found a part?~n"),
    Pool = arg_pool(),
    Templates =
        [{"F<T>(T)",                       [v(t)]},
         {"F<T>(list<T>)",                 [lst(v(t))]},
         {"F<T>(option<T>)",               [opt(v(t))]},
         {"F<T>(T, T)",                    [v(t), v(t)]},
         {"F<T>(list<T>, option<T>)",      [lst(v(t)), opt(v(t))]},
         {"F<T>(option<T>, T)",            [opt(v(t)), v(t)]},
         {"F<T>(list<T>, list<T>)",        [lst(v(t)), lst(v(t))]},
         {"F<T>((T, int))",                [tup([v(t), g(bs_types:int())])]},
         {"F<T>((T, int), T)",             [tup([v(t), g(bs_types:int())]), v(t)]},
         {"F<T,E>(result<list<T>, E>)",    [res(lst(v(t)), v(e))]},
         {"F<T>(option<T>, list<T>)",      [opt(v(t)), lst(v(t))]}],

    Rows = [{Name, Ps, Args} || {Name, Ps} <- Templates,
                                Args <- combos(length(Ps), Pool)],

    %% H1 — the hypothesis this measurement was written to test: containment
    %% cannot fail unless some variable solved to the empty type. 27 §5 settled
    %% NO VARIANCE, so every position is covariant, the join only widens, and a
    %% wider variable only widens the substituted parameter.
    H1 = [{N, S} || {N, Ps, As} <- Rows,
                    {S, F} <- [check(Ps, As)],
                    F =/= [],
                    not lists:any(fun bs_types:is_none/1, maps:values(S))],

    io:format("  ~p (template, argument-tuple) pairs enumerated~n", [length(Rows)]),
    io:format("  H1 'contain cannot fail after a non-empty solve': ~p counterexamples~n",
              [length(H1)]),
    io:format("  H1 is FALSIFIED — the covariance argument does not reach.~n"),

    %% What the counterexamples have in common. `F<T>(list<T>)` given
    %% `list<int> | :nothing` solves T = int quite happily — `list_elem` reads
    %% the list part and simply cannot see the `:nothing`. The solve is not
    %% wrong; it is PARTIAL BY CONSTRUCTION, because a template only ever
    %% interrogates the parts it names. The argument's other parts survive
    %% untouched into the residual.
    Sample = lists:sublist(H1, 3),
    [io:format("    e.g. ~ts with ~ts~n",
               [N, string:join([bs_types:to_string(T) || T <- maps:values(S)], ", ")])
     || {N, S} <- Sample],

    %% H2 — the corrected claim. Containment fails EXACTLY when some argument
    %% escapes its parameter's MAXIMAL EXTENT: the ground skeleton with every
    %% variable at `term`. If that holds in both directions the failure is
    %% decidable BEFORE solving, from a template that mentions no variable at
    %% all — which is what keeps the two diagnostics from having to interleave.
    Disagree = [{N, As} || {N, Ps, As} <- Rows,
                           {_, F} <- [check(Ps, As)],
                           Escapes <- [lists:any(
                                         fun({P, A}) ->
                                                 not bs_types:is_subtype(A, extent(P))
                                         end, lists:zip(Ps, As))],
                           (F =/= []) =/= Escapes],
    io:format("  H2 'contain fails <=> an argument escapes the maximal extent':~n"),
    io:format("    disagreements in either direction: ~p~n", [length(Disagree)]),
    [io:format("    MISMATCH ~ts~n", [N]) || {N, _} <- lists:sublist(Disagree, 5)],

    %% CONTROL — H2 must be capable of disagreeing. Feed the same predicate a
    %% deliberately WRONG extent (the parameter with variables at `none` rather
    %% than `term`) and it must now mismatch on cases it got right before. A
    %% predicate that agrees with everything would pass H2 while measuring
    %% nothing.
    Bogus = [{N, As} || {N, Ps, As} <- Rows,
                        {_, F} <- [check(Ps, As)],
                        Escapes <- [lists:any(
                                      fun({P, A}) ->
                                              not bs_types:is_subtype(A, subst(P, #{}))
                                      end, lists:zip(Ps, As))],
                        (F =/= []) =/= Escapes],
    io:format("  CONTROL the same test with a deliberately wrong extent: ~p disagreements~n",
              [length(Bogus)]),
    report((H1 =/= []) andalso (Disagree =:= []) andalso (Bogus =/= []),
           "H1 falsified, H2 holds both ways, and the control shows H2 can fail").

%%% ---------------------------------------------------------------------------
%%% M5 — a variable twice. 27 §2's opacity is what licenses the join.
%%% ---------------------------------------------------------------------------

m5_a_variable_twice_joins() ->
    io:format("~nM5 — `T Pick<T>(T, T)` with an int and an atom~n"),
    Int = bs_types:int(),
    At  = bs_types:atom_lit(a),
    {S, Fails} = check([v(t), v(t)], [Int, At]),
    T = maps:get(t, S),
    IsUnion = bs_types:is_subtype(Int, T) andalso bs_types:is_subtype(At, T),
    Tight   = bs_types:is_subtype(T, bs_types:union(Int, At)),
    io:format("  T = ~ts   (call checks: ~p)~n", [bs_types:to_string(T), Fails =:= []]),
    io:format("    contains both arguments: ~p, and nothing more: ~p~n", [IsUnion, Tight]),

    %% CONTROL — the join must not be doing this to everything. Same template,
    %% two arguments of the SAME type: the join must collapse, not widen.
    {S2, _} = check([v(t), v(t)], [Int, Int]),
    Collapses = bs_types:is_subtype(maps:get(t, S2), Int),
    io:format("  CONTROL Pick(int, int): T = ~ts, collapses: ~p~n",
              [bs_types:to_string(maps:get(t, S2)), Collapses]),
    report((Fails =:= []) andalso IsUnion andalso Tight andalso Collapses,
           "the join is the union of the occurrences, and only that").

%%% ---------------------------------------------------------------------------
%%% M6 — the ticket's "makes the variable decorative" worry, made measurable.
%%%      H2 says a parameter rejects an argument exactly when the argument
%%%      escapes the parameter's MAXIMAL EXTENT. So a parameter whose extent is
%%%      `term` cannot reject ANYTHING, whatever the algorithm does.
%%% ---------------------------------------------------------------------------

m6_which_parameters_can_reject_at_all() ->
    io:format("~nM6 — which parameter shapes can reject an argument at all?~n"),
    Shapes = [{"T",                  v(t)},
              {"list<T>",            lst(v(t))},
              {"option<T>",          opt(v(t))},
              {"result<T, E>",       res(v(t), v(e))},
              {"result<list<T>, E>", res(lst(v(t)), v(e))},
              {"(T, int)",           tup([v(t), g(bs_types:int())])},
              {"option<int>",        opt(g(bs_types:int()))}],
    Rows = [{N, bs_types:is_subtype(bs_types:term(), extent(P))} || {N, P} <- Shapes],
    [io:format("    ~-20ts extent is `term`, rejects nothing: ~p~n", [N, Top])
     || {N, Top} <- Rows],

    %% The two prelude parametric aliases, used with a BARE variable, are both
    %% in the unfailable class — and that is a property of the ALIAS SHAPE, not
    %% of the matching algorithm. `option<T> = T | :nothing` with `T` unbounded
    %% denotes the top type. A discriminated spelling would not.
    Unfailable = [N || {N, true} <- Rows],
    Failable   = [N || {N, false} <- Rows],
    io:format("  unfailable: ~ts~n", [string:join(Unfailable, ", ")]),
    io:format("  failable:   ~ts~n", [string:join(Failable, ", ")]),

    Expect = lists:sort(["T", "option<T>", "result<T, E>"]),
    Got    = lists:sort(Unfailable),
    %% CONTROL — `option<int>` differs from `option<T>` in exactly one place,
    %% and it is failable. So the unfailability is the BARE VARIABLE's, not the
    %% union's, and not the alias's name.
    Control = lists:member("option<int>", Failable),
    io:format("  CONTROL option<int> (same union, ground member) is failable: ~p~n", [Control]),
    report((Expect =:= Got) andalso Control,
           "a bare variable as a direct union member makes the parameter unfailable").

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

%% Project component I of every arity-N tuple in the part, unioned. There is no
%% exported accessor for this — `bs_types` exports `tuple/1` but no inverse — so
%% the probe reads the raw part. Recorded as an assumption, not hidden: a real
%% implementation would need `bs_types` to export it.
tuple_proj(#{tuples := top}, _N, _I) -> bs_types:term();
tuple_proj(#{tuples := Rows}, N, I) when is_list(Rows) ->
    lists:foldl(fun(Cs, Acc) when length(Cs) =:= N ->
                        bs_types:union(lists:nth(I, Cs), Acc);
                   (_, Acc) -> Acc
                end, bs_types:none(), Rows).

index(L) -> lists:zip(lists:seq(1, length(L)), L).

arg_pool() ->
    I = bs_types:int(),
    [I,
     bs_types:atom_lit(a),
     bs_types:atom_lit(nothing),
     bs_types:union(I, bs_types:atom_lit(nothing)),
     bs_types:list(I),
     bs_types:union(bs_types:list(I), bs_types:atom_lit(nothing)),
     bs_types:tuple([bs_types:atom_lit(error), I]),
     bs_types:union(bs_types:list(I),
                    bs_types:tuple([bs_types:atom_lit(error), I])),
     bs_types:string(),
     bs_types:tuple([I, I]),
     bs_types:term()].

combos(1, Pool) -> [[X] || X <- Pool];
combos(N, Pool) -> [[X | R] || X <- Pool, R <- combos(N - 1, Pool)].

report(true, Why)  -> io:format("  PASS — ~ts~n", [Why]), true;
report(false, Why) -> io:format("  FAIL — expected: ~ts~n", [Why]), false.
