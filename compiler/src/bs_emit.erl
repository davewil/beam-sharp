%%% bs_emit — lowers a checked B# module to Erlang Abstract Format forms, and
%%% `to_abstr/1` serialises them to the `.abstr` text `erlc +from_abstr` reads.
%%%
%%% The output is plain terms and nothing else: the frontend never depends on
%%% in-process compiler state, so the host language is free (ticket 13). The
%%% Abstract Format was chosen over Core Erlang because `.abstr -> Core` is
%%% free and the reverse is unrecoverable.
%%%
%%% Every function gets a `-spec`, widened to the nearest Erlang-expressible
%%% supertype where the set-theoretic type has no spelling; `spec_type/1` is
%%% that widening. The widening is visible to Dialyzer's `-Wspecdiffs` only,
%%% never `-Wunderspecs`: every emitted spec has a domain narrower than the
%%% success typing and a range that may be wider, which Dialyzer classifies as
%%% "not equal" rather than as an underspec.
%%%
%%% Nothing is emitted for the failure arm: `erlc` inserts the `match_fail`
%%% clause itself and it cannot be suppressed, so the honest crash comes free
%%% (tickets 12, 13).

-module(bs_emit).

-export([forms/1, to_abstr/1]).

-define(A, 0).

%%% ---------------------------------------------------------------------------
%%% Naming.
%%%
%%% A module or function name is preserved exactly and quoted: `Readings`
%%% emits module `'Readings'` with function `'Classify'`, called from Erlang
%%% as `'Readings':'Classify'(X)`. This is provisional; the module and
%%% namespace question is still open (ticket 10 §3), and the lossless spelling
%%% pre-empts it least.
%%% ---------------------------------------------------------------------------

forms(Module = #{module := Mod, functions := Fns, env := Env}) ->
    %% A private function is emitted and `-spec`'d like a public one; it is
    %% simply left out of the export list, the BEAM's only mechanism for the
    %% distinction (F12, ticket 40 §3).
    Exports = [{F, arity(F)} || F <- Fns, is_public(F)],
    Behaviours = maps:get(behaviours, Module, []),
    %% Whether `HandleCall/3` lowers to `handle_call/3` depends on what the
    %% module declares, so the behaviours travel in the context (ticket 35).
    %% The validator table is built once per module and consulted at every
    %% call site, so two `ValidateAs<Order>` share one generated function
    %% (F18).
    Validators = validator_table(Fns, Env),
    %% The foreign-wrapper counter is reset per module, so the emitted forms do
    %% not depend on what this OS process emitted before them (F19).
    reset_foreign_wrappers(),
    Ctx = #{module => Mod, env => Env, behaviours => Behaviours,
            imports => maps:get(imports, Module, #{}),
            qmods => maps:get(qmods, Module, #{}),
            validators => Validators,
            remote_names => maps:get(remote_names, Module, #{}),
            %% Which foreign calls are owed a `try` is decided in `bs_check`,
            %% where the declaration is, and only looked up here.
            foreigns => maps:get(foreigns, Module, #{})},
    %% A crash names the `.bs` file the function was written in. A module is a
    %% directory, so one `.beam` holds functions from several files, and a
    %% repeated `{attribute, _, file, {Name, Line}}` re-points every form after
    %% it. The tuple's line names the file only; each form's own annotation
    %% supplies its line, so the numbers are exact (F15, ticket 13 §3).
    Files = maps:get(files, Module, [{undefined, Fns}]),
    [{attribute, ?A, module, Mod},
     {attribute, ?A, export, [{name(F, Behaviours), A} || {F, A} <- Exports]}]
    ++ [{attribute, ?A, behaviour, bs_otp:behaviour_name(B)} || B <- Behaviours]
    %% Recursive `-type` declarations precede the specs that refer to them, so
    %% a reader meets the definition first; Erlang does not care (F28).
    ++ rec_type_attrs(Fns, Env)
    ++ lists:append([file_group(Path, Fs, Env, Behaviours, Ctx)
                     || {Path, Fs} <- Files])
    %% Generated code goes last and carries no `file` attribute: it belongs to
    %% no `.bs`, and pointing it at one would misattribute the next crash.
    %% The validators cannot crash anyway, since every branch returns a value.
    ++ validator_forms(Validators)
    ++ reserved_forms(Fns).

%% `undefined` is the one-source callers (`compile_string/2`, the REPL) that
%% have no path to attribute to; no attribute is emitted for them.
file_group(undefined, Fns, Env, Behaviours, Ctx) ->
    lists:append([[spec_attr(F, Env, Behaviours), function(F, Ctx)] || F <- Fns]);
file_group(Path, Fns, Env, Behaviours, Ctx) ->
    [{attribute, ?A, file, {Path, 1}}
     | lists:append([[spec_attr(F, Env, Behaviours), function(F, Ctx)]
                     || F <- Fns])].

%% The one place a B# function name becomes an Erlang one. The export list,
%% the `-spec`, the definition and every local call go through it, so they
%% cannot disagree and export a name nothing defines (ticket 35).
name(F, Behaviours) -> emitted_name(element(2, F), arity(F), Behaviours).

%% The one place a cross-module call is built. The callee's emitted name comes
%% from the callee's own contract, recorded by `bs_check`; the written name is
%% the fallback for a module that declares no behaviour.
remote(L, Mod0, Fn, As, C) ->
    %% A short namespace name becomes the full dotted path through the table
    %% the checker built; a second resolver here could disagree silently, as
    %% a wrong module atom is `undef` at run time rather than a type error.
    Mod = maps:get(Mod0, maps:get(qmods, C, #{}), Mod0),
    Name = maps:get({Mod, Fn, length(As)}, maps:get(remote_names, C, #{}), Fn),
    {call, L, {remote, L, {atom, L, Mod}, {atom, L, Name}},
     [expr(A, C) || A <- As]}.

emitted_name(Name, Arity, Behaviours) ->
    case bs_otp:callback_name(Name, Arity, Behaviours) of
        none -> Name;
        Otp  -> Otp
    end.

arity(F) -> length(element(5, F)).              % length(#fn.params)
%% Private is the default, so the test is `=:= public` and not `=/= private`;
%% the other spelling would export every unmarked function (F12).
is_public(F) -> element(7, F) =:= public.       % #fn.vis

%%% ---------------------------------------------------------------------------
%%% Functions and clauses
%%%
%%% N clause heads in the parameter position become N native Erlang clause
%%% heads; this is the one structural move the language rests on (ticket 01).
%%% ---------------------------------------------------------------------------

function(F, Ctx) ->
    Name = name(F, maps:get(behaviours, Ctx, [])),
    Arity = arity(F),
    Params = element(5, F),                     % #fn.params
    Clauses = element(6, F),                    % #fn.clauses
    %% The kind test is emitted on exported functions only, so visibility is
    %% read here, the one place the `#fn` record is in scope, and handed to
    %% the clause as a boolean (F24, ticket 18 §4).
    Public = is_public(F),
    {function, ?A, Name, Arity, [clause(C, Params, Ctx, Public) || C <- Clauses]}.

%% A parameter the body and guard never mention lowers to a `_`-prefixed
%% variable, because Erlang warns on an unused one and `(:ok, n) -> :negative`
%% is idiomatic B#, with the name as documentation.
clause({clause, Line, _Name, Patterns, Guard, Body}, Params, Ctx, Public) ->
    %% Desugaring runs first and relational patterns are stripped second, both
    %% before the boundary guard. `ensure_var/3` wraps a pattern it cannot
    %% name in a `p_alias`, and an aliased `p_rel` or `p_rec` would reach
    %% `pattern/2`, which has no clause for either; stripping first means the
    %% guard only ever sees a variable. Desugaring lives here rather than in
    %% `pattern/2` because resolving a record tag needs `Ctx`'s `env` (F22).
    Desugared = [desugar(P, Ctx) || P <- Patterns],
    {Patterns0, RelTests} = strip_rels(Desugared),
    %% The boundary guard is injected before `Used` is computed. It mentions
    %% the parameter variable, so a parameter the body never names would
    %% otherwise lower to `_Foo` while the guard referenced `Foo`, a compile
    %% error in the emitted Erlang. The relational tests mention `bs@rN` and
    %% are in the same list for the same reason.
    {Patterns1, Tests} = boundary_guards(Patterns0, Params, Line, Ctx, Public),
    %% The boundary tests lead the guard: `is_integer/1` first, then the
    %% comparisons, so a wrong-kind term fails on one test rather than three
    %% (F24, ticket 58).
    Guard1 = conjoin(Tests ++ RelTests, Guard, Line),
    %% A `== acc` in one pattern reads `acc` bound by another, and
    %% `used_vars/2` looks only at the body and guard. Without seeding `Used`
    %% from the patterns the binder would lower to `_Acc` while the match
    %% emitted `Acc`, and the emitted Erlang would not compile (F8).
    Read = lists:append([matched_vars(P) || P <- Patterns1]),
    Used = lists:foldl(fun sets:add_element/2,
                       used_vars(Body, guard_vars(Guard1)), Read),
    {clause, Line,
     [pattern(P, Used) || P <- Patterns1],
     guard(Guard1, Ctx),
     body_exprs(Body, Ctx)}.

%%% ---------------------------------------------------------------------------
%%% Bodies
%%%
%%% A binding lowers to a `{match, …}` in the clause body's own sequence, with
%%% no `{block, …}` around it, which keeps the final expression in tail
%%% position (ticket 34).
%%% ---------------------------------------------------------------------------

body_exprs({e_block, _, Binds, Final}, Ctx) ->
    binds(Binds, Final, Ctx) ++ [expr(Final, Ctx)];
body_exprs(E, Ctx) ->
    [expr(E, Ctx)].

binds([], _Final, _Ctx) -> [];
binds([{bind, L, Name, E} | Rest], Final, Ctx) ->
    %% A bound name nothing later mentions lowers to `_`-prefixed rather than
    %% being rejected: naming a value to say what it is is legitimate, and
    %% Erlang would otherwise warn (ticket 23).
    Later = later_vars(Rest, Final),
    Var = case sets:is_element(Name, Later) of
              true  -> var_name(Name);
              false -> list_to_atom([$_ | atom_to_list(var_name(Name))])
          end,
    [{match, L, {var, L, Var}, expr(E, Ctx)} | binds(Rest, Final, Ctx)];
%% A destructuring bind is the same `{match, …}` with a pattern on the left,
%% lowered through `pattern/2` like a clause head; the checker has already
%% proved it cannot fail, and `pattern/2` underscores what nothing reads (F5).
binds([{dbind, L, P, E} | Rest], Final, Ctx) ->
    [{match, L, pattern(P, later_vars(Rest, Final)), expr(E, Ctx)}
     | binds(Rest, Final, Ctx)].

later_vars(Rest, Final) ->
    lists:foldl(fun(B, A) -> used_vars(element(4, B), A) end,
                used_vars(Final, sets:new([{version, 2}])), Rest).

%%% ---------------------------------------------------------------------------
%%% The boundary guard
%%%
%%% A record parameter gets a guard on its `Kind` tag, because a body only
%%% projects fields and would never object to a map claiming the wrong record
%%% (ticket 18 §1, 26 §1). The exact-field-set test is a second tier, emitted
%%% only where a codegen obligation consumes the record; none exists yet.
%%%
%%% The tag test is emitted only where the declared type is a single closed
%%% record, since a union would need a disjunction over tags, and not where
%%% the clause's own pattern already constrains `Kind`, since the head then
%%% performs the identical test.
%%% ---------------------------------------------------------------------------

boundary_guards(Patterns, Params, Line, Ctx, Public) ->
    Zipped = lists:zip3(Patterns, Params, lists:seq(1, length(Patterns))),
    Folded = [guard_one(P, Param, I, Line, Ctx, Public) || {P, Param, I} <- Zipped],
    {[NewP || {NewP, _} <- Folded],
     [T || {_, Ts} <- Folded, T <- Ts]}.

%% The tag guard and the integer guard are mutually exclusive: a record type
%% has a `maps` part and an integer type does not, so no parameter is a
%% candidate for both.
guard_one(Pat, {param, TypeExpr, _}, I, Line, Ctx, Public) ->
    case record_tag(TypeExpr, Ctx) of
        {ok, Tag} ->
            case constrains_kind(Pat) of
                true  -> {Pat, []};
                false ->
                    {Var, Pat1} = ensure_var(Pat, I, Line),
                    {Pat1, [tag_test(Var, Tag, Line)]}
            end;
        none when Public ->
            int_guard(Pat, TypeExpr, I, Line, Ctx);
        none ->
            {Pat, []}
    end.

%%% ---------------------------------------------------------------------------
%%% The kind guard
%%%
%%% An exported function whose parameter is declared `int` (or a refinement of
%%% it) gets an `is_integer/1` guard, because a comparison is not a type test:
%%% `100.5 >= 9` is true, so without it a float reaches `Classify(>= 9)` and
%%% answers from a parameter published as `0..255` (F24, ticket 58).
%%%
%%% Exported functions only: a private function's every call site is a checked
%%% B# call site, so the out-of-domain argument was already refused (ticket 18
%%% §4). The record tag guard above is emitted on private functions too; that
%%% asymmetry is deliberate (ticket 46).
%%%
%%% Only `int` so far. An `atom` or `binary` parameter is the same rule with a
%%% different test and is still owed.
%%% ---------------------------------------------------------------------------

int_guard(Pat, TypeExpr, I, Line, Ctx) ->
    case is_int_only(TypeExpr, Ctx) andalso not pins_integer(Pat) of
        false -> {Pat, []};
        true  ->
            {Var, Pat1} = ensure_var(Pat, I, Line),
            {Pat1, [int_test(Var, Line)]}
    end.

%% A type is int-only when every part but the integer one is empty and the
%% integer one is inhabited. `Octet` and `int` are the same shape with
%% different ranges (ticket 20 §5); `int | :none` is not int-only, because its
%% atom part is a second admissible kind, and gets no guard (ticket 18).
is_int_only(TypeExpr, #{env := Env}) ->
    try bs_check:resolve(TypeExpr, Env) of
        #{ints := Is, atoms := {finite, []}, tuples := [], lists := [],
          maps := [], bins := []} when Is =/= [] -> true;
        _ -> false
    catch _:_ -> false
    end.

%% No guard is emitted where the head already objects: `Only(1)` does not
%% match `1.0` (ticket 18 §1). A relational pattern does not pin, because a
%% comparison orders rather than tests; by the time this runs `strip_rels/1`
%% has made `Classify(>= 9)` a bare `p_var`. A disjunction is only as pinned
%% as its weakest arm; a conjunction is pinned if any arm pins.
pins_integer({p_int, _, _})        -> true;
pins_integer({p_alias, _, _, P})   -> pins_integer(P);
pins_integer({p_and, _, A, B})     -> pins_integer(A) orelse pins_integer(B);
pins_integer({p_or, _, A, B})      -> pins_integer(A) andalso pins_integer(B);
pins_integer(_)                    -> false.

%% Built as a surface node so `used_vars/2` and `expr/2` handle it by their
%% existing paths; `erlang:is_integer/1` is a guard BIF and is legal in a guard
%% as a remote call, like `erlang:map_get/2` in the tag test.
int_test(Var, Line) ->
    {e_foreign_call, Line, erlang, is_integer, [{e_var, Line, Var}]}.

%% A record parameter is a single closed map member carrying a singleton
%% `Kind`; a union, a bare `term` or an untagged map is not one.
record_tag(TypeExpr, #{env := Env}) ->
    try bs_check:resolve(TypeExpr, Env) of
        #{maps := [{closed, Fields}], atoms := {finite, []}, ints := [],
          tuples := [], lists := [], bins := []} ->
            case maps:find('Kind', Fields) of
                {ok, #{atoms := {finite, [Tag]}, ints := [], tuples := [],
                       lists := [], maps := [], bins := []}} -> {ok, Tag};
                _ -> none
            end;
        _ -> none
    catch _:_ -> none
    end.

%% A pattern constrains the tag when it matches `Kind`, through an alias too:
%% a bound record pattern already tested the tag, and a second test would be
%% redundant. `desugar/2` has already turned a `p_rec` into a tagged `p_map`.
constrains_kind({p_map, _, Fields}) -> lists:keymember('Kind', 1, Fields);
constrains_kind({p_alias, _, _, P}) -> constrains_kind(P);
constrains_kind(_)                  -> false.

%% A `p_rec` becomes a `p_map` with the minted tag prepended, and a `p_bind`
%% becomes a `p_alias`; `pattern/2` gains no clause (F22, ticket 55). The tag
%% is read from the resolved type by `record_tag/2` rather than re-minted, so
%% it cannot drift from `bs_check:qualified/2`. The walk recurses, because a
%% record pattern may sit inside a tuple: `(Frame { Type: :method } f, rest)`.
desugar({p_rec, L, Name, Fields}, Ctx) ->
    Tag = case record_tag({t_ref, Name}, Ctx) of
              {ok, T} -> T;
              none    -> erlang:error({not_a_record, L, Name})
          end,
    {p_map, L, [{'Kind', {p_atom, L, Tag}}
                | [{K, desugar(P, Ctx)} || {K, P} <- Fields]]};
desugar({p_bind, L, V, P}, Ctx)        -> {p_alias, L, V, desugar(P, Ctx)};
desugar({p_tuple, L, Ps}, Ctx)         -> {p_tuple, L, [desugar(P, Ctx) || P <- Ps]};
desugar({p_map, L, Fs}, Ctx)           -> {p_map, L, [{K, desugar(P, Ctx)} || {K, P} <- Fs]};
desugar({p_alias, L, V, P}, Ctx)       -> {p_alias, L, V, desugar(P, Ctx)};
desugar({p_and, L, A, B}, Ctx)         -> {p_and, L, desugar(A, Ctx), desugar(B, Ctx)};
desugar({p_or, L, A, B}, Ctx)          -> {p_or, L, desugar(A, Ctx), desugar(B, Ctx)};
desugar({p_list, L, Items, Rest}, Ctx) ->
    {p_list, L, [desugar(P, Ctx) || P <- Items],
     case Rest of nil -> nil; R -> desugar(R, Ctx) end};
desugar(P, _Ctx)                       -> P.

%% A guard needs a variable to test, so a wildcard gets one. `@` cannot appear
%% in a B# variable, so a synthesised name never collides with a user's.
ensure_var({p_wild, L}, I, _Line) ->
    V = list_to_atom("bs@" ++ integer_to_list(I)),
    {V, {p_var, L, V}};
ensure_var(P = {p_var, _, V}, _I, _Line) ->
    {V, P};
ensure_var(P, I, Line) ->
    %% A structural pattern is aliased whole, so the tag has a name to be read
    %% from.
    V = list_to_atom("bs@" ++ integer_to_list(I)),
    {V, {p_alias, Line, V, P}}.

%% Built as a surface node rather than abstract format, so `used_vars/2` and
%% `expr/2` handle it by their existing paths.
tag_test(Var, Tag, Line) ->
    {e_op, Line, '==',
     {e_foreign_call, Line, erlang, map_get,
      [{e_atom, Line, 'Kind'}, {e_var, Line, Var}]},
     {e_atom, Line, Tag}}.

%%% ---------------------------------------------------------------------------
%%% Relational patterns
%%%
%%% A relational pattern lowers to a variable plus the guard it would have
%%% been: `Classify(>= 4 and <= 7)` becomes `classify(Bs@r1) when Bs@r1 >= 4
%%% andalso Bs@r1 =< 7`, and nothing downstream learns a new shape (ticket 42).
%%% One variable per relational subtree, not per test, because `>= 4 and <= 7`
%%% constrains a single value twice. Only the top of each argument is walked:
%%% the checker refuses a relational pattern anywhere else
%%% (`argument_position/2`), so nesting never reaches emission.
strip_rels(Patterns) ->
    {Ps, Tests, _N} =
        lists:foldl(
          fun(P, {Acc, Ts, N}) ->
                  case is_rel(P) of
                      false -> {Acc ++ [P], Ts, N};
                      true  ->
                          L = element(2, P),
                          V = list_to_atom("bs@r" ++ integer_to_list(N)),
                          {Acc ++ [{p_var, L, V}], Ts ++ [rel_expr(P, V)], N + 1}
                  end
          end, {[], [], 1}, Patterns),
    {Ps, Tests}.

is_rel({p_rel, _, _, _}) -> true;
is_rel({p_and, _, _, _}) -> true;
is_rel({p_or,  _, _, _}) -> true;
is_rel(_)                -> false.

%% Built as surface nodes, like `tag_test/3`, so `used_vars/2` and `expr/2`
%% handle them by their existing paths.
rel_expr({p_rel, L, Op, K}, V) -> {e_op, L, Op, {e_var, L, V}, {e_int, L, K}};
rel_expr({p_and, L, A, B}, V)  -> {e_op, L, 'and', rel_expr(A, V), rel_expr(B, V)};
rel_expr({p_or,  L, A, B}, V)  -> {e_op, L, 'or',  rel_expr(A, V), rel_expr(B, V)}.

conjoin([], Guard, _Line) -> Guard;
conjoin(Tests, none, Line) -> {guard, fold_and(Tests, Line)};
conjoin(Tests, {guard, Expr}, Line) -> {guard, fold_and(Tests ++ [Expr], Line)}.

fold_and([E], _Line) -> E;
fold_and([E | Rest], Line) -> {e_op, Line, 'and', E, fold_and(Rest, Line)}.

guard_vars(none)          -> sets:new([{version, 2}]);
guard_vars({guard, Expr}) -> used_vars(Expr, sets:new([{version, 2}])).

used_vars({e_var, _, V}, Acc)        -> sets:add_element(V, Acc);
used_vars({e_tuple, _, Es}, Acc)     -> lists:foldl(fun used_vars/2, Acc, Es);
used_vars({e_call, _, _, As}, Acc)   -> lists:foldl(fun used_vars/2, Acc, As);
%% Only the value argument of a `ValidateAs` holds variables; the type
%% arguments are types (F18).
used_vars({e_inst, _, _, _, As}, Acc) -> lists:foldl(fun used_vars/2, Acc, As);
used_vars({e_op, _, _, A, B}, Acc)   -> used_vars(B, used_vars(A, Acc));
used_vars({e_nil, _}, Acc)           -> Acc;
used_vars({e_proj, _, V, _}, Acc)    -> sets:add_element(V, Acc);
used_vars({e_block, _, Binds, Final}, Acc) ->
    lists:foldl(fun(B, A) -> used_vars(element(4, B), A) end,
                used_vars(Final, Acc), Binds);
used_vars({e_record, _, _, Fs}, Acc) ->
    lists:foldl(fun({_, E}, A) -> used_vars(E, A) end, Acc, Fs);
used_vars({e_with, _, Base, Fs}, Acc) ->
    lists:foldl(fun({_, E}, A) -> used_vars(E, A) end, used_vars(Base, Acc), Fs);
used_vars({e_foreign_call, _, _, _, As}, Acc) -> lists:foldl(fun used_vars/2, Acc, As);
used_vars({e_qcall, _, _, _, As}, Acc) -> lists:foldl(fun used_vars/2, Acc, As);
%% The walk descends into arms: a parameter read only inside an arm body
%% would otherwise lower to `_N` in the head while the arm emitted `N`, a
%% compile error in the emitted Erlang. Arm-bound names are harmless in the
%% set, because an arm may not rebind a name already in scope.
used_vars({e_switch, _, Subject, Arms}, Acc) ->
    lists:foldl(fun({arm, _, _, G, Body}, A) ->
                        used_vars(Body, sets:union(A, guard_vars(G)))
                end, used_vars(Subject, Acc), Arms);
%% A valve is walked like the switch it wraps, for the same reason: a
%% parameter read only inside a stage must not be underscored (F14).
used_vars({e_valve, _, Switch}, Acc) -> used_vars(Switch, Acc);
used_vars({e_list, _, Items, Rest}, Acc) ->
    R = case Rest of nil -> Acc; _ -> used_vars(Rest, Acc) end,
    lists:foldl(fun used_vars/2, R, Items);
used_vars(_, Acc)                    -> Acc.

guard(none, _Ctx)          -> [];
guard({guard, Expr}, Ctx)  -> [[expr(Expr, Ctx)]].

%%% ---------------------------------------------------------------------------
%%% Patterns
%%% ---------------------------------------------------------------------------

pattern({p_int, L, N}, _U)     -> {integer, L, N};
pattern({p_atom, L, A}, _U)    -> {atom, L, A};
pattern({p_wild, L}, _U)       -> {var, L, '_'};
pattern({p_tuple, L, Ps}, U)   -> {tuple, L, [pattern(P, U) || P <- Ps]};
pattern({p_nil, L}, _U)        -> {nil, L};
%% A map pattern uses `:=`: matching a key the term has not got fails the
%% clause, which is the `function_clause` the failure arm exists to produce
%% (ticket 12).
pattern({p_map, L, Fields}, U) ->
    {map, L, [{map_field_exact, L, {atom, L, K}, pattern(P, U)} || {K, P} <- Fields]};
%% An alias's name goes through the `p_var` clause rather than being built
%% here, so an unused binder underscores exactly as an unused parameter does;
%% `Which(Method { Channel: 7 } f) -> :seven` must not warn on `F` (F22.10).
pattern({p_alias, L, V, P}, U) ->
    {match, L, pattern({p_var, L, V}, U), pattern(P, U)};
%% `[a, b, ..rest]` is a right fold of cons cells onto the rest.
pattern({p_list, L, Items, Rest}, U) ->
    lists:foldr(fun(P, Acc) -> {cons, L, pattern(P, U), Acc} end,
                case Rest of
                    nil -> {nil, L};
                    R   -> pattern(R, U)
                end,
                Items);
pattern({p_var, L, V}, Used)   ->
    case sets:is_element(V, Used) of
        true  -> {var, L, var_name(V)};
        false -> {var, L, list_to_atom([$_ | atom_to_list(var_name(V))])}
    end;
%% `== acc` lowers to the variable itself: a bound variable repeated in an
%% Erlang pattern is already an equality test, so no guard or temporary is
%% emitted (F8). It is never underscored, being a use by definition, and
%% `clause/4` seeds `Used` with it so the binder is not underscored either.
pattern({p_eqvar, L, V}, _Used) -> {var, L, var_name(V)};
%% A binary pattern lowers one segment to one `bin_element` and emits no guard;
%% the BEAM's binary matching does the rest, sub-byte widths included (F13,
%% ticket 30). A `default` type-specifier list means unsigned big-endian
%% integer, the same platform default `bs_check:seg_type/1` infers
%% `range(0, 2^N - 1)` from.
pattern({p_bin, L, Segs}, U) ->
    {bin, L, [segment(S, U) || S <- Segs]};
%% A string literal in pattern position is a binary pattern with one string
%% segment (ticket 30 §4).
pattern({p_str, L, Bytes}, _U) ->
    {bin, L, [{bin_element, L, {string, L, Bytes}, default, default}]}.

segment({seg_bind, L, V, Size}, U) ->
    {bin_element, L, pattern({p_var, L, V}, U), seg_size(L, Size), seg_tsl(Size)};
segment({seg_wild, L, Size}, _U) ->
    {bin_element, L, {var, L, '_'}, seg_size(L, Size), seg_tsl(Size)};
segment({seg_int, L, K, N}, _U) ->
    {bin_element, L, {integer, L, K}, {integer, L, N}, default};
segment({seg_str, L, Bytes}, _U) ->
    {bin_element, L, {string, L, Bytes}, default, default}.

seg_size(_L, rest)            -> default;
seg_size(L, {width, N})       -> {integer, L, N};
%% A size variable is emitted as itself, which is why `bs_check` insists it
%% was bound earlier in the same pattern: Erlang reads a binary pattern left
%% to right, and an unbound size compiles and simply never matches.
seg_size(L, {sized_by, V})    -> {var, L, var_name(V)}.

%% A `sized_by` segment counts bytes, since `binary` carries unit 8; that is
%% what a length-prefixed wire format means by its length field.
seg_size_of({seg_bind, _, _, Size}) -> Size;
seg_size_of({seg_wild, _, Size})    -> Size;
seg_size_of(_)                      -> rest.

seg_tsl(rest)         -> [binary];
seg_tsl({sized_by, _}) -> [binary];
seg_tsl({width, _})   -> default.

%% Every name a pattern reads. Distinct from the checker's `pattern_vars`,
%% which answers what a pattern binds.
matched_vars({p_eqvar, _, V})          -> [V];
%% A segment's size is a name being read: `<<size:8, payload:size, rest>>`
%% would otherwise emit `_Size` at the binder and `Size` at the use (F13).
matched_vars({p_bin, _, Segs})         ->
    [V || S <- Segs, {sized_by, V} <- [seg_size_of(S)]];
matched_vars({p_tuple, _, Ps})         -> lists:append([matched_vars(P) || P <- Ps]);
matched_vars({p_map, _, Fs})           -> lists:append([matched_vars(P) || {_, P} <- Fs]);
matched_vars({p_alias, _, _, P})       -> matched_vars(P);
matched_vars({p_list, _, Items, Rest}) ->
    lists:append([matched_vars(P) || P <- Items])
        ++ case Rest of nil -> []; R -> matched_vars(R) end;
matched_vars(_)                        -> [].

%% A B# variable is lowercase-initial and an Erlang one must be uppercase-
%% initial, so the first character is capitalised. That is injective over the
%% source grammar, and the name stays readable in a crash report.
var_name(V) ->
    [H | T] = atom_to_list(V),
    list_to_atom([string:to_upper(H) | T]).

%%% ---------------------------------------------------------------------------
%%% Expressions
%%% ---------------------------------------------------------------------------

expr({e_int, L, N}, _C)       -> {integer, L, N};
expr({e_atom, L, A}, _C)      -> {atom, L, A};
%% A string's bytes are already UTF-8, validated by the lexer, so they are
%% emitted raw with no `/utf8` specifier; re-encoding would double-encode
%% every non-ASCII character (F9.3).
expr({e_str, L, Bytes}, _C)   ->
    {bin, L, [{bin_element, L, {string, L, Bytes}, default, default}]};
expr({e_var, L, V}, _C)       -> {var, L, var_name(V)};
expr({e_tuple, L, Es}, C)     -> {tuple, L, [expr(E, C) || E <- Es]};
%% A local call takes the same emitted name as the export list and the
%% definition: `HandleCall(...)` in a `GenServer` module must emit
%% `handle_call(...)`, or the module compiles and calls a function it does not
%% have. An unqualified call may be a remote one, and which it is was decided
%% at check time; the emitter only reads the table `bs_check` built (F11,
%% ticket 41 §2).
expr({e_call, L, F, As}, C)   ->
    Arity = length(As),
    case maps:get({F, Arity}, maps:get(imports, C, #{}), undefined) of
        undefined ->
            Name = emitted_name(F, Arity, maps:get(behaviours, C, [])),
            {call, L, {atom, L, Name}, [expr(A, C) || A <- As]};
        Mod ->
            remote(L, Mod, F, As, C)
    end;

%% `ValidateAs<T>(x)` is a bare local call to the generated validator with the
%% term as its only argument; the type argument was consumed at generation
%% time and nothing of it survives (F18, ticket 27 §8).
expr({e_inst, L, 'ValidateAs', [TypeExpr], [Arg]}, C) ->
    Ty = bs_check:resolve(TypeExpr, maps:get(env, C)),
    {_Roots, Table} = maps:get(validators, C),
    {call, L, {atom, L, root_name(maps:get(Ty, Table))}, [expr(Arg, C)]};

%% A qualified call is a remote call; the module atom is already the full
%% dotted path, so no name is built here (ticket 40 §1). A reserved qualifier
%% such as `List` names no module: the call is a local one to a function
%% generated into this module, so no `List.beam` ships (ticket 67).
%% `bs_check:reserved_call/6` has already refused a shadowing collision.
expr({e_qcall, L, Mod, Fn, As}, C) ->
    case lists:member(Mod, bs_check:reserved_qualifiers()) of
        true  -> {call, L, {atom, L, reserved_name(Mod, Fn, length(As))},
                  [expr(A, C) || A <- As]};
        false -> remote(L, Mod, Fn, As, C)
    end;
expr({e_op, L, Op, A, B}, C)  -> {op, L, erl_op(Op), expr(A, C), expr(B, C)};
expr({e_nil, L}, _C)          -> {nil, L};

%% A record erases to a map carrying its minted `Kind` tag as ordinary data,
%% which is what lets a clause head dispatch on a union of records
%% (ticket 26 §1).
expr({e_record, L, Name, Fields}, C = #{module := Mod}) ->
    Tag = bs_check:qualified(Mod, Name),
    {map, L,
     [{map_field_assoc, L, {atom, L, 'Kind'}, {atom, L, Tag}}
      | [{map_field_assoc, L, {atom, L, K}, expr(E, C)} || {K, E} <- Fields]]};

%% `o with { Total = 500 }` uses `:=`, so updating a key the term has not got
%% raises `badkey` and the field set cannot grow. The tag is untouched because
%% it is not among the keys assigned.
expr({e_with, L, Base, Fields}, C) ->
    {map, L, expr(Base, C),
     [{map_field_exact, L, {atom, L, K}, expr(E, C)} || {K, E} <- Fields]};

%% A projection is one `map_get`, which is guard-safe and so also serves the
%% boundary tag test.
expr({e_proj, L, V, Field}, _C) ->
    {call, L, {remote, L, {atom, L, erlang}, {atom, L, map_get}},
     [{atom, L, Field}, {var, L, var_name(V)}]};
%% A foreign call is an ordinary remote call, wrapped in a `try` only when its
%% declaration named a failure channel (F19). The boundary guard LANGUAGE.md
%% §10 describes over the eight violation channels is not emitted here yet
%% (ticket 18).
expr({e_foreign_call, L, Mod, Fn, As}, C) ->
    Call = {call, L, {remote, L, {atom, L, Mod}, {atom, L, Fn}},
            [expr(A, C) || A <- As]},
    case maps:is_key({Mod, Fn, length(As)}, maps:get(foreigns, C, #{})) of
        false -> Call;
        true  -> foreign_wrapper(L, Call)
    end;
expr({e_list, L, Items, Rest}, C) ->
    lists:foldr(fun(E, Acc) -> {cons, L, expr(E, C), Acc} end,
                case Rest of
                    nil -> {nil, L};
                    R   -> expr(R, C)
                end,
                Items);

%% A switch lowers to Erlang's `case`, each arm a one-pattern clause through
%% `pattern/2` (ticket 17 §6). No failure arm is emitted: the BEAM raises
%% `case_clause` on an unmatched term just as it raises `function_clause`.
expr({e_switch, L, Subject, Arms}, C) ->
    {'case', L, expr(Subject, C), [arm(A, C) || A <- Arms]};
%% A valve is unwrapped to the switch inside it; the marker only existed to
%% keep `bs_check` from advising the author about arms `bs_lower` chose (F14).
expr({e_valve, _, Switch}, C) ->
    expr(Switch, C).

%%% ---------------------------------------------------------------------------
%%% The foreign wrapper
%%%
%%% A foreign call with a declared failure channel is wrapped in a `try` that
%%% catches all three classes (F19, ticket 15 §4). An exit signal is not
%%% catchable, so a wide `catch exit:` cannot swallow a supervisor's shutdown,
%%% while narrowing to `error:` would miss the `exit({noproc, _})` a call to a
%%% dead process raises (prototype 15d).
%%%
%%% The class and reason variables are unique per module, from a counter at
%%% the emission site: a second `catch C:R` in the same clause, or a `try`
%%% nested in another's body, is `variable 'C' unsafe in 'try'`, a compile
%%% error. `bs@` keeps the names out of the source's variable grammar.
%%% ---------------------------------------------------------------------------

-define(WRAPPER_SEQ, {bs_emit, foreign_wrapper_seq}).

reset_foreign_wrappers() -> put(?WRAPPER_SEQ, 0), ok.

next_foreign_wrapper() ->
    N = case get(?WRAPPER_SEQ) of undefined -> 0; Seq -> Seq end,
    put(?WRAPPER_SEQ, N + 1),
    N.

foreign_wrapper(L, Call) ->
    N = next_foreign_wrapper(),
    Class  = {var, L, wrapper_var("bs@fc", N)},
    Reason = {var, L, wrapper_var("bs@fr", N)},
    %% A failure becomes `(:error, (Class, Reason))`, the declared `result`'s
    %% failure member. The outer `error` is `result<T, E>`'s tag and the inner
    %% `Class` is the exception class, kept so that
    %% `(:error, (:exit, (:noproc, _)))` reads as "the callee is dead"
    %% (ticket 15 §5).
    {'try', L, [Call], [],
     [{clause, L, [{tuple, L, [Class, Reason, {var, L, '_'}]}], [],
       [{tuple, L, [{atom, L, error}, {tuple, L, [Class, Reason]}]}]}],
     []}.

wrapper_var(Prefix, N) -> list_to_atom(Prefix ++ integer_to_list(N)).

%% An arm is desugared and relationally lowered exactly as a clause head is,
%% because it is the head's pattern grammar one level down (F7, F22). An arm
%% does not pass through `clause/4`, so both steps are repeated here; without
%% them a `p_rec` or `p_rel` would reach `pattern/2`, which has no clause for
%% either.
arm({arm, L, P, Guard, Body}, C) ->
    {[P1], RelTests} = strip_rels([desugar(P, C)]),
    Guard1 = conjoin(RelTests, Guard, L),
    Used = used_vars(Body, guard_vars(Guard1)),
    {clause, L, [pattern(P1, Used)], guard(Guard1, C), [expr(Body, C)]}.

%% `==` means `=:=`: the clause head and `maps:get` do not coerce, and Erlang's
%% `==` coerces through values but stops at map keys (ticket 16).
erl_op('==') -> '=:=';
erl_op('!=') -> '=/=';
erl_op('<=') -> '=<';                            % Erlang spells it the other way round
%% `and` lowers to `andalso`, not Erlang's `and`: the difference is
%% unobservable in a guard, where a raise simply fails, and short-circuiting
%% is the right behaviour in expression position (ticket 44).
erl_op('and') -> 'andalso';
erl_op('or')  -> 'orelse';
%% `/` is integer division and lowers to `div`, never Erlang's float `/`,
%% which the catch-all would otherwise pass through; `%` is `rem`, whose sign
%% follows the dividend (F26, ticket 38).
erl_op('/')  -> 'div';
erl_op('%')  -> 'rem';
erl_op(Op)   -> Op.                              % + - * < > >=

%%% ---------------------------------------------------------------------------
%%% Specs
%%% ---------------------------------------------------------------------------

spec_attr(F, Env, Behaviours) ->
    Params = element(5, F),
    Ret = element(4, F),
    ArgTypes = [spec_type(bs_check_resolve(T, Env)) || {param, T, _} <- Params],
    RetType = spec_type(bs_check_resolve(Ret, Env)),
    {attribute, ?A, spec,
     {{name(F, Behaviours), length(Params)},
      [{type, ?A, 'fun', [{type, ?A, product, ArgTypes}, RetType]}]}}.

%% Types are resolved by the checker's resolver only; a second one here would
%% be a second place for the record tag rule to drift (ticket 26 §1).
bs_check_resolve(T, Env) -> bs_check:resolve(T, Env).

%% A recursive type is emitted as a reference to a named `-type`, not inlined
%% (F28). Both `mu` and `recvar` become `Name()`; the body is declared once by
%% `rec_type_attrs/2`. Inlining would not terminate, and widening to `any()`
%% would pass Dialyzer while saying nothing.
spec_type(#{mu := N})     -> {user_type, ?A, N, []};
spec_type(#{recvar := N}) -> {user_type, ?A, N, []};
spec_type(Ty) ->
    case parts(Ty) of
        []  -> {type, ?A, none, []};
        [P] -> P;
        Ps  -> {type, ?A, union, Ps}
    end.

%% One `-type` per distinct binder reachable from any signature in the module,
%% collected in a separate pass so `spec_type/1` stays a pure function from a
%% type to a form.
rec_type_attrs(Fns, Env) ->
    Tys = lists:append(
            [[bs_check_resolve(T, Env) || {param, T, _} <- element(5, F)]
             ++ [bs_check_resolve(element(4, F), Env)] || F <- Fns]),
    Binders = lists:foldl(fun collect_mu/2, #{}, Tys),
    [{attribute, ?A, type, {N, spec_type(Body), []}}
     || {N, Body} <- lists:sort(maps:to_list(Binders))].

%% A binder already collected is not walked again, and a `recvar` collects
%% nothing; that is what terminates the walk.
collect_mu(#{mu := N, body := B}, Acc) ->
    case maps:is_key(N, Acc) of
        true  -> Acc;
        false -> lists:foldl(fun collect_mu/2, Acc#{N => B}, bs_types:components(B))
    end;
collect_mu(#{recvar := _}, Acc) -> Acc;
collect_mu(Ty, Acc) ->
    lists:foldl(fun collect_mu/2, Acc, bs_types:components(Ty)).

parts(Ty = #{atoms := As, ints := Is, tuples := Ts, maps := Ms,
             bins := Bs}) ->
    atom_parts(As) ++ [int_part(R) || R <- Is] ++ tuple_parts(Ts)
        ++ list_parts(Ty) ++ map_parts(Ms) ++ bin_parts(Bs).

%% `string`, `binary` and `binary \ string` all emit `binary()`: Erlang's type
%% language has no UTF-8 refinement. The widening is confined to the spec; the
%% algebra the checker reasons with keeps the three apart (ticket 20).
bin_parts([])  -> [];
bin_parts(_)   -> [{type, ?A, binary, []}].

%% A closed member emits all-mandatory `:=` keys, an open one adds
%% `any() => any()` for the fields it does not constrain, and a domain member
%% emits `#{K() => V()}`; nothing is widened to `map()` (F3.12, ticket 48).
map_parts(top) -> [{type, ?A, map, any}];
map_parts(Members) -> [map_part(M) || M <- Members].

map_part({dom, K, V}) ->
    {type, ?A, map, [{type, ?A, map_field_assoc, [spec_type(K), spec_type(V)]}]};
map_part({Kind, Fields}) ->
    Exact = [{type, ?A, map_field_exact, [{atom, ?A, K}, spec_type(V)]}
             || {K, V} <- lists:sort(maps:to_list(Fields))],
    Rest = case Kind of
               closed -> [];
               open   -> [{type, ?A, map_field_assoc,
                           [{type, ?A, any, []}, {type, ?A, any, []}]}]
           end,
    {type, ?A, map, Exact ++ Rest}.

tuple_parts(top) -> [{type, ?A, tuple, any}];
tuple_parts(Ps)  -> [tuple_part(P) || P <- Ps].

%% A cons-only part emits `nonempty_list(T)` and nil-plus-cons emits `[T]`.
%% Erlang has no fixed-length list type, so a residual the checker knows
%% exactly, such as `[int]`, widens here; that is honest, since Dialyzer reads
%% a spec as an upper bound, and exhaustiveness was already decided against
%% the spine in `bs_check` (F20, ticket 20).
list_parts(Ty) ->
    case {bs_types:has_nil(Ty), bs_types:has_cons(Ty)} of
        {false, false} -> [];
        {true, false}  -> [{type, ?A, nil, []}];
        {Nil, true} ->
            Elem = bs_types:list_elem(Ty),
            Arg = case bs_types:is_subtype(bs_types:term(), Elem) of
                      true  -> {type, ?A, any, []};
                      false -> spec_type(Elem)
                  end,
            case Nil of
                true  -> [{type, ?A, list, [Arg]}];
                false -> [{type, ?A, nonempty_list, [Arg]}]
            end
    end.

atom_parts({finite, L})    -> [{atom, ?A, A} || A <- L];
atom_parts({cofinite, _})  -> [{type, ?A, atom, []}].   % widened: the exclusion is lost

%% An interval in a declared type emits the matching Erlang range type. Only
%% the first clause is reachable today: intervals arise from guards, which
%% refine a clause rather than a signature, until the parser gains guard
%% refinement, `type Positive = int where value > 0;` (ticket 20 §5).
int_part({neg_inf, pos_inf}) -> {type, ?A, integer, []};
int_part({Lo, Hi}) when is_integer(Lo), is_integer(Hi) ->
    {type, ?A, range, [{integer, ?A, Lo}, {integer, ?A, Hi}]};
int_part({neg_inf, Hi}) when is_integer(Hi), Hi < 0 -> {type, ?A, neg_integer, []};
int_part({0, pos_inf})  -> {type, ?A, non_neg_integer, []};
int_part({1, pos_inf})  -> {type, ?A, pos_integer, []};
int_part(_)             -> {type, ?A, integer, []}.     % widened: no Erlang spelling

tuple_part(Components) ->
    {type, ?A, tuple, [spec_type(C) || C <- Components]}.

%%% ---------------------------------------------------------------------------
%%% `ValidateAs<T>`, the generated deep validator
%%%
%%% Deep validation happens at an explicit call site, never in a clause head,
%%% because the traversal is O(n·depth) and the sender chooses n (ticket 11
%%% §2); it returns `result<T, ValidationError>`, a path into the term plus
%%% the type expected there (ticket 15 §2).
%%%
%%% `<T>` is consumed at compile time: the module holds one ordinary Erlang
%%% function per distinct resolved `T`, and no type argument survives to run
%%% time (ticket 27 §8). The traversal is generated from the algebra, a DNF
%%% partitioned by constructor: the atom part becomes atom clauses, the
%%% integer part range guards, a tuple product a tuple pattern, a closed map
%%% member a map pattern plus `map_size/1`. `option<int>` and `int | :nothing`
%%% therefore generate the same validator.
%%%
%%% A recursive type terminates because `close_over/2` records a type's name
%%% before walking its children, so a recursive occurrence emits a call back
%%% into the function being generated; `children/1` and `validator_form/3`
%%% unfold a binder first (F28).
%%%
%%% Two protocols: internally every validator returns
%%% `{ok, V} | {error, {Path, Expected}}`, and only the root wrapper unwraps
%%% that into the untagged `T | (:error, E)` the language declares. Without
%%% the internal tag a validator over a type containing `(:error, _)` could
%%% not tell its own failure from a value it had just accepted.
%%% ---------------------------------------------------------------------------

-define(VV, {var, ?A, 'Bs@v'}).                 % the term under test
-define(VP, {var, ?A, 'Bs@p'}).                 % the path so far, reversed

%% Every distinct type any `ValidateAs<T>` in the module needs a validator for,
%% sub-types included, keyed by resolved type so two spellings of one type
%% share one generated function.
validator_table(Fns, Env) ->
    Roots = lists:usort([bs_check:resolve(TE, Env)
                         || {e_inst, _, 'ValidateAs', [TE], [_]} <- inst_nodes(Fns)]),
    {Roots, close_over(Roots, #{})}.

%% A generic term walk, since a `ValidateAs` may sit anywhere an expression
%% may and a per-node walk would go stale when a node is added.
inst_nodes(T) when is_tuple(T) ->
    Here = case T of
               {e_inst, _, 'ValidateAs', [_], [_]} -> [T];
               _                                   -> []
           end,
    Here ++ inst_nodes(tuple_to_list(T));
inst_nodes(L) when is_list(L) -> lists:append([inst_nodes(E) || E <- L]);
inst_nodes(_)                 -> [].

close_over([], Acc) -> Acc;
close_over([Ty | Rest], Acc) ->
    case maps:is_key(Ty, Acc) of
        true  -> close_over(Rest, Acc);
        false ->
            Name = list_to_atom("bs@validate@" ++ integer_to_list(maps:size(Acc) + 1)),
            close_over(children(Ty) ++ Rest, Acc#{Ty => Name})
    end.

%% The sub-types this type's traversal calls a validator for: each component
%% or field the descent enters, and, where a constructor does not pick out a
%% single candidate, each candidate as a type in its own right. A binder's
%% children are its unfolding's children; the recursive ones are this same
%% binder, already in `close_over/2`'s accumulator (F28).
children(#{mu := _} = Ty) -> children(bs_types:unfold(Ty));
children(Ty) ->
    #{tuples := Ts, maps := Ms} = Ty,
    tuple_children(Ts) ++ list_children(Ty) ++ map_children(Ms).

tuple_children(top) -> [];
tuple_children(Products) ->
    lists:append([case Case of
                      {one, Fixed, P} -> [C || {I, C} <- indexed(P),
                                               I =/= Fixed, checked(C)];
                      {alts, Ps}      -> [bs_types:tuple(P) || P <- Ps]
                  end || Case <- tuple_cases(Products)]).

list_children(Ty) ->
    Elem = bs_types:list_elem(Ty),
    case bs_types:is_none(Elem) of
        true  -> [];
        false -> [Elem || checked(Elem)]
    end.

map_children(top) -> [];
map_children(Members) ->
    lists:append([case Case of
                      %% Fields are walked in sorted order, as `map_case/3`
                      %% walks them, because the worklist order numbers the
                      %% generated functions and must be deterministic.
                      {one, Fixed, {_, Fs}} -> [maps:get(K, Fs)
                                                || K <- lists:sort(maps:keys(Fs)),
                                                   K =/= Fixed,
                                                   checked(maps:get(K, Fs))];
                      {alts, Ms}            -> [member_ty(M) || M <- Ms]
                  end || Case <- map_cases(Members)]).

map_key({Kind, Fs})     -> {Kind, lists:sort(maps:keys(Fs))}.
member_ty({closed, Fs}) -> bs_types:map_closed(Fs);
member_ty({open, Fs})   -> bs_types:map_open(Fs).

%%% --- deciding where the descent is unambiguous -----------------------------
%%%
%%% `children/1` and the clause builders read one decomposition, made in
%%% `tuple_cases/1` and `map_cases/1`: a child nobody generates is a `badkey`
%%% at compile time, and a child nobody calls is a dead function. A case is
%%% `{one, Fixed, Candidate}`, the only candidate that can match, with `Fixed`
%%% naming the position or key whose literal sits in the pattern, or
%%% `{alts, Candidates}`, where nothing structural chooses and the blame
%%% stays at this node.

tuple_cases(Products) ->
    lists:append([arity_case(G)
                  || {_, G} <- group_by(fun erlang:length/1, Products)]).

arity_case([P]) -> [{one, none, P}];
arity_case(Ps) ->
    Slots = lists:seq(1, length(hd(Ps))),
    case discriminator(fun(I, P) -> lists:nth(I, P) end, Slots, Ps) of
        none        -> [{alts, Ps}];
        {I, Tagged} -> [{one, I, P} || {_A, P} <- Tagged]
    end.

map_cases(Members) ->
    %% Closed members first: a closed member's `map_size/1` guard cannot match
    %% a wider map, while an open member has no guard and would shadow a
    %% closed one listed after it.
    Ordered = [M || M = {closed, _} <- Members] ++ [M || M = {open, _} <- Members],
    lists:append([shape_case(G) || {_, G} <- group_by(fun map_key/1, Ordered)]).

shape_case([M]) -> [{one, none, M}];
shape_case(Ms = [{_, Fs} | _]) ->
    Keys = lists:sort(maps:keys(Fs)),
    case discriminator(fun(K, {_, F}) -> maps:get(K, F) end, Keys, Ms) of
        none        -> [{alts, Ms}];
        {K, Tagged} -> [{one, K, M} || {_A, M} <- Tagged]
    end.

%% A slot discriminates when every candidate has a distinct singleton atom
%% there, so `(:ok, int) | (:error, atom)` is decided by its first component
%% and a union of records by `Kind`. Every candidate, because one without a
%% tag would be shadowed by a sibling's clause; distinct, because two carrying
%% the same tag are still two. Anything weaker would blame a value against
%% the wrong candidate.
discriminator(_At, [], _Cs) -> none;
discriminator(At, [Slot | Rest], Cs) ->
    Atoms = [A || C <- Cs, {tag, A} <- [tag_of(At(Slot, C))]],
    case length(Atoms) =:= length(Cs) andalso
         length(lists:usort(Atoms)) =:= length(Atoms) of
        true  -> {Slot, lists:zip(Atoms, Cs)};
        false -> discriminator(At, Rest, Cs)
    end.

tag_of(Ty = #{atoms := {finite, [A]}}) ->
    case Ty =:= bs_types:atom_lit(A) of
        true  -> {tag, A};
        false -> none
    end;
tag_of(_) -> none.

%% Nothing is generated for `term`: every value inhabits it, so the site that
%% would call its validator does not. `ValidateAs<term>` itself is refused at
%% the call site (ticket 15 §1).
checked(Ty) -> not bs_types:is_subtype(bs_types:term(), Ty).

validator_forms({Roots, Table}) ->
    Ordered = lists:sort(fun({_, A}, {_, B}) -> A =< B end, maps:to_list(Table)),
    lists:append([validator_form(Ty, Name, Table) || {Ty, Name} <- Ordered])
    ++ [root_form(maps:get(Ty, Table)) || Ty <- Roots].

%% The root wrapper, the only function a call site names, converts the
%% internal `{ok, V}` protocol into the untagged `T | (:error, E)` the language
%% declares (ticket 15 §2). Doing it here keeps the call site a bare call with
%% no variables, so two `ValidateAs` in one expression cannot collide.
root_form(Name) ->
    XV = {var, ?A, 'Bs@x'},
    VV = {var, ?A, 'Bs@ok'},
    EV = {var, ?A, 'Bs@er'},
    {function, ?A, root_name(Name), 1,
     [{clause, ?A, [XV], [],
       [{'case', ?A, {call, ?A, {atom, ?A, Name}, [XV, {nil, ?A}]},
         [{clause, ?A, [{tuple, ?A, [{atom, ?A, ok}, VV]}], [], [VV]},
          {clause, ?A, [{tuple, ?A, [{atom, ?A, error}, EV]}], [],
           [{tuple, ?A, [{atom, ?A, error}, EV]}]}]}]}]}.

%%% ---------------------------------------------------------------------------
%%% The reserved qualifiers' operations, generated
%%%
%%% A reserved qualifier's operation is emitted as a local recursive function
%%% in the module that uses it, never as a call to a shipped module or to
%%% `lists`; a compiled program's only runtime dependency is the BEAM
%%% (ticket 67). One function per {qualifier, name, arity} used, with no type
%%% in the key: none of these traversals looks at the element, so `list<int>`
%%% and `list<Order>` share one `Reverse`.
%%% ---------------------------------------------------------------------------

%% A generic term walk, for `inst_nodes/1`'s reason.
reserved_forms(Fns) ->
    Used = lists:usort([{M, F, length(As)}
                        || {e_qcall, _, M, F, As} <- qcall_nodes(Fns),
                           lists:member(M, bs_check:reserved_qualifiers())]),
    lists:append([reserved_form(K) || K <- Used]).

qcall_nodes(T) when is_tuple(T) ->
    Here = case T of
               {e_qcall, _, _, _, _} -> [T];
               _                     -> []
           end,
    Here ++ qcall_nodes(tuple_to_list(T));
qcall_nodes(L) when is_list(L) -> lists:append([qcall_nodes(E) || E <- L]);
qcall_nodes(_)                 -> [].

%% `@` cannot appear in a B# identifier, so a generated name never collides
%% with an author's.
reserved_name(Q, Fn, Arity) ->
    list_to_atom("bs@" ++ atom_to_list(Q) ++ "@" ++ atom_to_list(Fn)
                 ++ "@" ++ integer_to_list(Arity)).

%% Every list operation is tail-recursive through an accumulator, so each
%% emits two functions; generated code no author can rewrite does not get to
%% build a stack frame per element.
reserved_form({'List', 'Sum', 1}) ->
    acc_form('List', 'Sum', 1, 'Bs@h', {integer, ?A, 0},
             fun(H, Acc) -> {op, ?A, '+', Acc, H} end);
%% `Length` binds the head as `_Bs@h` because it is the one operation that
%% does not read the element; an unused-variable warning from generated code
%% would surface against a `.bs` the author cannot change (F4).
reserved_form({'List', 'Length', 1}) ->
    acc_form('List', 'Length', 1, '_Bs@h', {integer, ?A, 0},
             fun(_H, Acc) -> {op, ?A, '+', Acc, {integer, ?A, 1}} end);
reserved_form({'List', 'Reverse', 1}) ->
    acc_form('List', 'Reverse', 1, 'Bs@h', {nil, ?A},
             fun(H, Acc) -> {cons, ?A, H, Acc} end);
%% `Term.Compare` uses Erlang's own term order and answers with one of three
%% atoms a `switch` must cover, `lt`, `gt` or `eq` (ticket 16).
reserved_form({'Term', 'Compare', 2}) ->
    A = {var, ?A, 'Bs@a'},
    B = {var, ?A, 'Bs@b'},
    [{function, ?A, reserved_name('Term', 'Compare', 2), 2,
      [{clause, ?A, [A, B], [[{op, ?A, '<', A, B}]], [{atom, ?A, lt}]},
       {clause, ?A, [A, B], [[{op, ?A, '>', A, B}]], [{atom, ?A, gt}]},
       {clause, ?A, [{var, ?A, '_'}, {var, ?A, '_'}], [], [{atom, ?A, eq}]}]}].

%% An arity-1 entry that seeds the accumulator and an arity-2 walker; `Step`
%% builds the new accumulator from the head and the old one.
acc_form(Q, Fn, Arity, Head, Seed, Step) ->
    Name = reserved_name(Q, Fn, Arity),
    Walk = list_to_atom(atom_to_list(Name) ++ "@w"),
    XV = {var, ?A, 'Bs@x'},
    HV = {var, ?A, Head},
    TV = {var, ?A, 'Bs@t'},
    AV = {var, ?A, 'Bs@acc'},
    [{function, ?A, Name, 1,
      [{clause, ?A, [XV], [], [{call, ?A, {atom, ?A, Walk}, [XV, Seed]}]}]},
     {function, ?A, Walk, 2,
      [{clause, ?A, [{nil, ?A}, AV], [], [AV]},
       {clause, ?A, [{cons, ?A, HV, TV}, AV], [],
        [{call, ?A, {atom, ?A, Walk}, [TV, Step(HV, AV)]}]}]}].

root_name(Name)   -> list_to_atom(atom_to_list(Name) ++ "@r").
walker_name(Name) -> list_to_atom(atom_to_list(Name) ++ "@e").

%% The error names the binder and the clauses are generated from its
%% unfolding: "expected Tree" is useful where one unfolding of Tree is not,
%% while the traversal has to see constructors. The unfolding's recursive
%% positions are the same `mu` node, already in `Table` under this name, so
%% they call back into this function (F28). `unfold/1` returns a non-recursive
%% type unchanged.
validator_form(Ty, Name, Table) ->
    Err = error_expr(Ty),
    Body = bs_types:unfold(Ty),
    Clauses = ty_clauses(Body, Name, Table, Err)
              ++ [{clause, ?A, [{var, ?A, '_'}], [], [Err]}],
    Fn = {function, ?A, Name, 2,
          [{clause, ?A, [?VV, ?VP], [], [{'case', ?A, ?VV, Clauses}]}]},
    [Fn | walker_form(Body, Name, Table, Err)].

%% The single site that builds a `ValidationError`; the path is carried
%% reversed everywhere else so this is one `lists:reverse/1` per failure
%% rather than an append per step.
error_expr(Ty) ->
    {tuple, ?A,
     [{atom, ?A, error},
      {tuple, ?A, [{call, ?A, {remote, ?A, {atom, ?A, lists}, {atom, ?A, reverse}},
                    [?VP]},
                   bin_str(bs_types:to_string(Ty))]}]}.

ok_expr() -> {tuple, ?A, [{atom, ?A, ok}, ?VV]}.

ty_clauses(Ty, Name, Table, Err) ->
    #{atoms := As, ints := Is, tuples := Ts, maps := Ms,
      bins := Bs} = Ty,
    atom_clauses(As)
    ++ int_clauses(Is)
    ++ bin_clauses(lists:sort(Bs), Err)
    ++ tuple_clauses(Ts, Table, Err)
    ++ list_clauses(Ty, Name)
    ++ map_clauses(Ms, Table, Err).

atom_clauses({finite, Atoms}) ->
    [{clause, ?A, [{atom, ?A, A}], [], [ok_expr()]} || A <- Atoms];
%% A cofinite atom part such as `atom \ :ok` has no finite spelling, so it is
%% tested as `is_atom/1` minus the exclusions (ticket 10).
atom_clauses({cofinite, Excluded}) ->
    Tests = [guard_call(is_atom, [?VV])
             | [{op, ?A, '=/=', ?VV, {atom, ?A, E}} || E <- Excluded]],
    [{clause, ?A, [{var, ?A, '_'}], [Tests], [ok_expr()]}].

int_clauses(Ranges) -> [int_clause(R) || R <- Ranges].

int_clause({Lo, Hi}) ->
    Tests = [guard_call(is_integer, [?VV])]
            ++ [{op, ?A, '>=', ?VV, {integer, ?A, Lo}} || is_integer(Lo)]
            ++ [{op, ?A, '=<', ?VV, {integer, ?A, Hi}} || is_integer(Hi)],
    {clause, ?A, [{var, ?A, '_'}], [Tests], [ok_expr()]}.

%% `string` is `binary` refined by valid UTF-8, so the binary part is a subset
%% of {valid, invalid} and each inhabited value gets the membership check its
%% meaning requires; this establishes for a term from outside what a literal
%% establishes at compile time (ticket 20 §4).
bin_clauses([], _Err) -> [];
bin_clauses([other, utf8], _Err) ->
    [{clause, ?A, [{var, ?A, '_'}], [[guard_call(is_binary, [?VV])]], [ok_expr()]}];
bin_clauses([utf8], Err) ->
    [{clause, ?A, [{var, ?A, '_'}], [[guard_call(is_binary, [?VV])]],
      [utf8_case(ok_expr(), Err)]}];
bin_clauses([other], Err) ->
    [{clause, ?A, [{var, ?A, '_'}], [[guard_call(is_binary, [?VV])]],
      [utf8_case(Err, ok_expr())]}].

%% A list from `unicode:characters_to_list/2` is the only success; `error` and
%% `incomplete` tuples both fall to the second clause.
utf8_case(Valid, Invalid) ->
    UV = {var, ?A, 'Bs@u'},
    {'case', ?A,
     {call, ?A, {remote, ?A, {atom, ?A, unicode}, {atom, ?A, characters_to_list}},
      [?VV, {atom, ?A, utf8}]},
     [{clause, ?A, [UV], [[guard_call(is_list, [UV])]], [Valid]},
      {clause, ?A, [{var, ?A, '_'}], [], [Invalid]}]}.

tuple_clauses(top, _Table, _Err) ->
    [{clause, ?A, [{var, ?A, '_'}], [[guard_call(is_tuple, [?VV])]], [ok_expr()]}];
tuple_clauses(Products, Table, Err) ->
    [tuple_case(C, Table, Err) || C <- tuple_cases(Products)].

%% A single candidate descends with exact blame. `Fixed`, the discriminating
%% position when there was one, goes in the pattern as a literal, which keeps
%% the clauses disjoint and saves a call.
tuple_case({one, Fixed, P}, Table, _Err) ->
    Slots = [slot(I, Fixed, C, "Bs@c") || {I, C} <- indexed(P)],
    Steps = [{C, V, bin_str("(" ++ integer_to_list(I) ++ ")")}
             || {{I, C}, V} <- lists:zip(indexed(P), Slots),
                I =/= Fixed, checked(C)],
    {clause, ?A, [{tuple, ?A, Slots}], [], [chain(Steps, Table, 1)]};
%% Several candidates are each tried, and the blame stays at this node with
%% its whole type as the expectation; descending into a guessed candidate
%% would be blame tracking, which nothing has decided.
tuple_case({alts, Ps}, Table, Err) ->
    Wilds = [{var, ?A, '_'} || _ <- hd(Ps)],
    {clause, ?A, [{tuple, ?A, Wilds}], [],
     [alternatives([bs_types:tuple(P) || P <- Ps], Table, Err)]}.

%% The discriminating slot is matched literally; everything else is a name, or
%% `_` where nothing checks it.
slot(Slot, Slot, Ty, _Prefix) ->
    {tag, A} = tag_of(Ty),
    {atom, ?A, A};
slot(Slot, _Fixed, Ty, Prefix) -> component_var(Prefix, Slot, Ty).

list_clauses(Ty, Name) ->
    case {bs_types:has_nil(Ty), bs_types:has_cons(Ty)} of
        {false, false} -> [];
        {true, false}  -> [nil_clause()];
        {Nil, true}    -> [nil_clause() || Nil] ++ [cons_clause(Name)]
    end.

nil_clause() -> {clause, ?A, [{nil, ?A}], [], [ok_expr()]}.

%% A cons matches `[_|_]` rather than `is_list/1`, which is true of an improper
%% list; the walker decides properness on the way down, where the tail is
%% visible.
cons_clause(Name) ->
    EV = {var, ?A, 'Bs@le'},
    {clause, ?A, [{cons, ?A, {var, ?A, '_'}, {var, ?A, '_'}}], [],
     [{'case', ?A,
       {call, ?A, {atom, ?A, walker_name(Name)}, [?VV, {integer, ?A, 0}, ?VP]},
       [{clause, ?A, [{atom, ?A, ok}], [], [ok_expr()]},
        {clause, ?A, [{tuple, ?A, [{atom, ?A, error}, EV]}], [],
         [{tuple, ?A, [{atom, ?A, error}, EV]}]}]}]}.

walker_form(Ty, Name, Table, Err) ->
    Elem = bs_types:list_elem(Ty),
    case bs_types:is_none(Elem) of
        true  -> [];
        false ->
            case checked(Elem) of
                true  -> [walker(Name, maps:get(Elem, Table), Err)];
                false -> [walker(Name, none, Err)]
            end
    end.

%% The element index is the one path segment computed at run time, since the
%% list's length is not a compile-time fact.
walker(Name, Sub, Err) ->
    W  = walker_name(Name),
    IV = {var, ?A, 'Bs@i'},
    TV = {var, ?A, 'Bs@t'},
    HV = {var, ?A, 'Bs@h'},
    {HeadPat, Step} =
        case Sub of
            none ->
                {{cons, ?A, {var, ?A, '_'}, TV},
                 {call, ?A, {atom, ?A, W}, [TV, IV, ?VP]}};
            VName ->
                EV = {var, ?A, 'Bs@we'},
                {{cons, ?A, HV, TV},
                 {'case', ?A,
                  {call, ?A, {atom, ?A, VName},
                   [HV, {cons, ?A, index_segment(IV), ?VP}]},
                  [{clause, ?A, [{tuple, ?A, [{atom, ?A, ok}, {var, ?A, '_'}]}], [],
                    [{call, ?A, {atom, ?A, W},
                      [TV, {op, ?A, '+', IV, {integer, ?A, 1}}, ?VP]}]},
                   {clause, ?A, [{tuple, ?A, [{atom, ?A, error}, EV]}], [],
                    [{tuple, ?A, [{atom, ?A, error}, EV]}]}]}}
        end,
    {function, ?A, W, 3,
     [{clause, ?A, [{nil, ?A}, {var, ?A, '_'}, {var, ?A, '_'}], [], [{atom, ?A, ok}]},
      {clause, ?A, [HeadPat, IV, ?VP], [], [Step]},
      %% An improper tail. The blame is the list, not an element of it.
      {clause, ?A, [{var, ?A, '_'}, {var, ?A, '_'}, ?VP], [], [Err]}]}.

index_segment(IV) ->
    {call, ?A, {remote, ?A, {atom, ?A, erlang}, {atom, ?A, iolist_to_binary}},
     [{cons, ?A, {integer, ?A, $[},
       {cons, ?A, {call, ?A, {remote, ?A, {atom, ?A, erlang},
                              {atom, ?A, integer_to_list}}, [IV]},
        {cons, ?A, {integer, ?A, $]}, {nil, ?A}}}}]}.

map_clauses(top, _Table, _Err) ->
    [{clause, ?A, [{var, ?A, '_'}], [[guard_call(is_map, [?VV])]], [ok_expr()]}];
map_clauses(Members, Table, Err) ->
    [map_case(C, Table, Err) || C <- map_cases(Members)].

map_case({one, Fixed, {Kind, Fs}}, Table, _Err) ->
    Pairs = [{K, maps:get(K, Fs)} || K <- lists:sort(maps:keys(Fs))],
    Slots = [map_slot(K, Fixed, T, I) || {I, {K, T}} <- indexed(Pairs)],
    Pat   = {map, ?A, [{map_field_exact, ?A, {atom, ?A, K}, V}
                       || {{K, _}, V} <- lists:zip(Pairs, Slots)]},
    Steps = [{T, V, bin_str([$. | atom_to_list(K)])}
             || {{K, T}, V} <- lists:zip(Pairs, Slots),
                K =/= Fixed, checked(T)],
    {clause, ?A, [Pat], closed_guard(Kind, length(Pairs)),
     [chain(Steps, Table, 1)]};
map_case({alts, Ms = [{Kind, Fs} | _]}, Table, Err) ->
    Keys = lists:sort(maps:keys(Fs)),
    Pat  = {map, ?A, [{map_field_exact, ?A, {atom, ?A, K}, {var, ?A, '_'}}
                      || K <- Keys]},
    {clause, ?A, [Pat], closed_guard(Kind, length(Keys)),
     [alternatives([member_ty(M) || M <- Ms], Table, Err)]}.

map_slot(Key, Key, Ty, _I) ->
    {tag, A} = tag_of(Ty),
    {atom, ?A, A};
map_slot(_Key, _Fixed, Ty, I) -> component_var("Bs@f", I, Ty).

%% A closed map member rejects an extra key with a `map_size/1` guard, since
%% `#{a := _}` alone would accept it (ticket 26 §4).
closed_guard(closed, N) ->
    [[{op, ?A, '=:=', {call, ?A, {atom, ?A, map_size}, [?VV]}, {integer, ?A, N}}]];
closed_guard(open, _N) ->
    [].

%% Each step validates one child under an extended path, and the first failure
%% is returned unchanged, so the deepest blame wins.
chain([], _Table, _N) -> ok_expr();
chain([{SubTy, Value, Segment} | Rest], Table, N) ->
    EV = {var, ?A, list_to_atom("Bs@e" ++ integer_to_list(N))},
    {'case', ?A,
     {call, ?A, {atom, ?A, maps:get(SubTy, Table)},
      [Value, {cons, ?A, Segment, ?VP}]},
     [{clause, ?A, [{tuple, ?A, [{atom, ?A, ok}, {var, ?A, '_'}]}], [],
       [chain(Rest, Table, N + 1)]},
      {clause, ?A, [{tuple, ?A, [{atom, ?A, error}, EV]}], [],
       [{tuple, ?A, [{atom, ?A, error}, EV]}]}]}.

%% Each candidate is tried and its blame discarded in favour of this node's: a
%% failed alternative's path describes a shape the value was never claimed to
%% have.
alternatives([], _Table, Err) -> Err;
alternatives([Ty | Rest], Table, Err) ->
    {'case', ?A, {call, ?A, {atom, ?A, maps:get(Ty, Table)}, [?VV, ?VP]},
     [{clause, ?A, [{tuple, ?A, [{atom, ?A, ok}, {var, ?A, '_'}]}], [], [ok_expr()]},
      {clause, ?A, [{tuple, ?A, [{atom, ?A, error}, {var, ?A, '_'}]}], [],
       [alternatives(Rest, Table, Err)]}]}.

%% A component nobody checks gets `_` rather than a name, so a `term` field
%% raises no unused-variable warning.
component_var(Prefix, I, Ty) ->
    case checked(Ty) of
        true  -> {var, ?A, list_to_atom(Prefix ++ integer_to_list(I))};
        false -> {var, ?A, '_'}
    end.

indexed(L) -> lists:zip(lists:seq(1, length(L)), L).

bin_str(S) ->
    {bin, ?A, [{bin_element, ?A, {string, ?A, lists:flatten(S)}, default, default}]}.

guard_call(F, Args) -> {call, ?A, {atom, ?A, F}, Args}.

%% First-appearance order, so the emitted module is stable across runs.
group_by(KeyFun, Items) ->
    lists:foldl(fun(I, Acc) ->
                        K = KeyFun(I),
                        case lists:keyfind(K, 1, Acc) of
                            false   -> Acc ++ [{K, [I]}];
                            {K, Is} -> lists:keyreplace(K, 1, Acc, {K, Is ++ [I]})
                        end
                end, [], Items).

%%% ---------------------------------------------------------------------------
%%% Serialisation
%%%
%%% The forms are written as text, which `erlc +from_abstr` builds with no
%%% `.erl` on disk and no in-process compiler state (ticket 13).
%%% ---------------------------------------------------------------------------

%% The `coding: latin-1` line is required. `~p` prints a list of printable
%% bytes as a quoted string of those bytes, and `erlc` reads source as UTF-8
%% by default, so without it `"héllo"` would round-trip as five bytes instead
%% of six, with the program compiling and returning the wrong binary. Fixing
%% the boundary covers every non-ASCII form, not only strings (F9).
to_abstr(Forms) ->
    iolist_to_binary(["%% coding: latin-1\n"
                      | [io_lib:format("~p.~n", [F]) || F <- Forms]]).
