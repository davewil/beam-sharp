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
%% Exported so the emitter resolves surface types through THIS function rather
%% than its own copy. The copy predates records and adding a second minting site
%% to it would have put ticket 26 §1's qualified-name rule in two places.
-export([resolve/2, qualified/2, record_fields/1]).

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
        []     -> {ok, #{module => Module, functions => Fns, env => Env,
                         behaviours => behaviours(Decls)}, Diags};
        _Fatal -> {error, Diags}
    end.

%% The behaviours this module implements. Checking the callback contract against
%% them is decided and not built; what is emitted today is the attribute, which
%% makes `erlc` itself report a missing callback.
behaviours(Decls) -> [N || {behaviour, _, N} <- Decls].

module_name(Decls) ->
    case [N || {module, _, N} <- Decls] of
        [N | _] -> N;
        []      -> 'Main'
    end.

%%% ---------------------------------------------------------------------------
%%% Gathering signatures and their clauses
%%% ---------------------------------------------------------------------------

collect(Decls) ->
    %% A foreign declaration is FINISHED, not unfinished: it is a signature with
    %% no clauses that will never have any, so it must not be collected here or
    %% it reports `no_clauses`.
    Sigs = [#fn{name = N, line = L, ret = R, params = P}
            || {signature, L, N, R, P} <- Decls],
    [F#fn{clauses = [C || C = {clause, _, Name, _, _, _} <- Decls,
                          Name =:= F#fn.name]}
     || F <- Sigs].

%%% ---------------------------------------------------------------------------
%%% Resolving surface types into the algebra
%%% ---------------------------------------------------------------------------

type_env(Decls) ->
    Mod = module_name(Decls),
    Aliases = [{N, T} || {type_alias, _, N, T} <- Decls],
    Records = [{N, record_surface(Mod, L, N, Fs)}
               || {record_decl, L, N, Fs} <- Decls],
    Env = maps:from_list(Aliases ++ Records),
    %% Ticket 09 made recursion equirecursive and contractive; this slice has no
    %% recursive aliases yet, so a single non-recursive resolution pass is enough.
    maps:map(fun(_, T) -> resolve(T, Env) end, Env).

%% Ticket 26 §1: a record IS a map type carrying a minted tag, so there is no
%% record node in the algebra — the declaration desugars to the anonymous map
%% type a user could have written, which is the whole of F3.2.
record_surface(Mod, Line, Name, Fields) ->
    %% The mint would otherwise silently overwrite a field the user declared.
    %% Erroring at the DECLARATION rather than at a use is ticket 15's collapse
    %% rule applied to the same kind of hazard.
    case [F || F = {field, 'Kind', _} <- Fields] of
        [] -> ok;
        _  -> erlang:error({kind_field_is_minted, Line, Name})
    end,
    {t_map, [{field, 'Kind', {t_atom, qualified(Mod, Name)}} | Fields]}.

%% THE SINGLE MINTING POINT. Ticket 26 §1 makes it a hard requirement that the
%% tag mints from the QUALIFIED name — with the short name, `Shop.Orders.Order`
%% and `Billing.Invoices.Order` both mint `:order` and two bounded contexts
%% silently unify. What a qualified name lowers to belongs to the map's module
%% fog, so it is confined here: one function, changed in one place.
qualified(Mod, Name) ->
    list_to_atom(atom_to_list(Mod) ++ "." ++ atom_to_list(Name)).

%% The declared field order, for the emitter. `Kind` is dropped: it is minted,
%% never assigned.
record_fields({t_map, Fields}) -> [N || {field, N, _} <- Fields, N =/= 'Kind'].

%% An already-resolved type passes through, so the emitter can hand this either
%% a surface type or one the environment has already reduced.
resolve(T, _Env) when is_map(T)  -> T;
resolve({t_atom, A}, _Env)    -> bs_types:atom_lit(A);
resolve({t_builtin, B}, _Env) -> builtin(B);
resolve({t_ref, N}, Env) ->
    case maps:get(N, Env, undefined) of
        undefined -> erlang:error({unknown_type, N});
        T when is_map(T) -> T;
        Surface -> resolve(Surface, Env)
    end;
resolve({t_tuple, Cs}, Env)   -> bs_types:tuple([resolve(C, Env) || C <- Cs]);
%% A DECLARED map type is closed — it fixes its domain. Ticket 26 §4's "no
%% absent fields" is what makes that sound, and §5 then closes row polymorphism
%% rather than deferring it: a wider record is simply a different type.
resolve({t_map, Fields}, Env) ->
    bs_types:map_closed(maps:from_list([{N, resolve(T, Env)} || {field, N, T} <- Fields]));
resolve({t_generic, list, T}, Env) -> bs_types:list(resolve(T, Env));
resolve({t_generic, N, _}, _Env)   -> erlang:error({unknown_generic, N});
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
            Scope = lists:append([scope_diags(C) || C <- Clauses]),
            {Residual, Diags0} = walk(Clauses, Declared, Env, [], 1),
            Diags = Scope ++ Diags0,
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

%%% ---------------------------------------------------------------------------
%%% Scope — ticket 34's bindings
%%%
%%% This walks a BODY, which ticket 33 says the checker does not do. The two are
%%% not in tension: 33 is about whether a body is *typed*, and nothing here asks
%%% what type anything has. These are name questions, decidable syntactically,
%%% and they are here because the alternative is `erlc` reporting them against
%%% the emitted `.abstr` — a file the author did not write.
%%%
%%% Bindings do not shadow. A name means one thing in a clause, so rebinding is
%%% an error rather than a new scope: ticket 08's rule that narrowing is always
%%% written applies to names too, and a second `x =` reads as an assignment in
%%% a language that has no mutation to assign with.
%%% ---------------------------------------------------------------------------

scope_diags({clause, Line, Name, Patterns, _, Body}) ->
    Bound = lists:append([pattern_vars(P) || P <- Patterns]),
    check_scope(Body, Bound, Name, Line, []).

check_scope({e_block, _, Binds, Final}, Bound0, Name, Line, Acc0) ->
    {Bound, Acc} =
        lists:foldl(
          fun({bind, L, V, E}, {B, A}) ->
                  A1 = unbound(E, B, L, Name, A),
                  case lists:member(V, B) of
                      true  -> {B, [{error, L, Name, {rebinding, V}} | A1]};
                      false -> {[V | B], A1}
                  end
          end, {Bound0, Acc0}, Binds),
    %% The final expression carries no line of its own — the parser keeps one
    %% per binding and one per clause — so an unbound name in it is reported
    %% against the clause, which is the smallest span that is certainly right.
    unbound(Final, Bound, Line, Name, Acc);
check_scope(Final, Bound, Name, Line, Acc) ->
    unbound(Final, Bound, Line, Name, Acc).

unbound(Expr, Bound, Line, Name, Acc) ->
    [{error, Line, Name, {unbound_variable, V}}
     || V <- lists:usort(expr_vars(Expr)), not lists:member(V, Bound)] ++ Acc.

pattern_vars({p_var, _, V})            -> [V];
pattern_vars({p_tuple, _, Ps})         -> lists:append([pattern_vars(P) || P <- Ps]);
pattern_vars({p_map, _, Fs})           -> lists:append([pattern_vars(P) || {_, P} <- Fs]);
pattern_vars({p_list, _, Items, Rest}) ->
    lists:append([pattern_vars(P) || P <- Items])
        ++ case Rest of nil -> []; R -> pattern_vars(R) end;
pattern_vars(_)                        -> [].

%% Every variable an expression READS. Deliberately not shared with the
%% emitter's `used_vars/2`, which answers a different question — whether to
%% underscore a name it is about to emit — and would drag a lowering concern
%% into the checker to save ten lines.
expr_vars({e_var, _, V})               -> [V];
expr_vars({e_proj, _, V, _})           -> [V];
expr_vars({e_tuple, _, Es})            -> lists:append([expr_vars(E) || E <- Es]);
expr_vars({e_call, _, _, As})          -> lists:append([expr_vars(A) || A <- As]);
expr_vars({e_foreign_call, _, _, _, As}) -> lists:append([expr_vars(A) || A <- As]);
expr_vars({e_op, _, _, A, B})          -> expr_vars(A) ++ expr_vars(B);
expr_vars({e_record, _, _, Fs})        -> lists:append([expr_vars(E) || {_, E} <- Fs]);
expr_vars({e_with, _, Base, Fs})       ->
    expr_vars(Base) ++ lists:append([expr_vars(E) || {_, E} <- Fs]);
expr_vars({e_list, _, Items, Rest})    ->
    lists:append([expr_vars(E) || E <- Items])
        ++ case Rest of nil -> []; R -> expr_vars(R) end;
expr_vars({e_block, _, Binds, Final})  ->
    lists:append([expr_vars(E) || {bind, _, _, E} <- Binds]) ++ expr_vars(Final);
expr_vars(_)                           -> [].

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
    {Components, Bindings, Exact} = pattern_row(Patterns, Env),
    Base = bs_types:tuple(Components),
    {Certain, Possible} = apply_guard(Base, Bindings, Guard),
    case Exact of
        true  -> {Certain, Possible};
        %% An inexact pattern over-states what it matches — `[0, ..t]` is not
        %% every non-empty list — so it may bound Possible but must credit
        %% NOTHING to Certain. Same rule as an untranslatable guard, and the same
        %% reason: crediting an over-estimate is what makes a compiler claim
        %% coverage it does not have.
        false -> {bs_types:none(), Possible}
    end.

pattern_row(Patterns, Env) ->
    Triples = [pattern_type(P, [I], Env)
               || {P, I} <- lists:zip(Patterns, lists:seq(1, length(Patterns)))],
    Tys   = [T || {T, _, _} <- Triples],
    Binds = [B || {_, B, _} <- Triples],
    Exact = lists:all(fun({_, _, E}) -> E end, Triples),
    {Tys, lists:foldl(fun maps:merge/2, #{}, Binds), Exact}.

%% A pattern yields the set of values it matches, plus where each variable sits,
%% so a guard can refine that position afterwards.
%% Returns {Type, Bindings, Exact}. `Exact` is whether the type is exactly what
%% the pattern matches rather than an upper bound — see clause_type/2.
pattern_type({p_int, _, N}, _Path, _Env)  -> {bs_types:range(N, N), #{}, true};
pattern_type({p_atom, _, A}, _Path, _Env) -> {bs_types:atom_lit(A), #{}, true};
pattern_type({p_wild, _}, _Path, _Env)    -> {bs_types:term(), #{}, true};
pattern_type({p_var, _, V}, Path, _Env)   -> {bs_types:term(), #{V => Path}, true};
pattern_type({p_tuple, _, Ps}, Path, Env) ->
    Indexed = lists:zip(Ps, lists:seq(1, length(Ps))),
    Triples = [pattern_type(P, Path ++ [I], Env) || {P, I} <- Indexed],
    {bs_types:tuple([T || {T, _, _} <- Triples]),
     lists:foldl(fun maps:merge/2, #{}, [B || {_, B, _} <- Triples]),
     lists:all(fun({_, _, E}) -> E end, Triples)};
%% A property pattern is OPEN: it constrains the fields it names and nothing
%% else. That is what lets `Which({ Kind: :'Shop.Order' })` cover a whole record
%% in one clause, and it is exact — the pattern matches precisely the maps whose
%% named fields lie in those types, so it credits `Certain` in full.
%%
%% Field paths are real rather than `no_path`. Handing these to the guard
%% machinery as unrefinable would be worse than imprecise: `refine_all/3` turns
%% an unknown path into `none_marker`, so a clause with both a record pattern
%% and a guard would credit NOTHING and the function would report inexhaustive.
pattern_type({p_map, _, Fields}, Path, Env) ->
    Triples = [{K, pattern_type(P, Path ++ [{field, K}], Env)} || {K, P} <- Fields],
    {bs_types:map_open(maps:from_list([{K, T} || {K, {T, _, _}} <- Triples])),
     lists:foldl(fun maps:merge/2, #{}, [B || {_, {_, B, _}} <- Triples]),
     lists:all(fun({_, {_, _, E}}) -> E end, Triples)};
pattern_type({p_nil, _}, _Path, _Env) -> {bs_types:nil(), #{}, true};
%% Ticket 08 settled prefix-plus-rest only, so a list pattern without a rest is
%% rejected rather than approximated.
pattern_type({p_list, Line, _Items, nil}, _Path, _Env) ->
    erlang:error({list_pattern_needs_rest, Line});
pattern_type({p_list, _, Items, Rest}, _Path, _Env) ->
    %% `[h, ..t]` matches every non-empty list; `[0, ..t]` matches only some, so
    %% it is an upper bound and credits nothing.
    Exact = lists:all(fun open_pattern/1, Items) andalso open_pattern(Rest),
    Binds = lists:foldl(fun maps:merge/2, #{}, [binding(P) || P <- Items ++ [Rest]]),
    {bs_types:cons(bs_types:term()), Binds, Exact}.

open_pattern({p_var, _, _}) -> true;
open_pattern({p_wild, _})   -> true;
open_pattern(_)             -> false.

%% List elements are bound but have no tuple path, so a guard over one is not
%% refinable — refine_all/3 treats that conservatively.
binding({p_var, _, V}) -> #{V => no_path};
binding(_)             -> #{}.

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
            Results = [refine_all(Ty, Bindings, A) || A <- Alts],
            case lists:member(none_marker, Results) of
                true  -> {bs_types:none(), Ty};
                false -> Refined = bs_types:union(Results), {Refined, Refined}
            end
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
      fun(_, none_marker) -> none_marker;
         ({V, C}, Acc) ->
              case maps:get(V, Bindings, undefined) of
                  %% A guard naming something no pattern bound, or bound
                  %% somewhere the algebra cannot address (a list element),
                  %% cannot be credited. Returning Acc unchanged would credit
                  %% the clause with its whole pattern despite an unread guard,
                  %% which is the soundness bug the `Certain`/`Possible` split
                  %% exists to prevent.
                  undefined -> none_marker;
                  no_path   -> none_marker;
                  Path      -> refine_at(Acc, Path, C)
              end;
         (unknown, Acc) -> Acc
      end, Ty, Constraints).

%% Descend into a record field. The map part of a pattern's type is always a
%% list of members — `top` only ever arises from `term`, which no pattern
%% produces at this position — so narrowing it away is unreachable rather than
%% conservative, and it is written that way so a future `top` under-credits
%% instead of silently over-crediting.
refine_at(Ty = #{maps := top}, [{field, _} | _], _C) ->
    Ty#{maps := []};
refine_at(Ty = #{maps := Members}, [{field, K} | Rest], C) ->
    Refined =
        [begin
             Comp = maps:get(K, Fields),
             New = case Rest of
                       [] -> apply_constraint(Comp, C);
                       _  -> refine_at(Comp, Rest, C)
                   end,
             {Kind, Fields#{K => New}}
         end || {Kind, Fields} <- Members, maps:is_key(K, Fields)],
    Ty#{maps := [M || M = {_, Fs} <- Refined,
                      not lists:any(fun bs_types:is_none/1, maps:values(Fs))]};
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
