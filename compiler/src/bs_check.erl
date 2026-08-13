%%% The exhaustiveness checker — ticket 04's mechanism, made executable.
%%%
%%% The whole idea in three lines:
%%%
%%%   residual := the declared input type
%%%   for each clause: residual := residual \ (what that clause matches)
%%%   exhaustive iff residual is empty
%%%
%%% Ticket 04's binding constraint is why a signature is mandatory: exhaustiveness
%%% is *absolute* — the union of clause domains against a domain someone hands you
%%% — so without a declared input type the question is not merely hard, it is
%%% ill-posed. Elixir cannot ask it because it builds the function type from the
%%% clauses themselves, which makes the check vacuous.
%%%
%%% Guards participate. Ticket 08's rule is that the checker credits any condition
%%% it can translate into a type operation, and names `n > 1` as an interval
%%% refinement — which ticket 20 made real by putting intervals in the algebra.
%%% A condition it cannot translate (a call to a user function) credits nothing,
%%% which is sound: the clause then subtracts only what its pattern alone matches.

-module(bs_check).

-export([check/1]).

-record(fn, {name, line, ret, params, clauses = []}).

%%% ---------------------------------------------------------------------------
%%% Entry point
%%% ---------------------------------------------------------------------------

%% Returns {ok, Module, [Diagnostic]} | {error, [Diagnostic]}.
check(Decls) ->
    Env = type_env(Decls),
    Module = module_name(Decls),
    Fns = collect(Decls),
    Results = [check_fn(F, Env) || F <- Fns],
    Diags = lists:append([D || {_, D} <- Results]),
    case [D || D <- Diags, element(1, D) =:= error] of
        []     -> {ok, #{module => Module, functions => Fns, env => Env}, Diags};
        _Fatal -> {error, Diags}
    end.

module_name(Decls) ->
    case [N || {module, _, N} <- Decls] of
        [N | _] -> N;
        []      -> 'Main'
    end.

%%% ---------------------------------------------------------------------------
%%% Gathering signatures and their clauses
%%% ---------------------------------------------------------------------------

collect(Decls) ->
    Sigs = [#fn{name = N, line = L, ret = R, params = P}
            || {signature, L, N, R, P} <- Decls],
    [F#fn{clauses = [C || C = {clause, _, Name, _, _, _} <- Decls,
                          Name =:= F#fn.name]}
     || F <- Sigs].

%%% ---------------------------------------------------------------------------
%%% Resolving surface types into the algebra
%%% ---------------------------------------------------------------------------

type_env(Decls) ->
    Aliases = [{N, T} || {type_alias, _, N, T} <- Decls],
    Env = maps:from_list(Aliases),
    %% Ticket 09 made recursion equirecursive and contractive; this slice has no
    %% recursive aliases yet, so a single non-recursive resolution pass is enough.
    maps:map(fun(_, T) -> resolve(T, Env) end, Env).

resolve({t_atom, A}, _Env)    -> bs_types:atom_lit(A);
resolve({t_builtin, B}, _Env) -> builtin(B);
resolve({t_ref, N}, Env) ->
    case maps:get(N, Env, undefined) of
        undefined -> erlang:error({unknown_type, N});
        T when is_map(T) -> T;
        Surface -> resolve(Surface, Env)
    end;
resolve({t_tuple, Cs}, Env)   -> bs_types:tuple([resolve(C, Env) || C <- Cs]);
resolve({t_union, Ms}, Env)   -> bs_types:union([resolve(M, Env) || M <- Ms]).

%% Builtins are lowercase — ticket 27 forced that, since a lowercase-implicit
%% type-variable convention would then be ambiguous.
builtin(int)  -> bs_types:int();
builtin(atom) -> bs_types:atom_top();
builtin(term) -> bs_types:term();
builtin(bool) -> bs_types:union(bs_types:atom_lit(true), bs_types:atom_lit(false));
builtin(B)    -> erlang:error({unknown_builtin, B}).

%%% ---------------------------------------------------------------------------
%%% Checking one function
%%% ---------------------------------------------------------------------------

check_fn(F = #fn{name = Name, line = Line, params = Params}, Env) ->
    %% The argument list is treated as a product, so exhaustiveness across all
    %% parameters is one subtraction rather than one per column. This is the
    %% cross-clause part of ticket 04: a clause need not be redundant in any
    %% single column to be redundant overall.
    Declared = bs_types:tuple([resolve(T, Env) || {param, T, _} <- Params]),
    case F#fn.clauses of
        [] ->
            {F, [{error, Line, Name, no_clauses}]};
        Clauses ->
            {Residual, Diags} = walk(Clauses, Declared, Env, [], 1),
            Final =
                case bs_types:is_none(Residual) of
                    true  -> Diags;
                    %% The residual is carried as a *type*, not a string: ticket
                    %% 04 found it IS the missing case, so the caller formats it
                    %% as a clause head rather than as a type expression.
                    false -> Diags ++ [{error, Line, Name, {inexhaustive, Residual}}]
                end,
            {F, Final}
    end.

walk([], Residual, _Env, Diags, _N) ->
    {Residual, lists:reverse(Diags)};
walk([C = {clause, CLine, Name, _, _, _} | Rest], Residual, Env, Diags, N) ->
    %% Two bounds, and conflating them is a soundness bug rather than an
    %% imprecision. `Certain` is what the clause is *guaranteed* to match, and is
    %% the only thing that may be subtracted from the residual — an over-estimate
    %% there makes the compiler claim coverage it does not have. `Possible` is
    %% what the clause *could* match, and is what redundancy is judged against —
    %% an under-estimate there would call a live clause dead.
    %%
    %% They differ exactly when a guard is not translatable to a type operation.
    {Certain, Possible} = clause_type(C, Env),
    %% Redundancy is *relative* — clause i against the clauses before it — which
    %% is why it is checked against the running residual rather than the declared
    %% type. Ticket 04 drew that distinction and it falls straight out here.
    Diags1 =
        case bs_types:is_none(bs_types:intersect(Possible, Residual)) of
            true  -> [{warning, CLine, Name, {unreachable_clause, N}} | Diags];
            false -> Diags
        end,
    walk(Rest, bs_types:subtract(Residual, Certain), Env, Diags1, N + 1).

%%% ---------------------------------------------------------------------------
%%% What a clause matches
%%% ---------------------------------------------------------------------------

%% Returns {Certain, Possible} — see walk/5 for why both are needed.
clause_type({clause, _, _, Patterns, Guard, _}, Env) ->
    {Components, Bindings} = pattern_row(Patterns, Env),
    Base = bs_types:tuple(Components),
    apply_guard(Base, Bindings, Guard).

pattern_row(Patterns, Env) ->
    {Tys, Binds} =
        lists:unzip([pattern_type(P, [I], Env)
                     || {P, I} <- lists:zip(Patterns, lists:seq(1, length(Patterns)))]),
    {Tys, lists:foldl(fun maps:merge/2, #{}, Binds)}.

%% A pattern yields the set of values it matches, plus where each variable sits,
%% so a guard can refine that position afterwards.
pattern_type({p_int, _, N}, _Path, _Env)  -> {bs_types:range(N, N), #{}};
pattern_type({p_atom, _, A}, _Path, _Env) -> {bs_types:atom_lit(A), #{}};
pattern_type({p_wild, _}, _Path, _Env)    -> {bs_types:term(), #{}};
pattern_type({p_var, _, V}, Path, _Env)   -> {bs_types:term(), #{V => Path}};
pattern_type({p_tuple, _, Ps}, Path, Env) ->
    Indexed = lists:zip(Ps, lists:seq(1, length(Ps))),
    {Tys, Binds} = lists:unzip([pattern_type(P, Path ++ [I], Env) || {P, I} <- Indexed]),
    {bs_types:tuple(Tys), lists:foldl(fun maps:merge/2, #{}, Binds)}.

%%% ---------------------------------------------------------------------------
%%% Guards as type operations
%%% ---------------------------------------------------------------------------

apply_guard(Ty, _Bindings, none) ->
    %% No guard: the pattern alone decides, so both bounds coincide.
    {Ty, Ty};
apply_guard(Ty, Bindings, {guard, Expr}) ->
    %% A guard is normalised to alternatives (`||`), each a conjunction (`&&`)
    %% of per-variable constraints. Alternatives union; conjunctions intersect.
    case alternatives(Expr) of
        unknown ->
            %% Ticket 08: `HasSku(lines, sku)` credits nothing.
            %%
            %% "Credits nothing" has to mean the clause contributes NOTHING to the
            %% residual — not that it contributes its whole pattern. A guard the
            %% checker cannot read might always fail, so nothing is guaranteed to
            %% be matched here. Getting this backwards let `F(n) when Weird(n)`
            %% report as exhaustive, which is the precise failure the map's
            %% guarantee exists to rule out; a test caught it.
            {bs_types:none(), Ty};
        Alts ->
            Refined = bs_types:union([refine_all(Ty, Bindings, A) || A <- Alts]),
            {Refined, Refined}
    end.

%% [] means "no constraint"; unknown means "not translatable".
alternatives({e_op, _, '||', L, R}) ->
    case {alternatives(L), alternatives(R)} of
        {unknown, _} -> unknown;
        {_, unknown} -> unknown;
        {A, B}       -> A ++ B
    end;
alternatives({e_op, _, '&&', L, R}) ->
    case {alternatives(L), alternatives(R)} of
        {unknown, _} -> unknown;
        {_, unknown} -> unknown;
        %% A conjunction of two alternative-sets is their pairwise concatenation.
        {As, Bs}     -> [A ++ B || A <- As, B <- Bs]
    end;
alternatives(Cmp) ->
    case comparison(Cmp) of
        unknown     -> unknown;
        Constraint  -> [[Constraint]]
    end.

comparison({e_op, _, Op, {e_var, _, V}, {e_int, _, K}}) -> int_cmp(Op, V, K);
comparison({e_op, _, Op, {e_int, _, K}, {e_var, _, V}}) -> int_cmp(flip(Op), V, K);
comparison({e_op, _, '==', {e_var, _, V}, {e_atom, _, A}}) ->
    {V, {include, bs_types:atom_lit(A)}};
comparison({e_op, _, '!=', {e_var, _, V}, {e_atom, _, A}}) ->
    {V, {exclude, bs_types:atom_lit(A)}};
comparison(_) ->
    unknown.

int_cmp('>',  V, K) -> {V, {include, bs_types:range(K + 1, pos_inf)}};
int_cmp('>=', V, K) -> {V, {include, bs_types:range(K, pos_inf)}};
int_cmp('<',  V, K) -> {V, {include, bs_types:range(neg_inf, K - 1)}};
int_cmp('<=', V, K) -> {V, {include, bs_types:range(neg_inf, K)}};
int_cmp('==', V, K) -> {V, {include, bs_types:range(K, K)}};
int_cmp('!=', V, K) -> {V, {exclude, bs_types:range(K, K)}};
int_cmp(_, _, _)    -> unknown.

flip('>')  -> '<';
flip('<')  -> '>';
flip('>=') -> '<=';
flip('<=') -> '>=';
flip(Op)   -> Op.

refine_all(Ty, Bindings, Constraints) ->
    lists:foldl(
      fun({V, C}, Acc) ->
              case maps:get(V, Bindings, undefined) of
                  undefined -> Acc;          % guard mentions an unbound name
                  Path      -> refine_at(Acc, Path, C)
              end;
         (unknown, Acc) -> Acc
      end, Ty, Constraints).

%% Replace the component at a path with its intersection (or difference).
refine_at(Ty, [I | Rest], C) ->
    #{tuples := Products} = Ty,
    Refined =
        [begin
             Comp = lists:nth(I, P),
             New = case Rest of
                       [] -> apply_constraint(Comp, C);
                       _  -> refine_at(Comp, Rest, C)
                   end,
             setnth(I, P, New)
         end || P <- Products, length(P) >= I],
    Kept = [P || P <- Refined, not lists:any(fun bs_types:is_none/1, P)],
    Ty#{tuples := Kept}.

apply_constraint(Ty, {include, C}) -> bs_types:intersect(Ty, C);
apply_constraint(Ty, {exclude, C}) -> bs_types:subtract(Ty, C).

setnth(1, [_ | T], V) -> [V | T];
setnth(N, [H | T], V) -> [H | setnth(N - 1, T, V)].
