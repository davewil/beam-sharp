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

%% Everything the body check (ticket 33, F5) needs to answer a question about
%% one clause. `types` is the surface-to-algebra environment and is the ONLY
%% field `resolve/2` sees, because the emitter calls `resolve/2` with that map
%% directly — widening it in place would put a checker concern in the emitter's
%% argument list.
-record(ctx, {types = #{}, callees = #{}, ret, fname, arity = 0, binds = #{}}).

%%% ---------------------------------------------------------------------------
%%% Entry point
%%% ---------------------------------------------------------------------------

%% Returns {ok, Module, [Diagnostic]} | {error, [Diagnostic]}.
check(Decls) ->
    Env = type_env(Decls),
    Module = module_name(Decls),
    Fns = collect(Decls),
    Ctx = #ctx{types = Env, callees = callees(Decls, Env)},
    Results = [check_fn(F, Ctx) || F <- Fns],
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

%% The callee environment — ticket 33 §6. `collect/1` above excludes foreign
%% declarations on purpose, and that exclusion is right for clause checking and
%% WRONG here: a foreign declaration is a signature attached to the name Erlang
%% already has (ticket 32), so its callees are declared exactly like any other
%% and site 1 applies to them verbatim. Local names key on the atom; foreign
%% ones on `{Module, Function}`, which is the pair `e_foreign_call` carries.
callees(Decls, Env) ->
    Local = [{N, sig(Ps, R, Env)} || {signature, _, N, R, Ps} <- Decls],
    Foreign = [{{Mod, N}, sig(Ps, R, Env)}
               || {foreign, _, Mod, Sigs} <- Decls,
                  {foreign_sig, _, N, R, Ps} <- Sigs],
    maps:from_list(Local ++ Foreign).

sig(Params, Ret, Env) ->
    {[resolve(T, Env) || {param, T, _} <- Params], resolve(Ret, Env)}.

%%% ---------------------------------------------------------------------------
%%% Resolving surface types into the algebra
%%% ---------------------------------------------------------------------------

type_env(Decls) ->
    Mod = module_name(Decls),
    Aliases = [{N, alias(Params, T)} || {type_alias, _, N, Params, T} <- Decls],
    Records = [{N, record_surface(Mod, L, N, Fs)}
               || {record_decl, L, N, Fs} <- Decls],
    Env = maps:merge(prelude(), maps:from_list(Aliases ++ Records)),
    %% The environment is HETEROGENEOUS after F6, and deliberately so. A ground
    %% entry is pre-resolved to an algebra type here, once; a parametric one
    %% cannot be — its body has free variables — so it stays a surface template
    %% and is resolved per use site, after substitution.
    maps:map(fun(_, {parametric, _, _} = P) -> P;
                (_, T) -> resolve(T, Env)
             end, Env).

alias([], Body)     -> Body;
alias(Params, Body) -> {parametric, Params, Body}.

%% Ticket 10 §5 and LANGUAGE.md §7 put these in the PRELUDE, and there is no
%% import system for a prelude file to arrive through — so they are held here,
%% spelled in the language's own alias mechanism rather than as a special case in
%% `resolve/2`. Lowercase because the prelude owns that namespace exactly as
%% `list` does; a user's own parametric alias is PascalCase like every other user
%% type, so the two cannot collide.
%%
%% This implements a decided prelude entry. It does not answer the map's
%% prelude-stratum fog: nothing here lets a user add to this map.
prelude() ->
    #{option => {parametric, ['T'],
                 {t_union, [{t_ref, 'T'}, {t_atom, nothing}]}},
      result => {parametric, ['T', 'E'],
                 {t_union, [{t_ref, 'T'},
                            {t_tuple, [{t_atom, error}, {t_ref, 'E'}]}]}}}.

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
%%
%% `Seen` is the chain of alias names this resolution has already entered, and it
%% exists because without it a cyclic alias does not error — it HANGS. Measured
%% on master before F6: `type A = B` / `type B = A` spins until killed. A hang is
%% invisible to a green suite, which is why the guard arrives with the feature
%% that makes recursive aliases the natural thing to write (`type Tree<T> =
%% (T, list<Tree<T>>)`), not with the feature that finally implements them.
resolve(T, Env) -> resolve(T, Env, []).

resolve(T, _Env, _Seen) when is_map(T) -> T;
resolve({t_atom, A}, _Env, _Seen)    -> bs_types:atom_lit(A);
%% A lowercase name is a builtin OR a prelude entry, and the two failure modes
%% read differently: `option` alone is not an unknown type, it is a known one
%% written without its bracket. Checked here rather than in `builtin/1` because
%% only the environment knows what the prelude holds.
resolve({t_builtin, B}, Env, _Seen) ->
    case maps:get(B, Env, undefined) of
        {parametric, Params, _} ->
            erlang:error({needs_type_args, B, length(Params)});
        _ -> builtin(B)
    end;
resolve({t_ref, N}, Env, Seen) ->
    seen(N, Seen),
    case maps:get(N, Env, undefined) of
        undefined -> erlang:error({unknown_type, N});
        {parametric, Params, _} ->
            erlang:error({needs_type_args, N, length(Params)});
        T when is_map(T) -> T;
        Surface -> resolve(Surface, Env, [N | Seen])
    end;
resolve({t_tuple, Cs}, Env, Seen) ->
    bs_types:tuple([resolve(C, Env, Seen) || C <- Cs]);
%% A DECLARED map type is closed — it fixes its domain. Ticket 26 §4's "no
%% absent fields" is what makes that sound, and §5 then closes row polymorphism
%% rather than deferring it: a wider record is simply a different type.
resolve({t_map, Fields}, Env, Seen) ->
    bs_types:map_closed(
      maps:from_list([{N, resolve(T, Env, Seen)} || {field, N, T} <- Fields]));
%% `list<T>` is algebra-primitive — the list part is a pair of flags, not an
%% alias body — so it is the one bracket that cannot be written as a prelude
%% alias and is resolved here.
resolve({t_generic, list, [T]}, Env, Seen) -> bs_types:list(resolve(T, Env, Seen));
resolve({t_generic, list, Args}, _Env, _Seen) ->
    erlang:error({generic_arity, list, 1, length(Args)});
%% Ticket 27 §(b), executable: substitute the ground arguments into the alias
%% body and resolve THAT. The variable is gone before `bs_types` sees anything,
%% which is why F6 adds no node to the algebra and no case to any operation on
%% it — and why `option<int>` and a hand-written `int | :nothing` are the same
%% type rather than two types that agree (F6.3).
resolve({t_generic, N, Args}, Env, Seen) ->
    seen(N, Seen),
    case maps:get(N, Env, undefined) of
        undefined -> erlang:error({unknown_generic, N});
        {parametric, Params, Body} when length(Params) =:= length(Args) ->
            %% Arguments are resolved in the CALLER's chain, not the callee's:
            %% they are siblings of this application, not steps below it.
            Sub = maps:from_list(
                    lists:zip(Params, [resolve(A, Env, Seen) || A <- Args])),
            resolve(subst(Body, Sub), Env, [N | Seen]);
        {parametric, Params, _} ->
            erlang:error({generic_arity, N, length(Params), length(Args)});
        _Ground ->
            erlang:error({not_parametric, N})
    end;
resolve({t_union, Ms}, Env, Seen) ->
    bs_types:union([resolve(M, Env, Seen) || M <- Ms]).

seen(N, Seen) ->
    case lists:member(N, Seen) of
        false -> ok;
        true  -> erlang:error({cyclic_type, N})
    end.

%% Substitution is over the SURFACE type, and what it substitutes IN is an
%% already-resolved algebra type — which `resolve/3`'s first clause then passes
%% straight through. So a parameter is replaced exactly once and never re-walked.
subst(T, _Sub) when is_map(T)      -> T;
subst({t_ref, N} = T, Sub)         -> maps:get(N, Sub, T);
subst({t_union, Ms}, Sub)          -> {t_union, [subst(M, Sub) || M <- Ms]};
subst({t_tuple, Cs}, Sub)          -> {t_tuple, [subst(C, Sub) || C <- Cs]};
subst({t_generic, N, Args}, Sub)   -> {t_generic, N, [subst(A, Sub) || A <- Args]};
subst({t_map, Fields}, Sub) ->
    {t_map, [{field, N, subst(T, Sub)} || {field, N, T} <- Fields]};
subst(T, _Sub)                     -> T.

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

check_fn(F = #fn{name = Name, line = Line, params = Params, ret = Ret}, Ctx0) ->
    Env = Ctx0#ctx.types,
    %% The argument list is treated as a product, so exhaustiveness across all
    %% parameters is one subtraction rather than one per column. This is the
    %% cross-clause part of ticket 04: a clause need not be redundant in any
    %% single column to be redundant overall.
    Declared = bs_types:tuple([resolve(T, Env) || {param, T, _} <- Params]),
    Ctx = Ctx0#ctx{ret = resolve(Ret, Env), fname = Name, arity = length(Params)},
    case F#fn.clauses of
        [] ->
            {F, [{error, Line, Name, no_clauses}]};
        Clauses ->
            {Residual, Diags} = walk(Clauses, Declared, Ctx, [], 1),
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

scope_diags({clause, Line, Name, Patterns, Guard, Body}) ->
    Bound = lists:append([pattern_vars(P) || P <- Patterns]),
    %% A guard is read in the scope of the CLAUSE HEAD alone — bindings come
    %% after it. Scanned here because F4's rule is that an unbound name is a
    %% `bsc` error, and a guard was the one place it still reached `erlc` as
    %% `variable 'X' is unbound` against a file the author did not write.
    guard_scope(Guard, Bound, Line, Name) ++ check_scope(Body, Bound, Name, Line, []).

guard_scope(none, _Bound, _Line, _Name)        -> [];
guard_scope({guard, G}, Bound, Line, Name)     -> name_diags(G, Bound, Line, Name, []).

check_scope({e_block, _, Binds, Final}, Bound0, Name, Line, Acc0) ->
    {Bound, Acc} =
        lists:foldl(
          fun({bind, L, V, E}, {B, A}) ->
                  bind_names(E, [V], B, L, Name, A);
             %% A destructuring bind names everything its pattern names, and
             %% every one of them obeys the same no-shadowing rule.
             ({dbind, L, P, E}, {B, A}) ->
                  bind_names(E, pattern_vars(P), B, L, Name, A)
          end, {Bound0, Acc0}, Binds),
    %% The final expression carries no line of its own — the parser keeps one
    %% per binding and one per clause — so an unbound name in it is reported
    %% against the clause, which is the smallest span that is certainly right.
    name_diags(Final, Bound, Line, Name, Acc);
check_scope(Final, Bound, Name, Line, Acc) ->
    name_diags(Final, Bound, Line, Name, Acc).

%% One binding: its right-hand side is read in the scope BEFORE it, and the
%% names it introduces may not already be bound.
bind_names(Expr, Vars, Bound, Line, Name, Acc) ->
    Acc1 = name_diags(Expr, Bound, Line, Name, Acc),
    lists:foldl(
      fun(V, {B, A}) ->
              case lists:member(V, B) of
                  true  -> {B, [{error, Line, Name, {rebinding, V}} | A]};
                  false -> {[V | B], A}
              end
      end, {Bound, Acc1}, Vars).

%% The two name questions an expression can answer wrongly, asked together
%% because they are asked at the same points and against the same running scope.
%% F7 is what made the second one necessary: until a switch arm existed, the only
%% thing that introduced a name mid-expression was a binding, and `bind_names/6`
%% above already had it.
name_diags(Expr, Bound, Line, Name, Acc) ->
    [{error, Line, Name, {unbound_variable, V}}
     || V <- lists:usort(expr_vars(Expr)), not lists:member(V, Bound)]
        ++ rebinds(Expr, Bound, Name) ++ Acc.

%% A switch arm may not rebind a name already in scope, and this is a stronger
%% rule than ticket 34's applied evenly. In Erlang a `case` arm pattern naming an
%% already-bound variable is not a binding at all — it is an EQUALITY TEST
%% against the existing value. So accepting it would emit a silently different
%% program from the one that reads like a fresh binding, with no diagnostic
%% anywhere. Refusing it is what keeps the surface honest.
%%
%% Generic below the switch case, for `wildcards/1`'s reason: a switch can sit
%% anywhere an expression can, and enumerating the grammar a fourth time to find
%% one node would be a fourth copy of the same walk.
rebinds({e_switch, _, Subject, Arms}, Bound, Name) ->
    rebinds(Subject, Bound, Name)
        ++ lists:append([arm_rebinds(A, Bound, Name) || A <- Arms]);
rebinds(T, Bound, Name) when is_tuple(T) -> rebinds(tuple_to_list(T), Bound, Name);
rebinds(L, Bound, Name) when is_list(L) ->
    lists:append([rebinds(E, Bound, Name) || E <- L]);
rebinds(_, _, _) -> [].

arm_rebinds({arm, Line, P, Guard, Body}, Bound, Name) ->
    Vars = pattern_vars(P),
    Inner = Bound ++ Vars,
    [{error, Line, Name, {rebinding, V}}
     || V <- lists:usort(Vars), lists:member(V, Bound)]
        ++ rebinds(Body, Inner, Name)
        ++ case Guard of none -> []; {guard, G} -> rebinds(G, Inner, Name) end.

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
    lists:append([expr_vars(element(4, B)) || B <- Binds]) ++ expr_vars(Final);
%% An arm's pattern names are readable in THAT ARM and nowhere else, so the
%% subtraction is per-arm and not per-switch. Getting this wrong in either
%% direction is silent: subtract nothing and a name the arm itself bound is
%% reported unbound; subtract the whole switch's names and a genuine typo in one
%% arm is covered by a sibling arm that happens to bind the same name.
expr_vars({e_switch, _, Subject, Arms}) ->
    expr_vars(Subject) ++ lists:append([arm_free_vars(A) || A <- Arms]);
expr_vars(_)                           -> [].

arm_free_vars({arm, _, P, Guard, Body}) ->
    Bound = pattern_vars(P),
    Read = case Guard of none -> []; {guard, G} -> expr_vars(G) end ++ expr_vars(Body),
    [V || V <- Read, not lists:member(V, Bound)].

%%% ---------------------------------------------------------------------------
%%% The body check — ticket 33, F5.
%%%
%%% Two halves, and conflating them is what made ticket 33's own sub-question 1
%%% the wrong cut:
%%%
%%%   SYNTHESIS  — every expression gets a type. Total over the twelve forms,
%%%                unavoidable, and nothing in it is inferred: every
%%%                non-structural form reads a type some other declaration
%%%                already wrote down, which is ticket 04's mandatory signature
%%%                paying for a second thing it was not bought for.
%%%
%%%   OBLIGATION — where containment is CHECKED. Five sites, every one of them a
%%%                place a type was already declared: call argument,
%%%                construction, projection, clause return, destructuring bind.
%%%                There is no sixth site because there is no sixth place a type
%%%                is written — `e_op`, `e_tuple`, `e_list` and `e_block`
%%%                declare nothing, so they synthesise and never check.
%%%
%%% Four of the five hand back a residual the existing printer renders as a
%%% clause head. Construction is the exception and is honest about it: two
%%% closed maps over different key sets are simply disjoint, so the subtraction
%%% names the type you were building rather than the field you forgot, and the
%%% residual there is field NAMES (see field_delta/2).
%%% ---------------------------------------------------------------------------

clause_diags(C = {clause, Line, _, Patterns, Guard, Body}, Domain, Bindings, Ctx0) ->
    guard_diags(Guard, Ctx0) ++
    case scope_diags(C) of
        [] ->
            Ctx = Ctx0#ctx{binds = Bindings},
            Scope = clause_scope(Patterns, Bindings, Domain),
            {Ty, Diags} = type_of(Body, Scope, Ctx),
            Diags ++ return_diags(Ty, Line, Ctx);
        Errors ->
            %% A clause whose names do not resolve is not typed. Every unbound
            %% name would answer `term`, and `term` fails most containments — so
            %% the author would meet a pile of type errors about a typo.
            Errors
    end.

%% A guard is not typed — ticket 33 enumerated five sites and a guard is not one
%% of them — but `_` in a guard is the same authoring mistake as `_` in a body,
%% and it is a hole F5's OWN grammar opened: before `_` was an expression this
%% did not parse. Left alone it reaches `bs_emit:expr/2` as a function-clause
%% CRASH, which is worse than the `erlc` error F4.7 exists to prevent.
%%
%% Scanned syntactically rather than typed, which is all the question needs.
%%
%% A switch in a guard is the same hole in a second costume, and F7 opened it the
%% same way F5 opened the first: a guard shares the whole expression grammar, so
%% `when x switch { … }` parses the moment the production exists. Erlang's guards
%% are a restricted sublanguage with no `case` in them, so left alone this reaches
%% the author as `illegal guard expression` from `erlc`, against the `.abstr` file
%% they did not write — which is exactly what F4.7's rule exists to prevent.
guard_diags(none, _Ctx) -> [];
guard_diags({guard, Expr}, C) ->
    [{error, L, C#ctx.fname, wildcard_as_value} || L <- wildcards(Expr)]
        ++ [{error, L, C#ctx.fname, switch_in_guard} || L <- switches(Expr)].

%% Generic, because a guard shares the whole expression grammar and enumerating
%% it a third time to find one node would be three copies of the same walk.
wildcards({e_wild, L})           -> [L];
wildcards(T) when is_tuple(T)    -> wildcards(tuple_to_list(T));
wildcards(L) when is_list(L)     -> lists:append([wildcards(E) || E <- L]);
wildcards(_)                     -> [].

%% The same walk, and it stops AT a switch rather than descending through it:
%% one error per guard is what the author needs, and a switch nested inside a
%% refused switch is not a second mistake.
switches({e_switch, L, _, _})    -> [L];
switches(T) when is_tuple(T)     -> switches(tuple_to_list(T));
switches(L) when is_list(L)      -> lists:append([switches(E) || E <- L]);
switches(_)                      -> [].

%% SITE 4 — the clause return. Not in ticket 33's table of what was waiting, and
%% forced by ticket 18's own criticism of Gleam: 13 emits a `-spec` for every
%% function, and 18 measured Gleam trusting an `@external` and publishing the
%% false claim as a `-spec`. Without this, beam-sharp publishes exactly the same
%% unverified claim from its own bodies.
return_diags(Ty, Line, #ctx{ret = Ret, fname = Name}) ->
    case bs_types:subtract(Ty, Ret) of
        R ->
            case bs_types:is_none(R) of
                true  -> [];
                false -> [{error, Line, Name, {return_not_declared, R}}]
            end
    end.

%% A body variable's type is read off the clause's REFINED DOMAIN at the path
%% the pattern recorded — never off the pattern itself, which answers `term` for
%% a bare variable and would fail every call site in the corpus.
clause_scope(Patterns, Bindings, Domain) ->
    Named = lists:append([pattern_vars(P) || P <- Patterns]),
    maps:from_list([{V, var_type(V, Bindings, Domain)} || V <- Named]).

var_type(V, Bindings, Domain) ->
    case maps:get(V, Bindings, undefined) of
        %% A variable nested inside a list item is named but not addressable.
        %% `term` is the truthful answer and it is an over-approximation, so it
        %% is sound and merely imprecise.
        undefined -> bs_types:term();
        no_path   -> bs_types:term();
        Path      -> at_path(Domain, Path)
    end.

%% The read-only twin of refine_at/3. It UNIONS across the alternatives at each
%% step rather than indexing one, because the domain's tuple part is a list of
%% products and its map part a list of members — an earlier clause narrowing to
%% a union is the ordinary case, not the exotic one.
at_path(Ty, []) -> Ty;
at_path(#{tuples := top}, [I | _]) when is_integer(I) -> bs_types:term();
at_path(#{tuples := Products}, [I | Rest]) when is_integer(I) ->
    at_path(union_of([lists:nth(I, P) || P <- Products, length(P) >= I]), Rest);
at_path(#{maps := top}, [{field, _} | _]) -> bs_types:term();
at_path(#{maps := Members}, [{field, K} | Rest]) ->
    at_path(union_of([maps:get(K, Fs) || {_, Fs} <- Members, maps:is_key(K, Fs)]), Rest);
at_path(Ty, [{elem} | Rest]) ->
    at_path(elem_of(Ty), Rest);
%% The tail of a non-empty list is a list over the same elements — including the
%% empty one, since `[x, ..t]` says nothing about how long the tail is.
at_path(Ty, [{tail} | Rest]) ->
    at_path(bs_types:list(elem_of(Ty)), Rest).

elem_of(#{lists := {_, none}}) -> bs_types:none();
elem_of(#{lists := {_, any}})  -> bs_types:term();
elem_of(#{lists := {_, E}})    -> E.

union_of([]) -> bs_types:none();
union_of(Ts) -> bs_types:union(Ts).

%%% --- synthesis, and the checks that hang off it ----------------------------

%% Returns {Type, Diags}. Checking happens DURING synthesis rather than in a
%% pass after it, because an argument's type is only known by synthesising it
%% and a nested call is the ordinary case.
type_of({e_int, _, N}, _S, _C)  -> {bs_types:range(N, N), []};
type_of({e_atom, _, A}, _S, _C) -> {bs_types:atom_lit(A), []};
type_of({e_var, _, V}, S, _C)   -> {maps:get(V, S, bs_types:term()), []};
%% `_` is an expression only so that `(a, _) = pair` parses — see the parser.
%% Used as a VALUE it is rejected here, so the author does not meet
%% `variable '_' is unbound` from `erlc` against a file they did not write.
type_of({e_wild, L}, _S, C) ->
    {reported(), [{error, L, C#ctx.fname, wildcard_as_value}]};
type_of({e_tuple, _, Es}, S, C) ->
    {Tys, D} = type_of_all(Es, S, C),
    {bs_types:tuple(Tys), D};
%% Ticket 16 §2. `e_op` declares nothing, so it synthesises and never checks —
%% and `1 + 2` is `int`, not `range(3,3)`: exact interval arithmetic is F2's.
type_of({e_op, _, Op, A, B}, S, C) ->
    {_, D1} = type_of(A, S, C),
    {_, D2} = type_of(B, S, C),
    {op_type(Op), D1 ++ D2};
type_of({e_nil, _}, _S, _C) -> {bs_types:nil(), []};
type_of({e_list, _, Items, Rest}, S, C) ->
    {Tys, D1} = type_of_all(Items, S, C),
    {RestElem, D2} =
        case Rest of
            nil -> {bs_types:none(), []};
            R   -> {RT, RD} = type_of(R, S, C), {elem_of(RT), RD}
        end,
    {bs_types:cons(union_of(Tys ++ [RestElem])), D1 ++ D2};
type_of({e_block, _, Binds, Final}, S, C) ->
    {S1, D1} = lists:foldl(fun(B, Acc) -> bind_step(B, Acc, C) end, {S, []}, Binds),
    {T, D2} = type_of(Final, S1, C),
    {T, D1 ++ D2};
%% SITE 3 — projection. Legal exactly where every member of the receiver's type
%% carries the field, and the residual IS the member that lacks it, which is the
%% sentence F3.8 deferred: the tag to discriminate on.
type_of({e_proj, L, V, Field}, S, C) ->
    Recv = maps:get(V, S, bs_types:term()),
    Lacking = bs_types:subtract(Recv, bs_types:map_open(#{Field => bs_types:term()})),
    case bs_types:is_none(Lacking) of
        true  -> {field_type(Recv, Field), []};
        false -> {reported(),
                  [{error, L, C#ctx.fname, {field_absent, Field, Lacking}}]}
    end;
%% SITE 2 — construction. F3 shipped without this and said so: a body could
%% build a map wearing an `Order` tag without `Order`'s fields and nothing
%% rejected it.
type_of({e_record, L, Name, Fields}, S, C) ->
    {_, D} = type_of_all([E || {_, E} <- Fields], S, C),
    case maps:get(Name, C#ctx.types, undefined) of
        undefined ->
            {reported(), [{error, L, C#ctx.fname, {unknown_record, Name}} | D]};
        Ty ->
            case declared_fields(Ty) of
                unknown -> {Ty, D};
                Declared ->
                    case field_delta([K || {K, _} <- Fields], Declared) of
                        {[], []} -> {Ty, D};
                        {Missing, Extra} ->
                            {Ty, [{error, L, C#ctx.fname,
                                   {field_set_mismatch, Name, Missing, Extra}} | D]}
                    end
            end
    end;
%% `with` is width-preserving (ticket 26 §2), so the base's type passes through
%% unchanged. The assigned VALUES are not checked: that would be a sixth site,
%% and ticket 33 enumerated five.
type_of({e_with, _, Base, Fields}, S, C) ->
    {T, D1} = type_of(Base, S, C),
    {_, D2} = type_of_all([E || {_, E} <- Fields], S, C),
    {T, D1 ++ D2};
%% Ticket 17 §6 — `walk/5` over ONE COLUMN. A clause row's domain is a product of
%% declared parameter types and a switch's is a single synthesised type, and that
%% is the whole of the difference: the same `pattern_type/3`, the same
%% `apply_guard/3`, the same `Certain`/`Possible` split, the same residual.
%%
%% A switch DECLARES nothing, so it opens no sixth site — ticket 33 enumerated
%% five and F7 adds none. It synthesises the union of its arms, which is what
%% makes site 4 (the clause return) reachable from a place it could not be
%% reached from before.
type_of({e_switch, L, Subject, Arms}, S, C) ->
    {SubjTy, D0} = type_of(Subject, S, C),
    {Tys, Residual, D1} = arms(Arms, SubjTy, S, C, 1, [], []),
    D2 = case bs_types:is_none(Residual) of
             true  -> [];
             %% The residual IS the missing arm — ticket 04's finding at a third
             %% site, and it needs no new printer: `to_pattern/1` already renders
             %% a tuple as `(a, b, c)` and a record union as its discriminator.
             false -> [{error, L, C#ctx.fname, {switch_inexhaustive, Residual}}]
         end,
    {union_of(Tys), D0 ++ D1 ++ D2};
type_of({e_call, L, Name, Args}, S, C) ->
    call(L, Name, Name, Args, S, C);
%% Ticket 32 dissolved the foreign case before it was asked: a foreign
%% declaration is a signature attached to the name Erlang already has, so site 1
%% applies verbatim.
type_of({e_foreign_call, L, Mod, Fun, Args}, S, C) ->
    call(L, {Mod, Fun}, foreign_name(Mod, Fun), Args, S, C);
type_of(_, _S, _C) ->
    {bs_types:term(), []}.

%% The type of an expression that has ALREADY produced a diagnostic. `none` is a
%% subtype of everything, so every site above it passes vacuously and the author
%% gets one error rather than a cascade — a failed projection would otherwise
%% also fail the clause's return check and name a type nobody wrote.
reported() -> bs_types:none().

type_of_all(Es, S, C) ->
    {Tys, Ds} = lists:unzip([type_of(E, S, C) || E <- Es]),
    {Tys, lists:append(Ds)}.

%% One arm at a time against a running residual, which is `walk/5`'s shape and
%% for `walk/5`'s reason: redundancy is RELATIVE — arm i against the arms before
%% it — so it is judged against what is left rather than against the subject.
arms([], Residual, _S, _C, _N, Tys, Diags) ->
    {Tys, Residual, Diags};
arms([{arm, AL, P, Guard, Body} | Rest], Residual, S, C, N, Tys, Diags) ->
    {PTy, Binds, Exact} = pattern_type(P, [], C#ctx.types),
    {Certain0, Possible} = apply_guard(PTy, Binds, Guard),
    %% An inexact pattern over-states what it matches, so it may bound Possible
    %% and must credit nothing to Certain. Identical to `clause_type/2`, and for
    %% the identical reason: crediting an over-estimate is what makes a compiler
    %% claim coverage it does not have.
    Certain = case Exact of true -> Certain0; false -> bs_types:none() end,
    D1 = case bs_types:is_none(bs_types:intersect(Possible, Residual)) of
             true  -> [{warning, AL, C#ctx.fname, {unreachable_arm, N}}];
             false -> []
         end,
    %% `Possible`, never `Certain` — F5.7's trap, at a second site and with the
    %% same failure mode. `Certain` is `none` under an untranslatable guard, and
    %% a body typed against `none` does not fail loudly: every containment over
    %% `none` passes, so the arm silently stops being checked.
    Domain = bs_types:intersect(Residual, Possible),
    %% An arm variable's type is read off the refined domain at the path the
    %% pattern recorded, exactly as a clause's is — the paths simply start at `[]`
    %% here, because a switch has one subject where a clause head has a product.
    Scope = maps:merge(S, maps:from_list(
                            [{V, at_path(Domain, Path)}
                             || {V, Path} <- maps:to_list(Binds)])),
    {BodyTy, D2} = type_of(Body, Scope, C),
    arms(Rest, bs_types:subtract(Residual, Certain), S, C, N + 1,
         Tys ++ [BodyTy], Diags ++ D1 ++ guard_diags(Guard, C) ++ D2).

op_type('+') -> bs_types:int();
op_type('-') -> bs_types:int();
op_type('*') -> bs_types:int();
op_type(_)   -> bs_types:union(bs_types:atom_lit(true), bs_types:atom_lit(false)).

%% A binding declares no type, so it is synthesis only — there is no site here.
bind_step({bind, _, V, E}, {S, D}, C) ->
    {T, D1} = type_of(E, S, C),
    {S#{V => T}, D ++ D1};
%% SITE 5 — the destructuring bind ticket 34 deferred here rather than refusing.
%% Provably irrefutable IFF the residual is empty, which is the mechanism 34
%% named and 33 routed to this feature.
bind_step({dbind, L, P, E}, {S, D}, C) ->
    {T, D1} = type_of(E, S, C),
    {PTy, PBinds, Exact} = pattern_type(P, [], C#ctx.types),
    Residual = bs_types:subtract(T, PTy),
    D2 = case {Exact, bs_types:is_none(Residual)} of
             {true, true}  -> [];
             {_, false}    -> [{error, L, C#ctx.fname, {bind_may_fail, Residual}}];
             %% An inexact pattern OVER-states what it matches, so its residual
             %% under-states what is left. The bind is refutable and the honest
             %% residual is the whole right-hand side.
             {false, true} -> [{error, L, C#ctx.fname, {bind_may_fail, T}}]
         end,
    Bound = maps:from_list([{V, at_path(T, Path)} || {V, Path} <- maps:to_list(PBinds)]),
    {maps:merge(S, Bound), D ++ D1 ++ D2}.

%% SITE 1 — the call argument, and ticket 26 §1's requirement David named:
%% reject `Update(Order o)` called with an `Invoice`.
call(L, Key, Shown, Args, S, C) ->
    {ATys, D} = type_of_all(Args, S, C),
    case maps:get(Key, C#ctx.callees, undefined) of
        undefined ->
            {reported(),
             [{error, L, C#ctx.fname, {unknown_callee, Shown, length(Args)}} | D]};
        {Ps, Ret} when length(Ps) =/= length(ATys) ->
            {Ret, [{error, L, C#ctx.fname,
                    {arity_mismatch, Shown, length(ATys), length(Ps)}} | D]};
        {Ps, Ret} ->
            {Ret, arg_diags(L, Shown, Args, ATys, Ps, 1, C) ++ D}
    end.

arg_diags(_L, _Callee, [], [], [], _I, _C) -> [];
arg_diags(L, Callee, [A | As], [T | Ts], [P | Ps], I, C) ->
    Rest = arg_diags(L, Callee, As, Ts, Ps, I + 1, C),
    case bs_types:subtract(T, P) of
        R ->
            case bs_types:is_none(R) of
                true  -> Rest;
                %% The residual is the clause the CALLER must write — ticket 04's
                %% guarantee at a second site. It proposes an edit to the function
                %% being checked and never to the callee, which is ticket 18 §4's
                %% function-local rule showing up in a diagnostic.
                false -> [{error, L, C#ctx.fname,
                           {arg_not_accepted, Callee, I, R, head_hint(A, C)}} | Rest]
            end
    end.

%% A head can only be synthesised when the argument IS a whole parameter; an
%% arbitrary expression has no position in the caller's head to put a pattern in.
head_hint({e_var, _, V}, #ctx{binds = B, arity = N}) ->
    case maps:get(V, B, undefined) of
        [I] when is_integer(I) -> {I, N};
        _                      -> none
    end;
head_hint(_, _) -> none.

foreign_name(Mod, Fun) ->
    list_to_atom(":" ++ atom_to_list(Mod) ++ "." ++ atom_to_list(Fun)).

%% Site 2's residual is field NAMES, not a type — ticket 33 §4. `Order{Id} \
%% Order` is `{ Kind: :'Shop.Order' }`: correct, and worthless, because it names
%% the type you were building rather than the field you forgot.
field_delta(Supplied, Declared) ->
    {lists:sort(Declared -- Supplied), lists:sort(Supplied -- Declared)}.

%% The declared field set, read off the RESOLVED type rather than the surface
%% one `record_fields/1` reads for the emitter. `Kind` is minted, never assigned.
declared_fields(#{maps := [{closed, Fs}]}) -> maps:keys(Fs) -- ['Kind'];
declared_fields(_)                         -> unknown.

field_type(#{maps := top}, _Field) -> bs_types:term();
field_type(#{maps := Members}, Field) ->
    union_of([maps:get(Field, Fs) || {_, Fs} <- Members, maps:is_key(Field, Fs)]).

walk([], Residual, _Ctx, Diags, _N) ->
    {Residual, lists:reverse(Diags)};
walk([C = {clause, CLine, Name, _, _, _} | Rest], Residual, Ctx, Diags, N) ->
    Env = Ctx#ctx.types,
    %% Two bounds, and conflating them is a soundness bug rather than an
    %% imprecision. `Certain` is what the clause is *guaranteed* to match, and is
    %% the only thing that may be subtracted from the residual — an over-estimate
    %% there makes the compiler claim coverage it does not have. `Possible` is
    %% what the clause *could* match, and is what redundancy is judged against —
    %% an under-estimate there would call a live clause dead.
    %%
    %% They differ exactly when a guard is not translatable to a type operation.
    {Certain, Possible, Bindings} = clause_type(C, Env),
    %% Redundancy is *relative* — clause i against the clauses before it — which
    %% is why it is checked against the running residual rather than the declared
    %% type. Ticket 04 drew that distinction and it falls straight out here.
    Diags1 =
        case bs_types:is_none(bs_types:intersect(Possible, Residual)) of
            true  -> [{warning, CLine, Name, {unreachable_clause, N}} | Diags];
            false -> Diags
        end,
    %% THE BODY CHECK — ticket 33, and the whole of why walk/5 changed. The
    %% domain is the running residual intersected with `Possible`, which is a
    %% value this function already computed and threw away, so this is not a
    %% second pass over the AST.
    %%
    %% `Possible`, never `Certain`: an untranslatable guard makes `Certain`
    %% `none`, and a body typed against `none` does not fail loudly — every
    %% containment over `none` passes, so the check silently stops checking.
    %% That is the failure mode that ships.
    Domain = bs_types:intersect(Residual, Possible),
    Diags2 = clause_diags(C, Domain, Bindings, Ctx) ++ Diags1,
    walk(Rest, bs_types:subtract(Residual, Certain), Ctx, Diags2, N + 1).

%%% ---------------------------------------------------------------------------
%%% What a clause matches
%%% ---------------------------------------------------------------------------

%% Returns {Certain, Possible, Bindings} — see walk/5 for why both bounds are
%% needed. The bindings come back out because the body check reads each
%% variable's type off the domain at the path recorded here, rather than off its
%% pattern: a bare `p_var` is `term`, and typing a body from its patterns fails
%% every call site in the corpus (ticket 33 §5).
clause_type({clause, _, _, Patterns, Guard, _}, Env) ->
    {Components, Bindings, Exact} = pattern_row(Patterns, Env),
    Base = bs_types:tuple(Components),
    {Certain, Possible} = apply_guard(Base, Bindings, Guard),
    case Exact of
        true  -> {Certain, Possible, Bindings};
        %% An inexact pattern over-states what it matches — `[0, ..t]` is not
        %% every non-empty list — so it may bound Possible but must credit
        %% NOTHING to Certain. Same rule as an untranslatable guard, and the same
        %% reason: crediting an over-estimate is what makes a compiler claim
        %% coverage it does not have.
        false -> {bs_types:none(), Possible, Bindings}
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
pattern_type({p_list, _, Items, Rest}, Path, _Env) ->
    %% `[h, ..t]` matches every non-empty list; `[0, ..t]` matches only some, so
    %% it is an upper bound and credits nothing.
    Exact = lists:all(fun open_pattern/1, Items) andalso open_pattern(Rest),
    Binds = lists:foldl(fun maps:merge/2, #{},
                        [binding(P, Path ++ [{elem}]) || P <- Items]
                        ++ [binding(Rest, Path ++ [{tail}])]),
    {bs_types:cons(bs_types:term()), Binds, Exact}.

open_pattern({p_var, _, _}) -> true;
open_pattern({p_wild, _})   -> true;
open_pattern(_)             -> false.

%% A list element's address. It is a REAL path — F5 needs to read `rest` back
%% out of `Reverse([x, ..rest], acc)` and answer `list<int>`, and answering
%% `term` there rejects a shipped example with a checker that is working
%% correctly on wrong information.
%%
%% A guard over one is still not refinable: `refine_all/3` rejects any path
%% carrying a list step, which is exactly what it did with `no_path` before.
%% Reading a component and refining one are different capabilities over the same
%% address, and the list part of the algebra supports the first and not the
%% second.
binding({p_var, _, V}, Path) -> #{V => Path};
binding(_, _)                -> #{}.

list_step({elem}) -> true;
list_step({tail}) -> true;
list_step(_)      -> false.

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
                  Path      ->
                      %% A path through a list element is unrefinable for the
                      %% same reason `no_path` was: `refine_at/3` cannot address
                      %% one. Kept identical rather than improved, so F5's
                      %% readable paths change nothing a guard credits.
                      case lists:any(fun list_step/1, Path) of
                          true  -> none_marker;
                          false -> refine_at(Acc, Path, C)
                      end
              end;
         (unknown, Acc) -> Acc
      end, Ty, Constraints).

%% THE WHOLE VALUE, which is what a switch arm refines. `at_path/2` has had this
%% clause since F5 and its refining twin never needed one, because a clause-head
%% path always begins with a parameter index and so is never empty. A switch
%% subject is one value, so `n switch { m when m > 0 => … }` is the first thing
%% ever to ask for it — and without this clause it does not report anything, it
%% leaves the checker through a `function_clause`.
refine_at(Ty, [], C) ->
    apply_constraint(Ty, C);
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
