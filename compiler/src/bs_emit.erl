%%% Lowering to the Erlang Abstract Format — ticket 13's target.
%%%
%%% Ticket 13 chose the Abstract Format over Core Erlang, and the decisive reason
%%% was that it is a **one-way door, not a rung on a ladder**: `.abstr -> Core` is
%%% `erlc +from_abstr +to_core` and free, while `.core -> abstract forms` is
%%% unrecoverable. The emission contract is a *sequence of abstract-format forms*,
%%% with a standing obligation that the frontend never depend on in-process
%%% compiler state — which is what frees the compiler's host language, and which
%%% this module honours by producing plain terms and nothing else.
%%%
%%% Two things ticket 13 requires that show up here:
%%%
%%%   * **A `-spec` for every function whose type is known**, widened to the
%%%     nearest expressible supertype where a set-theoretic type has no Erlang
%%%     spelling. `spec_type/1` is that widening.
%%%
%%%     CORRECTED 2026-08-13, measured: the widening is observable through
%%%     **`-Wspecdiffs` only**. Ticket 13 §6 and an earlier version of this
%%%     comment both said `-Wunderspecs`/`-Wspecdiffs`, and `-Wunderspecs` can
%%%     never see it — not as a corpus artefact but *by construction*. Dialyzer
%%%     classifies a spec as a whole, and ticket 04 made signatures mandatory, so
%%%     every spec we emit has a domain **narrower** than the `_` success typing
%%%     infers while its range may be wider. Narrower somewhere and wider
%%%     elsewhere is neither supertype nor subtype, so it lands in "not equal",
%%%     which `-Wunderspecs` does not report. Verified: a hand-written
%%%     `same_dom(any()) -> atom()` fires `-Wunderspecs`; `narrow_dom(integer())
%%%     -> atom()` does not, and beam-sharp is always the second shape.
%%%
%%%   * **Nothing emitted for the failure arm.** Ticket 12 decided to retain it
%%%     and ticket 13 then found the decision was not ours to make on this target:
%%%     `erlc` inserts the `match_fail` arm and it cannot be suppressed. So the
%%%     honest crash comes free, and `20f` verifies it is actually there.

-module(bs_emit).

-export([forms/1, to_abstr/1]).

-define(A, 0).

%%% ---------------------------------------------------------------------------
%%% Naming.
%%%
%%% PROVISIONAL. The map's fog patch "Module and namespace system, and function
%%% identity" owes the real answer — whether a module identifier lowers to a bare
%%% snake_cased atom (risking collision with Erlang modules) or to something
%%% prefixed as Elixir's `Elixir.` is. Ticket 10 §3 deliberately did not decide it.
%%%
%%% This slice preserves the source name exactly and quotes it, because that is
%%% the only lossless option and therefore the one that pre-empts the decision
%%% least. `Readings` emits module `'Readings'` with function `'Classify'`, called
%%% from Erlang as `'Readings':'Classify'(X)`.
%%% ---------------------------------------------------------------------------

forms(Module = #{module := Mod, functions := Fns, env := Env}) ->
    %% F12 / ticket 40 §3. A private function is still emitted, still `-spec`'d
    %% and still named by a crash — it is simply not in the export list, which is
    %% the BEAM's only mechanism for the distinction and the reason the marker
    %% goes no further than this line.
    Exports = [{F, arity(F)} || F <- Fns, is_public(F)],
    Behaviours = maps:get(behaviours, Module, []),
    %% The behaviours travel in the emit context because a function name is not
    %% self-describing: whether `HandleCall/3` lowers to `handle_call/3` depends
    %% on what the MODULE declares. Ticket 35's contract scoping, carried.
    %% F18. Built once for the whole module and consulted at every call site, so
    %% two `ValidateAs<Order>` share one generated function rather than emitting
    %% the identical traversal twice.
    Validators = validator_table(Fns, Env),
    %% F19 / ticket 15 §4. The counter behind the wrapper's synthesised names,
    %% reset once per module so the emitted forms do not depend on what this OS
    %% process emitted before them.
    reset_foreign_wrappers(),
    Ctx = #{module => Mod, env => Env, behaviours => Behaviours,
            imports => maps:get(imports, Module, #{}),
            qmods => maps:get(qmods, Module, #{}),
            validators => Validators,
            remote_names => maps:get(remote_names, Module, #{}),
            %% Which foreign calls are owed a `try`. Decided in `bs_check`,
            %% where the declaration is; looked up here and nowhere else.
            foreigns => maps:get(foreigns, Module, #{})},
    %% F15 / ticket 13 §3 — WHICH `.bs` A CRASH NAMES.
    %%
    %% A module is a directory now, so one `.beam` holds functions written in
    %% several files, and without this every one of them reports against the
    %% aggregate. `13b` measured the repair on this exact target: a repeated
    %% `{attribute, ANNO, file, {Name, Line}}` re-points every form after it,
    %% which is the mechanism Elixir and LFE use to attribute generated code back
    %% to original source, and the Abstract Format path inherits it for free.
    %%
    %% The line in the tuple names the file only; each form's OWN annotation
    %% supplies the line, so the numbers are exact. `13b` recorded why that
    %% matters — the generated-Erlang-source route achieves the same effect with
    %% `-file` directives, but a directive occupies the line it names and every
    %% number becomes arithmetic.
    %%
    %% Until this feature there was NO file attribute anywhere in the emitter,
    %% while a comment further down this file said ticket 13 "keeps per-file
    %% `file` attributes precisely so crashes point at the right `.bs`". It
    %% described an intention. This is the code.
    Files = maps:get(files, Module, [{undefined, Fns}]),
    [{attribute, ?A, module, Mod},
     {attribute, ?A, export, [{name(F, Behaviours), A} || {F, A} <- Exports]}]
    ++ [{attribute, ?A, behaviour, bs_otp:behaviour_name(B)} || B <- Behaviours]
    ++ lists:append([file_group(Path, Fs, Env, Behaviours, Ctx)
                     || {Path, Fs} <- Files])
    %% The generated validators go last and carry no `file` attribute of their
    %% own: they belong to no `.bs`, and pointing them at one would be a lie the
    %% next crash would tell. Nothing in them can crash — every branch returns a
    %% value — so no stack frame ever names them.
    ++ validator_forms(Validators).

%% `undefined` is the one-source callers (`compile_string/2`, the REPL) that have
%% no path to attribute to. Emitting an attribute naming nothing would be worse
%% than emitting none.
file_group(undefined, Fns, Env, Behaviours, Ctx) ->
    lists:append([[spec_attr(F, Env, Behaviours), function(F, Ctx)] || F <- Fns]);
file_group(Path, Fns, Env, Behaviours, Ctx) ->
    [{attribute, ?A, file, {Path, 1}}
     | lists:append([[spec_attr(F, Env, Behaviours), function(F, Ctx)]
                     || F <- Fns])].

%% THE ONE PLACE A B# FUNCTION NAME BECOMES AN ERLANG ONE.
%%
%% Four sites need it — the export list, the `-spec`, the function definition and
%% every local call — and they must agree or the module exports a name nothing
%% defines. Ticket 35's table is consulted here and nowhere else so they cannot
%% drift apart.
name(F, Behaviours) -> emitted_name(element(2, F), arity(F), Behaviours).

%% THE ONE PLACE A CROSS-MODULE CALL IS BUILT — the remote sibling of `name/2`,
%% and it exists for the same reason. The callee's emitted name is looked up in
%% the CALLEE's contract, which `bs_check` recorded while checking it; falling
%% back to the written name is right for every module that declares no behaviour.
remote(L, Mod0, Fn, As, C) ->
    %% A short name from the namespace tier becomes the full dotted path here,
    %% through the table the CHECKER built. Two sources of truth for this would
    %% be two chances to disagree, and the one that disagrees silently is the
    %% emitter — a wrong module atom is `undef` at run time, not a type error.
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
%% F12, amended 2026-08-17: PRIVATE IS THE DEFAULT, so the test is `=:= public`
%% and not `=/= private`. Written the other way it would export every unmarked
%% function — which is the old rule surviving in a predicate after the rule it
%% implemented was reversed, and nothing would have reported it.
is_public(F) -> element(7, F) =:= public.       % #fn.vis

%%% ---------------------------------------------------------------------------
%%% Functions and clauses
%%%
%%% The one structural move the language rests on: N clause heads in the parameter
%%% position become N native Erlang clause heads. Ticket 01 verified by hand that
%%% five beam-sharp clauses produce five clause heads in the compiled beam's
%%% abstract_code chunk; this is the compiler doing what that lowering did.
%%% ---------------------------------------------------------------------------

function(F, Ctx) ->
    Name = name(F, maps:get(behaviours, Ctx, [])),
    Arity = arity(F),
    Params = element(5, F),                     % #fn.params
    Clauses = element(6, F),                    % #fn.clauses
    %% F24 — visibility reaches the clause because ticket 18 §4 scopes the type
    %% test to the EXPORTED function. It is read here rather than in `clause/4`
    %% because this is the only place the `#fn` record is in scope; the clause
    %% sees a boolean and does not learn the record's shape.
    Public = is_public(F),
    {function, ?A, Name, Arity, [clause(C, Params, Ctx, Public) || C <- Clauses]}.

%% A beam-sharp clause may name a parameter it does not use — `(:ok, n) -> :negative`
%% is idiomatic, and the name is documentation. Erlang warns about exactly that, so
%% a variable the body and guard never mention lowers to `_`-prefixed. Found by
%% running the emitter rather than by reading it: the first end-to-end build
%% produced two spurious "variable 'N' is unused" warnings.
clause({clause, Line, _Name, Patterns, Guard, Body}, Params, Ctx, Public) ->
    %% Relational patterns are lowered FIRST, before the boundary guard runs.
    %% Order matters and the reason is `ensure_var/3`: given a pattern it cannot
    %% name, it wraps the whole thing in a `p_alias`, and an aliased `p_rel` would
    %% then reach `pattern/2`, which has no clause for one — a crash rather than a
    %% diagnostic. Stripping first means the boundary guard only ever sees a
    %% variable, which it already knows what to do with.
    %%
    %% F22 DESUGARS BEFORE ALL OF IT, AND ADDS NO CASE TO `pattern/2`.
    %% `p_rec` becomes the `p_map` this module already lowers, with the minted
    %% tag filled in; `p_bind` becomes the `p_alias` it already lowers. Doing it
    %% here rather than in `pattern/2` is forced, and usefully so: resolving the
    %% tag needs `Ctx`, which carries `env`, while `pattern/2` is handed only the
    %% used-variable set. Same place and same reason `record_tag/2` reads the
    %% environment for the boundary guard.
    Desugared = [desugar(P, Ctx) || P <- Patterns],
    {Patterns0, RelTests} = strip_rels(Desugared),
    %% The boundary guard is injected BEFORE `Used` is computed. It mentions the
    %% parameter variable, so a parameter the body never names would otherwise
    %% lower to `_Foo` and the guard would reference an underscored variable —
    %% which is not a warning but a compile error in the emitted Erlang. The
    %% relational tests are in the same list for the same reason: they mention
    %% `bs@rN`, and that name exists nowhere but in the head they came from.
    {Patterns1, Tests} = boundary_guards(Patterns0, Params, Line, Ctx, Public),
    %% F24 — THE BOUNDARY TESTS LEAD, which is ticket 58's own stated shape:
    %% *"`is_integer/1` first, then the residual comparisons"*. Not a
    %% correctness requirement, because a comparison in a guard cannot crash and
    %% `andalso` would reach the type test either way — it is the order the two
    %% halves compose in once ticket 46's range residual lands beside this one,
    %% and it short-circuits a wrong-kind term on one test rather than three.
    Guard1 = conjoin(Tests ++ RelTests, Guard, Line),
    %% F8 — a `== acc` READS `acc`, and it reads it from a PATTERN rather than
    %% from the body or the guard, which is the only place `used_vars/2` looks.
    %% Without this seed, a parameter mentioned nowhere but in another parameter's
    %% `== acc` lowers to `_Acc` while the match lowers to `Acc`, and the emitted
    %% Erlang fails to compile with `variable 'Acc' is unbound` — against a file
    %% the author never wrote. Identical in shape to the arm-body hazard
    %% `used_vars/2` already documents below, arriving from the one direction that
    %% walk cannot see.
    Read = lists:append([matched_vars(P) || P <- Patterns1]),
    Used = lists:foldl(fun sets:add_element/2,
                       used_vars(Body, guard_vars(Guard1)), Read),
    {clause, Line,
     [pattern(P, Used) || P <- Patterns1],
     guard(Guard1, Ctx),
     body_exprs(Body, Ctx)}.

%%% ---------------------------------------------------------------------------
%%% Bodies — ticket 34's bindings
%%%
%%% An Erlang clause body is already a SEQUENCE and `{match, …}` is an ordinary
%%% form, so a binding needs no block, no `begin`, and nothing new in the
%%% emission contract. Measured before building: `f(O) -> B = O + 1, B * 2` and
%%% a destructuring `{A, B} = P` both compile and run through `compile:forms/2`.
%%% Keeping the body a flat list rather than wrapping it in a `{block, …}` also
%%% keeps the last expression in tail position, which ticket 13's tail-call test
%%% asserts on.
%%% ---------------------------------------------------------------------------

body_exprs({e_block, _, Binds, Final}, Ctx) ->
    binds(Binds, Final, Ctx) ++ [expr(Final, Ctx)];
body_exprs(E, Ctx) ->
    [expr(E, Ctx)].

binds([], _Final, _Ctx) -> [];
binds([{bind, L, Name, E} | Rest], Final, Ctx) ->
    %% A bound name nothing later mentions lowers to `_`-prefixed, for the same
    %% reason a parameter does: Erlang warns about it otherwise, and the warning
    %% would be about a variable the author did write, unlike the parameter case.
    %% Kept rather than rejected — binding a name to say what a value IS is a
    %% legitimate reason to write one, and ticket 23 puts the reader first.
    Later = later_vars(Rest, Final),
    Var = case sets:is_element(Name, Later) of
              true  -> var_name(Name);
              false -> list_to_atom([$_ | atom_to_list(var_name(Name))])
          end,
    [{match, L, {var, L, Var}, expr(E, Ctx)} | binds(Rest, Final, Ctx)];
%% A destructuring bind — F5, site 5. The checker has already proved it cannot
%% fail, so this is the same `{match, …}` with a pattern on the left and needs
%% nothing the emitter did not already have: `pattern/2` is what a clause head
%% is lowered through.
%% `pattern/2` already takes the used-variable set and underscores a name
%% nothing reads, which is the same rule a plain binding applies above — so a
%% destructuring bind needs no new lowering, only the set it is judged against.
binds([{dbind, L, P, E} | Rest], Final, Ctx) ->
    [{match, L, pattern(P, later_vars(Rest, Final)), expr(E, Ctx)}
     | binds(Rest, Final, Ctx)].

later_vars(Rest, Final) ->
    lists:foldl(fun(B, A) -> used_vars(element(4, B), A) end,
                used_vars(Final, sets:new([{version, 2}])), Rest).

%%% ---------------------------------------------------------------------------
%%% The boundary guard — ticket 18 §1, reaching records
%%%
%%% Ticket 26 §1 allocates two tiers and this emits the first. The TAG test is
%%% unconditional on an exported record parameter, because no body ever checks
%%% which record a map claims to be — a body projects fields, so it cannot
%%% object, which is exactly 18's test for where the free check is absent. The
%%% exact-field-set test is the second tier and is emitted only where a codegen
%%% obligation consumes the record; none exists yet, so its absence here is the
%%% correct observation rather than a gap. Measured in 26a at +14 bytes, flat in
%%% field count, against the +29 ticket 18 feared.
%%%
%%% Two deliberate narrowings, and they are limits rather than principles:
%%%
%%%   * only where the declared type is a SINGLE closed record. A union of
%%%     records would need a disjunction over tags, which is a different shape
%%%     and is not what F3.9 asserts.
%%%   * not where the clause's own pattern already constrains `Kind`, since the
%%%     head then performs the identical test and a second one is dead weight.
%%%     This is 18's "only where the function's own body would not object", in
%%%     miniature and decidable by reading one pattern.
%%% ---------------------------------------------------------------------------

boundary_guards(Patterns, Params, Line, Ctx, Public) ->
    Zipped = lists:zip3(Patterns, Params, lists:seq(1, length(Patterns))),
    Folded = [guard_one(P, Param, I, Line, Ctx, Public) || {P, Param, I} <- Zipped],
    {[NewP || {NewP, _} <- Folded],
     [T || {_, Ts} <- Folded, T <- Ts]}.

%% The two guards are mutually exclusive by construction rather than by an
%% ordering choice: a record type has a `maps` part and an integer type does
%% not, so no parameter is ever a candidate for both.
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
%%% F24 / TICKET 58 — the kind half, which is ticket 18 §1 rule C case (b)
%%%
%%% `Classify(100.5)` returned `:reserved` from a parameter published as
%%% `0..255`. 18 decided this on 2026-08-13 and §5 refused an opt-out; the rule
%%% was never in the emitter, which is why 58 is a defect and not a question.
%%%
%%% A COMPARISON IS NOT A TYPE TEST, and that is the whole reason this cannot be
%%% derived from ticket 46's range subtraction. `100.5 >= 9` is true, so the
%%% float reaches the `Classify(>= 9)` clause; 46's residual for that clause is
%%% `=< 255`, and `100.5 =< 255` is true as well. A range-only fix makes `300.5`
%%% crash and leaves `100.5` answering — the reported defect, unmoved, behind a
%%% green test. Comparisons order the numeric tower; only `is_integer/1` closes
%%% it. The two are one guard in two halves and this is the first.
%%%
%%% EXPORTED ONLY, by 18 §4: the analysis is function-local and looks at the
%%% exported function's own head. A private function's every call site is a
%%% checked beam-sharp call site, so site 1 has already rejected the
%%% out-of-domain argument. Note this does NOT match the record tag guard above,
%%% which is emitted on private functions too — ticket 46 measured that and
%%% called it the record guard's business against 18 §4 rather than this
%%% ticket's, so the asymmetry is inherited deliberately and left in place.
%%%
%%% SCOPED TO THE NUMERIC KIND CHANNEL. An `atom` or `binary` parameter is the
%%% same rule with a different test and is OWED, not decided differently. `int`
%%% is built first because it is 18 §1(b)'s own worked example and the type the
%%% corpus actually publishes a refinement of.
%%% ---------------------------------------------------------------------------

int_guard(Pat, TypeExpr, I, Line, Ctx) ->
    case is_int_only(TypeExpr, Ctx) andalso not pins_integer(Pat) of
        false -> {Pat, []};
        true  ->
            {Var, Pat1} = ensure_var(Pat, I, Line),
            {Pat1, [int_test(Var, Line)]}
    end.

%% Every part but the integer one empty, and the integer one inhabited. A
%% refinement is a SUBSET of `int` rather than a type beside it (ticket 20 §5),
%% so `Octet` and `int` arrive here as the same shape with different ranges and
%% neither is special-cased. A union like `int | :none` is NOT int-only and gets
%% nothing: its atom part is a second admissible kind, and refusing it here is
%% 18(d)'s conservative direction rather than a gap.
is_int_only(TypeExpr, #{env := Env}) ->
    try bs_check:resolve(TypeExpr, Env) of
        #{ints := Is, atoms := {finite, []}, tuples := [], lists := [],
          maps := [], bins := []} when Is =/= [] -> true;
        _ -> false
    catch _:_ -> false
    end.

%% Ticket 18 §1(a) — the head already objects, so nothing is emitted. An integer
%% literal in a clause head IS the objection: `Only(1)` does not match `1.0`,
%% which the suite asserts rather than assumes.
%%
%% A RELATIONAL PATTERN IS ABSENT FROM THIS LIST ON PURPOSE, and it is the case
%% the whole feature turns on. `strip_rels/1` has already run by the time this
%% is reached, so `Classify(>= 9)` arrives as a bare `p_var` and is correctly
%% found not to pin anything. Were it still a `p_rel` here, the temptation would
%% be to call it constrained — and it is not, because a comparison orders.
%%
%% `p_or` needs BOTH sides and `p_and` needs only one: a disjunction is only as
%% pinned as its weakest arm, while a conjunction is pinned if any arm pins it.
pins_integer({p_int, _, _})        -> true;
pins_integer({p_alias, _, _, P})   -> pins_integer(P);
pins_integer({p_and, _, A, B})     -> pins_integer(A) orelse pins_integer(B);
pins_integer({p_or, _, A, B})      -> pins_integer(A) andalso pins_integer(B);
pins_integer(_)                    -> false.

%% An ordinary surface node, like `tag_test/3` beside it, so `used_vars/2` and
%% `expr/2` handle it by the paths they already have. `erlang:is_integer/1` is a
%% guard BIF and is legal in a guard as a remote call — the same shape the tag
%% test already relies on for `erlang:map_get/2`.
int_test(Var, Line) ->
    {e_foreign_call, Line, erlang, is_integer, [{e_var, Line, Var}]}.

%% A single closed map member carrying a singleton `Kind`. Anything else — a
%% union, a bare `term`, an anonymous map without a tag — is not a record
%% parameter for this purpose.
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

%% `desugar/2` runs before this, so a `p_rec` never reaches here — it has already
%% become a `p_map` carrying the minted `Kind`, which this then sees. The
%% `p_alias` clause matters though: a bound record pattern still constrains the
%% tag, and without it the boundary guard would emit a SECOND, redundant tag
%% test against a variable that already matched one.
constrains_kind({p_map, _, Fields}) -> lists:keymember('Kind', 1, Fields);
constrains_kind({p_alias, _, _, P}) -> constrains_kind(P);
constrains_kind(_)                  -> false.

%% F22 / TICKET 55 — the two new pattern nodes become two the emitter already
%% lowers, and `pattern/2` gains nothing.
%%
%% `p_rec` -> `p_map` with the minted tag prepended. The tag is read back out of
%% the resolved type by `record_tag/2` rather than re-minted here, so this cannot
%% drift from `bs_check:qualified/2`.
%%
%% `p_bind` -> `p_alias`, which is Erlang's `Var = Pattern` and has been in this
%% module since the boundary guard needed it. That node is the entire runtime
%% story of the trailing binder; the feature is surface over it.
%%
%% THE RECURSION IS THE PART THAT WOULD BE MISSED. 25c's own shape is
%% `(Frame { Type: :method } f, rest)` — nested inside a tuple — so a desugar
%% that only looked at the top of each parameter would compile the exemplar's
%% line to something that never matches.
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

%% A wildcard has nothing to test against, so one is introduced. `@` keeps the
%% synthesised name out of the source's variable grammar, which is lowercase
%% alphanumerics — so it cannot collide with anything a user wrote.
ensure_var({p_wild, L}, I, _Line) ->
    V = list_to_atom("bs@" ++ integer_to_list(I)),
    {V, {p_var, L, V}};
ensure_var(P = {p_var, _, V}, _I, _Line) ->
    {V, P};
ensure_var(P, I, Line) ->
    %% A structural pattern already binds the shape; the tag still needs a name
    %% to be read from, so the whole pattern is aliased.
    V = list_to_atom("bs@" ++ integer_to_list(I)),
    {V, {p_alias, Line, V, P}}.

%% Emitted as ordinary surface nodes rather than abstract format, so that
%% `used_vars/2` and `expr/2` handle it by the paths they already have.
tag_test(Var, Tag, Line) ->
    {e_op, Line, '==',
     {e_foreign_call, Line, erlang, map_get,
      [{e_atom, Line, 'Kind'}, {e_var, Line, Var}]},
     {e_atom, Line, Tag}}.

%%% ---------------------------------------------------------------------------
%%% Relational patterns — ticket 42, lowered to what a guard would have produced
%%%
%%% `Classify(>= 4 and <= 7)` becomes `classify(Bs@r1) when Bs@r1 >= 4 andalso
%%% Bs@r1 =< 7`. Nothing downstream learns a new shape, which is 42's own claim
%%% for the construct: *"identical to what a guard would have produced, so
%%% nothing downstream changes."*
%%%
%%% ONE VARIABLE PER RELATIONAL SUBTREE, not per test. `>= 4 and <= 7` constrains
%%% a single value twice — the combinator is not structural — so both tests must
%%% name the same variable or the head would match two different things and mean
%%% neither.
%%%
%%% `@` keeps the synthesised name out of the source's variable grammar, which is
%%% lowercase alphanumerics, so it cannot collide with anything a user wrote. Same
%%% convention `ensure_var/3` already uses, and the same reason.
%%%
%%% Only the TOP of each argument is walked, because the checker refuses a
%%% relational pattern anywhere else (`argument_position/2`) and refuses it as an
%%% error, so nesting never reaches emission. When a later feature lifts that
%%% restriction it must come back here — which is why the restriction is enforced
%%% in one named function rather than assumed in two places.
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

%% Emitted as ordinary surface nodes rather than abstract format, so `used_vars/2`
%% and `expr/2` handle them by the paths they already have — the same trick
%% `tag_test/3` uses one section up.
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
%% F18. The type arguments are types; only the value argument holds variables.
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
%% Descending into arms is not optional and the failure is not a warning. A
%% parameter read ONLY inside an arm body would otherwise look unused, lower to
%% `_N` in the clause head, and the arm body would then emit `N` — which is a
%% compile ERROR in the emitted Erlang, against a file the author did not write.
%% Same shape as F1's spurious-warning finding, one degree worse.
%%
%% Arm-bound names are added along with everything else, and cannot pollute the
%% decision they are not part of: an arm may not rebind a name already in scope,
%% so no arm variable is ever the head variable being judged.
used_vars({e_switch, _, Subject, Arms}, Acc) ->
    lists:foldl(fun({arm, _, _, G, Body}, A) ->
                        used_vars(Body, sets:union(A, guard_vars(G)))
                end, used_vars(Subject, Acc), Arms);
%% F14. Same walk, same stakes as the switch above and for the same reason: this
%% one enumerates and falls through to `Acc`, so a parameter read only inside a
%% valve stage would look unused, lower to `_N` in the clause head, and then be
%% referenced by the emitted `case` — a compile error in a file the author did
%% not write.
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
%% `:=` rather than `=>`: a map pattern in Erlang is exact-key by construction,
%% and matching a key the term has not got fails the clause, which is the
%% `function_clause` ticket 12's failure arm is there to produce.
pattern({p_map, L, Fields}, U) ->
    {map, L, [{map_field_exact, L, {atom, L, K}, pattern(P, U)} || {K, P} <- Fields]};
%% Introduced by the boundary guard when the head is structural and the tag
%% still needs a name to be read from — and, since F22, by every trailing binder
%% a user writes.
%%
%% THE NAME GOES THROUGH `pattern/2`'S OWN `p_var` CLAUSE RATHER THAN BEING
%% BUILT HERE, so an unused binder underscores exactly as an unused parameter
%% does. Writing `{var, L, var_name(V)}` directly is what this used to do, and
%% F22.10 caught it: `Which(Method { Channel: 7 } f) -> :seven` emitted Erlang
%% that warned `variable 'F' is unused` on a clause the author wrote correctly.
%% 25c's file is full of that shape, so every clause in it would have warned.
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
%% F8 — `== acc` lowers to the VARIABLE ITSELF, and nothing else. A bound
%% variable repeated in an Erlang pattern *is* an equality test, so the target
%% does the whole job: no guard is emitted, no comparison, no temporary.
%%
%% Which is the joke at the centre of this feature. B# needs a token here only
%% because it forbids rebinding and so cannot use Erlang's own rule; the token
%% buys back a capability the runtime never lost. Elixir spends `^` on the same
%% purchase.
%%
%% Never underscore-prefixed — it is by definition a use, and `Used` is seeded
%% with these names in `clause/3` so the BINDER is not underscored either.
pattern({p_eqvar, L, V}, _Used) -> {var, L, var_name(V)};
%% F13 — a binary pattern lowers one segment to one `bin_element`, which is the
%% whole of the codegen. Nothing is synthesised and no guard is emitted: the
%% BEAM's binary matching already does everything ticket 30's answer asks for,
%% including the sub-byte widths that no language in its survey type-checks.
%%
%% `default` as a type-specifier list means unsigned big-endian INTEGER, which is
%% what a width-N segment is and what `bs_check:seg_type/1` inferred
%% `range(0, 2^N - 1)` from. The two agree because they are both reading the same
%% platform default, not because they were written to match.
pattern({p_bin, L, Segs}, U) ->
    {bin, L, [segment(S, U) || S <- Segs]};
%% A string literal in pattern position IS a binary pattern with one string
%% segment — ticket 30 §4's "byte-string singleton", which turns out to be
%% literally true at the abstract-format level.
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
%% The variable itself, which is why `bs_check` insists it was bound EARLIER in
%% the same pattern: Erlang reads a binary pattern left to right and an unbound
%% size here is legal, compiles, and simply never matches.
seg_size(L, {sized_by, V})    -> {var, L, var_name(V)}.

%% `binary` carries unit 8, so a `sized_by` segment counts BYTES — which is what
%% every length-prefixed wire format means by its length field, and what 25c's
%% AMQP frame and 25b's WebSocket payload both need.
seg_size_of({seg_bind, _, _, Size}) -> Size;
seg_size_of({seg_wild, _, Size})    -> Size;
seg_size_of(_)                      -> rest.

seg_tsl(rest)         -> [binary];
seg_tsl({sized_by, _}) -> [binary];
seg_tsl({width, _})   -> default.

%% Every name a pattern reads. The emitter's own copy on purpose: `pattern_vars`
%% in the checker answers what a pattern BINDS, and the two must not be one
%% function that guesses which question it was asked.
matched_vars({p_eqvar, _, V})          -> [V];
%% F13 — a segment's SIZE is a name being read, and seeding `Used` with it is
%% what stops the binder being underscored. `<<size:8, payload:size, rest>>`
%% would otherwise emit `_Size` at the binder and `Size` at the use, and `erlc`
%% would meet an unbound variable in a file the author never wrote — F4's rule,
%% and the failure would look like a codegen bug rather than a naming one.
matched_vars({p_bin, _, Segs})         ->
    [V || S <- Segs, {sized_by, V} <- [seg_size_of(S)]];
matched_vars({p_tuple, _, Ps})         -> lists:append([matched_vars(P) || P <- Ps]);
matched_vars({p_map, _, Fs})           -> lists:append([matched_vars(P) || {_, P} <- Fs]);
matched_vars({p_alias, _, _, P})       -> matched_vars(P);
matched_vars({p_list, _, Items, Rest}) ->
    lists:append([matched_vars(P) || P <- Items])
        ++ case Rest of nil -> []; R -> matched_vars(R) end;
matched_vars(_)                        -> [].

%% beam-sharp variables are lowercase-initial; Erlang's must be uppercase-initial.
%% Capitalising the first character is injective over the source's variable
%% grammar, so no two distinct names can collide, and the emitted name stays
%% readable in a crash report — which matters, because ticket 13 keeps per-file
%% `file` attributes precisely so crashes point at the right `.bs`.
var_name(V) ->
    [H | T] = atom_to_list(V),
    list_to_atom([string:to_upper(H) | T]).

%%% ---------------------------------------------------------------------------
%%% Expressions
%%% ---------------------------------------------------------------------------

expr({e_int, L, N}, _C)       -> {integer, L, N};
expr({e_atom, L, A}, _C)      -> {atom, L, A};
%% The bytes are already UTF-8-encoded — the lexer read them from the source and
%% validated them there — so this emits them raw and adds no `/utf8` specifier.
%% Re-encoding would double-encode every non-ASCII character, which is invisible
%% in an ASCII test and is why F9.3 exists.
expr({e_str, L, Bytes}, _C)   ->
    {bin, L, [{bin_element, L, {string, L, Bytes}, default, default}]};
expr({e_var, L, V}, _C)       -> {var, L, var_name(V)};
expr({e_tuple, L, Es}, C)     -> {tuple, L, [expr(E, C) || E <- Es]};
%% THE FOURTH NAMING SITE, and the one that fails silently if it disagrees with
%% the other three. A beam-sharp function calling `HandleCall(...)` inside a
%% `GenServer` module must emit `handle_call(...)`, because that is what the
%% export list and the definition now say. Get this wrong and the module compiles
%% and calls a function it does not have.
%% F11 — AN UNQUALIFIED CALL MAY BE A REMOTE ONE, and the emitter does not decide
%% which. 41 §2: "the resolution happens at check time, never at run time", so the
%% table consulted here is the one `bs_check` already built and returned. Deciding
%% it a second time here would be the second resolver `resolve/2` was exported to
%% prevent.
expr({e_call, L, F, As}, C)   ->
    Arity = length(As),
    case maps:get({F, Arity}, maps:get(imports, C, #{}), undefined) of
        undefined ->
            Name = emitted_name(F, Arity, maps:get(behaviours, C, [])),
            {call, L, {atom, L, Name}, [expr(A, C) || A <- As]};
        Mod ->
            remote(L, Mod, F, As, C)
    end;

%% F18 — the call site of a codegen obligation, and it is a bare local call with
%% no arguments beyond the term. The type argument was consumed at generation
%% time (27 §8) and nothing about it survives here, which is the whole difference
%% between a codegen obligation and a generic call.
expr({e_inst, L, 'ValidateAs', [TypeExpr], [Arg]}, C) ->
    Ty = bs_check:resolve(TypeExpr, maps:get(env, C)),
    {_Roots, Table} = maps:get(validators, C),
    {call, L, {atom, L, root_name(maps:get(Ty, Table))}, [expr(Arg, C)]};

%% `List.Map(xs)`. The module atom is already the full dotted path (40 §1), which
%% is why nothing here has to build a name: `'Shop.Orders'` is what the dependency
%% emitted and what `ls` shows.
expr({e_qcall, L, Mod, Fn, As}, C) ->
    remote(L, Mod, Fn, As, C);
expr({e_op, L, Op, A, B}, C)  -> {op, L, erl_op(Op), expr(A, C), expr(B, C)};
expr({e_nil, L}, _C)          -> {nil, L};

%% Ticket 26 §1: a record erases to a MAP carrying its minted tag. The tag is
%% ordinary data in the term, which is the whole reason a union of records is
%% dispatched by an ordinary clause head — and the reason ticket 16's refusal of
%% protocols narrowed to *open* protocols once 26 landed.
expr({e_record, L, Name, Fields}, C = #{module := Mod}) ->
    Tag = bs_check:qualified(Mod, Name),
    {map, L,
     [{map_field_assoc, L, {atom, L, 'Kind'}, {atom, L, Tag}}
      | [{map_field_assoc, L, {atom, L, K}, expr(E, C)} || {K, E} <- Fields]]};

%% `o with { Total = 500 }` — width-preserving, and `:=` is what preserves it.
%% Updating a key the term has not got raises `badkey` rather than quietly
%% widening the record, so the field set cannot grow through this construct.
%% The tag is not re-minted: it is simply not among the keys being assigned.
expr({e_with, L, Base, Fields}, C) ->
    {map, L, expr(Base, C),
     [{map_field_exact, L, {atom, L, K}, expr(E, C)} || {K, E} <- Fields]};

%% One `map_get`. Guard-safe by construction, which is what lets the same node
%% serve the boundary tag test above.
expr({e_proj, L, V, Field}, _C) ->
    {call, L, {remote, L, {atom, L, erlang}, {atom, L, map_get}},
     [{atom, L, Field}, {var, L, var_name(V)}]};
%% A foreign call is an ordinary BEAM remote call — unless its declaration named
%% a failure channel, in which case F19 wraps it. The boundary guard §10 of
%% `LANGUAGE.md` describes is still NOT here: that is ticket 18's, over all eight
%% violation channels, and it is a synthesised traversal rather than four lines.
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

%% Ticket 17 §6 lowers to Erlang's own `case`, and needs nothing the emitter did
%% not already have: `pattern/2` is what a clause head goes through and an arm is
%% a one-pattern clause. The correspondence is the point — ticket 01 moved this
%% grammar out of switch arms and into the parameter position, so putting it back
%% lands on the construct Erlang always had underneath both.
%%
%% Nothing is emitted for the failure arm, for ticket 13's reason one level down:
%% the BEAM raises `case_clause` on a term no arm matches, exactly as it raises
%% `function_clause`, so ticket 12's retained failure arm comes free here too.
expr({e_switch, L, Subject, Arms}, C) ->
    {'case', L, expr(Subject, C), [arm(A, C) || A <- Arms]};
%% F14. The marker has done its work by the time emission runs — it existed to
%% keep `bs_check` from advising the author about arms `bs_lower` chose — so here
%% it is simply unwrapped. Ticket 17 §7's "a `|?>` chain emits a `case` per stage"
%% is satisfied by the switch inside, with no emitter machinery of its own.
expr({e_valve, _, Switch}, C) ->
    expr(Switch, C).

%%% ---------------------------------------------------------------------------
%%% F19 — the compiler-emitted foreign wrapper (ticket 15 §4, §5)
%%%
%%% ALL THREE CLASSES, and that is measured rather than cautious.
%%% [`15d`](../../wayfinder/prototypes/15d_which_classes_a_wrapper_catches.erl)
%%% ran the feared hazard — a wide `catch exit:` swallowing a supervisor's
%%% shutdown — and found it does not exist: a locally raised `exit/1` and an exit
%%% SIGNAL are different mechanisms sharing a keyword, and signals are not
%%% catchable at all, so cases 5-7 die through the wrapper regardless. Narrowing
%%% to `error:` would instead MISS `exit({noproc, ...})`, which is what
%%% `gen_server:call` to a dead process raises in the caller's own process and
%%% the commonest foreign failure on the platform.
%%%
%%% THE NAMES MUST BE UNIQUE PER CLAUSE, and this is a correctness requirement
%%% rather than hygiene. Measured with `erlc`: a second `catch C:R` in the same
%%% clause is `variable 'C' unsafe in 'try'` — a compile error, not a silent
%%% match — and one `try` nested in another's body is the same. F14 met this in
%%% `bs_lower` and solved it with a numbering walk; there is nothing to lower
%%% here, because the wrapper is invisible to the checker, so the counter lives
%%% at the emission site. Monotonic across one module's walk is enough:
%%% uniqueness within a CLAUSE is all Erlang requires, and a per-module counter
%%% delivers it with no scope tracking to get wrong.
%%%
%%% `bs@` keeps both names out of the source's variable grammar, which is
%%% lowercase alphanumerics — the convention `ensure_var/3`, the relational
%%% lowering and the valve already share.
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
    %% `(:error, (Class, Reason))` — the declared `result`'s failure member,
    %% carrying ticket 15 §5's `foreign_error`. The double `error` reads like a
    %% mistake and is not: the outer one is `result<T, E>`'s tag and the inner
    %% one is the exception CLASS, which is exactly the distinction 15 §5 kept
    %% the class for. `(:error, (:exit, (:noproc, _)))` is legible as "the callee
    %% is dead"; a flattened reason is not.
    {'try', L, [Call], [],
     [{clause, L, [{tuple, L, [Class, Reason, {var, L, '_'}]}], [],
       [{tuple, L, [{atom, L, error}, {tuple, L, [Class, Reason]}]}]}],
     []}.

wrapper_var(Prefix, N) -> list_to_atom(Prefix ++ integer_to_list(N)).

%% An arm takes the same relational lowering as a clause head, because it is the
%% clause head's own pattern grammar one level down — F7's whole argument for
%% `switch` being the only branching construct. `n switch { >= 5 => :high, ... }`
%% is a sentence the grammar admits the moment the head does.
%% F22 DESUGARS HERE TOO, AND FORGETTING IT WAS THE FEATURE'S ONE REAL BUG.
%% A switch arm does not travel through `clause/3`, so the desugar there does not
%% reach it and a `p_rec` would arrive at `pattern/2`, which has no clause for
%% one — a crash, not a diagnostic. Exemplar 25c's wall is a switch arm
%% (`consume.bs:20`), so the feature would have passed every clause-head test
%% and still not moved the thing it was built to move.
arm({arm, L, P, Guard, Body}, C) ->
    {[P1], RelTests} = strip_rels([desugar(P, C)]),
    Guard1 = conjoin(RelTests, Guard, L),
    Used = used_vars(Body, guard_vars(Guard1)),
    {clause, L, [pattern(P1, Used)], guard(Guard1, C), [expr(Body, C)]}.

%% Ticket 16 settled that `==` means `=:=`, and decided it on internal agreement
%% rather than familiarity: Erlang's `==` coerces through tuples, lists and map
%% *values* and then stops at map keys, while the clause head and `maps:get` do
%% not coerce at all. The exact spelling agrees with two constructs and disagrees
%% with none.
erl_op('==') -> '=:=';
erl_op('!=') -> '=/=';
erl_op('<=') -> '=<';                            % Erlang spells it the other way round
%% Ticket 44 spells the conjunction `and`, and it lowers to `andalso` rather than
%% to Erlang's own `and`. The two differ only in short-circuiting, which 44a
%% measured to be unobservable in guard context — a guard that raises simply
%% fails — so this picks the one that also behaves in expression position, where
%% the difference is real.
erl_op('and') -> 'andalso';
erl_op('or')  -> 'orelse';
erl_op(Op)   -> Op.                              % + - * < > >=

%%% ---------------------------------------------------------------------------
%%% Specs — ticket 13's widening rule, made concrete
%%% ---------------------------------------------------------------------------

spec_attr(F, Env, Behaviours) ->
    Params = element(5, F),
    Ret = element(4, F),
    ArgTypes = [spec_type(bs_check_resolve(T, Env)) || {param, T, _} <- Params],
    RetType = spec_type(bs_check_resolve(Ret, Env)),
    {attribute, ?A, spec,
     {{name(F, Behaviours), length(Params)},
      [{type, ?A, 'fun', [{type, ?A, product, ArgTypes}, RetType]}]}}.

%% This used to be a second copy of `bs_check:resolve/2`. Records made the
%% duplication untenable rather than merely ugly: ticket 26 §1's tag mints from
%% the qualified name, and a second resolver would have been a second place for
%% that rule to live and drift.
bs_check_resolve(T, Env) -> bs_check:resolve(T, Env).

%% Where a set-theoretic type has no Erlang spelling, widen to the nearest
%% supertype that does. A cofinite atom set is the clearest case: Erlang can say
%% `atom()` but cannot say "every atom except :ok", so the exclusion is dropped.
spec_type(Ty) ->
    case parts(Ty) of
        []  -> {type, ?A, none, []};
        [P] -> P;
        Ps  -> {type, ?A, union, Ps}
    end.

parts(Ty = #{atoms := As, ints := Is, tuples := Ts, maps := Ms,
             bins := Bs}) ->
    atom_parts(As) ++ [int_part(R) || R <- Is] ++ tuple_parts(Ts)
        ++ list_parts(Ty) ++ map_parts(Ms) ++ bin_parts(Bs).

%% All three non-empty points emit `binary()`, and that is this function's own
%% rule rather than a shortcut. Erlang's type language has no UTF-8 refinement,
%% so `string`, `binary` and `binary \ string` have one spelling between them and
%% the nearest supertype that exists is where they land.
%%
%% The widening is confined to the SPEC. Nothing above widens: the algebra keeps
%% the three apart exactly, which is what the checker reasons with. A spec is
%% what Dialyzer reads, and ticket 20's exactness requirement is about the
%% residual, not about the abstract chunk.
bin_parts([])  -> [];
bin_parts(_)   -> [{type, ?A, binary, []}].

%% Erlang's map type spells both halves of the distinction the algebra carries:
%% `:=` is a mandatory key and `=>` an optional one, so a closed member emits
%% all-mandatory and an open one adds `any() => any()` for the fields it does
%% not constrain. Nothing is widened to `map()`, which is what F3.12 asserts.
map_parts(top) -> [{type, ?A, map, any}];
map_parts(Members) -> [map_part(M) || M <- Members].

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

%% Erlang spells "list of T" and "non-empty list of T" but has no way to say
%% "either, with this element type" beyond the former, so a cons-only part
%% emits `nonempty_list(T)` and the pair emits `[T]`.
%% F20 — THE SPEC WIDENS HERE, DELIBERATELY AND FOR THE FIRST TIME.
%%
%% Erlang's type grammar has `nil`, `nonempty_list(T)` and `list(T)`, and no
%% fixed-length list at all: there is no way to write "exactly two ints". So a
%% residual the checker knows exactly — `[int]` — leaves as `nonempty_list()`
%% on the way into a `-spec`.
%%
%% This does not weaken anything the compiler proves. Exhaustiveness is decided
%% in `bs_check` against the spine, before any of this runs; a `-spec` is read
%% by Dialyzer as an upper bound on a success typing, so a wider one is honest
%% and a narrower one would be a lie. Ticket 20's no-widening rule governs the
%% ALGEBRA, which still does not widen — this is the boundary where the algebra
%% meets a target grammar that cannot say what it knows.
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

%% NOT DEAD, BUT NOT YET REACHABLE. Every branch below except the first is
%% unreachable from the current surface, and it is worth being precise about why
%% rather than deleting them or leaving it to be rediscovered.
%%
%% These read an interval out of a *declared* type. Ticket 20 put intervals in the
%% algebra and the checker genuinely uses them — it is what makes `math.bs`
%% exhaustive with no catch-all — but they only ever arise from a **guard**, and a
%% guard refines a clause rather than a signature. A parameter declared `int` is
%% `int` in the spec whatever its clauses test.
%%
%% The surface owes the syntax that would reach them: ticket 20 §5's guard
%% refinement, `type Positive = int where value > 0;`, which the parser does not
%% yet implement. That is the next slice increment, not a defect here.
%% Found by a teammate measuring emitter coverage for the OTP corpus.
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
%%% F18 — `ValidateAs<T>`, the generated deep validator
%%%
%%% Ticket 11 §2 put deep validation at an explicit call site rather than in a
%%% clause head, because the traversal is O(n·depth) and **the sender chooses n**.
%%% Ticket 15 §2 then amended its return type to `result<T, ValidationError>` —
%%% a path into the term plus the type expected there. This is where both are
%%% made executable.
%%%
%%% IT IS CODEGEN, NOT A CALL. Ticket 27 §8: `<T>` is a compile-time argument
%%% driving generation, monomorphic at every use site, with **no type variable
%%% surviving into the runtime or the algebra**. So nothing here dispatches on a
%%% type at run time and no type argument is passed anywhere — the emitted module
%%% holds one ordinary Erlang function per distinct `T`, and the call site is a
%%% local call to it.
%%%
%%% THE TRAVERSAL IS WRITTEN AGAINST THE ALGEBRA, NOT AGAINST THE SURFACE. A
%%% `bs_types:ty()` is a DNF **partitioned by constructor**, and the BEAM
%%% dispatches on constructor for free — so the atom part becomes atom clauses,
%%% the integer part becomes range guards, a tuple product becomes a tuple
%%% pattern and a closed map member becomes a map pattern plus `map_size/1`. One
%%% consequence worth naming: `option<int>` and a hand-written `int | :nothing`
%%% generate the *same* validator, because they are the same type by the time
%%% this module sees either — F6.3's property, one layer down.
%%%
%%% TERMINATION IS UPSTREAM, AND IT IS NOT PERMANENT. Ticket 09 committed to
%%% equirecursive contractive types and `bs_check:resolve/3` raises
%%% `{recursive_type, N}` for one today, so every `ty()` reaching here is a FINITE
%%% TREE and `close_over/2`'s worklist cannot cycle. When 09's machinery lands,
%%% this needs the name assigned to a type BEFORE its body is generated, or
%%% `Tree = :leaf | (:node, Tree, Tree)` recurses forever at compile time. The
%%% generated code itself already terminates: it walks a term, which is finite.
%%%
%%% TWO PROTOCOLS, AND THE SPLIT IS LOAD-BEARING. Internally every validator
%%% returns `{ok, V} | {error, {Path, Expected}}`; the ROOT wrapper unwraps that
%%% into what the language declared — `result<T, E>` is `T | (:error, E)`, an
%%% UNTAGGED success. Without the internal tagging a validator over a type that
%%% itself contains `(:error, _)` could not tell its own failure from a value it
%%% had just accepted.
%%% ---------------------------------------------------------------------------

-define(VV, {var, ?A, 'Bs@v'}).                 % the term under test
-define(VP, {var, ?A, 'Bs@p'}).                 % the path so far, reversed

%% Every distinct type any `ValidateAs<T>` in this module needs a validator for,
%% including the sub-types its traversal descends into. Keyed by the resolved
%% type, so two call sites naming the same type by different spellings share one
%% generated function — monomorphic AT every use site, which is 27 §8's
%% requirement, without emitting the identical traversal twice.
validator_table(Fns, Env) ->
    Roots = lists:usort([bs_check:resolve(TE, Env)
                         || {e_inst, _, 'ValidateAs', [TE], [_]} <- inst_nodes(Fns)]),
    {Roots, close_over(Roots, #{})}.

%% A generic walk rather than a per-node one: a `ValidateAs` may sit anywhere an
%% expression may, and a walk that had to be taught each new node would go stale
%% the first time one is added.
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

%% The sub-types this type's traversal will call a validator for. Two shapes
%% produce children: a component or field the descent enters, and — where a
%% constructor does NOT pick out a single candidate — each candidate as a type in
%% its own right, so the "try each, blame here" fallback is built from the same
%% generator rather than from a second one.
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
                      %% Sorted, and it is not cosmetic: `map_case/3` walks the
                      %% fields in sorted order too, and the worklist order is
                      %% what numbers the generated functions. Two orders would
                      %% mean two emitted modules for one source file.
                      {one, Fixed, {_, Fs}} -> [maps:get(K, Fs)
                                                || K <- lists:sort(maps:keys(Fs)),
                                                   K =/= Fixed,
                                                   checked(maps:get(K, Fs))];
                      {alts, Ms}            -> [member_ty(M) || M <- Ms]
                  end || Case <- map_cases(Members)]).

map_key({Kind, Fs})     -> {Kind, lists:sort(maps:keys(Fs))}.
member_ty({closed, Fs}) -> bs_types:map_closed(Fs);
member_ty({open, Fs})   -> bs_types:map_open(Fs).

%%% --- deciding where the descent is unambiguous ------------------------------
%%%
%%% ONE DECOMPOSITION, READ TWICE. `children/1` and the clause builders must
%%% agree exactly — a child nobody generates is a `badkey` at compile time, and a
%%% child generated for a step nobody takes is a dead function in every emitted
%%% module. So the decision about how a constructor's candidates are carved up
%%% lives in `tuple_cases/1` and `map_cases/1`, and both readers go through them.
%%%
%%% A case is `{one, Fixed, Candidate}` — this candidate is the only one that can
%%% match, and `Fixed` names the position or key whose literal sits in the
%%% pattern rather than being checked by a call — or `{alts, Candidates}`, where
%%% nothing structural chooses and the blame stays at this node.

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
    %% Closed members first. A closed member carries `map_size/1` and so cannot
    %% match a wider map; an open one has no such guard and would shadow a closed
    %% member listed after it. Declared types resolve to closed members only
    %% (26 §4), so this orders against a shape the surface cannot yet produce.
    Ordered = [M || M = {closed, _} <- Members] ++ [M || M = {open, _} <- Members],
    lists:append([shape_case(G) || {_, G} <- group_by(fun map_key/1, Ordered)]).

shape_case([M]) -> [{one, none, M}];
shape_case(Ms = [{_, Fs} | _]) ->
    Keys = lists:sort(maps:keys(Fs)),
    case discriminator(fun(K, {_, F}) -> maps:get(K, F) end, Keys, Ms) of
        none        -> [{alts, Ms}];
        {K, Tagged} -> [{one, K, M} || {_A, M} <- Tagged]
    end.

%% THE TAGGED UNION IS THE CASE THIS EXISTS FOR, and it is the idiomatic one on
%% this runtime: `(:ok, int) | (:error, atom)` has two products of the same
%% arity, so arity alone says "ambiguous" and the blame would land on the whole
%% union — when in fact the first component decides it outright. A union of
%% records is the same shape one constructor over, discriminated by the `Kind`
%% ticket 26 §1 mints.
%%
%% A slot discriminates when EVERY candidate has a distinct singleton atom there.
%% Every candidate, because one that does not would be shadowed by a sibling's
%% clause; distinct, because two candidates carrying the same tag are still two.
%% Anything weaker and a value inhabiting candidate B could be blamed against
%% candidate A, which is the guessing this design refuses.
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

%% NOTHING IS GENERATED FOR THE TOP. Every term inhabits `term`, so a validator
%% over it could only ever return `ok` — and the site that would have called one
%% simply does not. `ValidateAs<term>` itself never reaches here: ticket 15 §1's
%% collapse check refuses it at the call site.
checked(Ty) -> not bs_types:is_subtype(bs_types:term(), Ty).

validator_forms({Roots, Table}) ->
    Ordered = lists:sort(fun({_, A}, {_, B}) -> A =< B end, maps:to_list(Table)),
    lists:append([validator_form(Ty, Name, Table) || {Ty, Name} <- Ordered])
    ++ [root_form(maps:get(Ty, Table)) || Ty <- Roots].

%% The root wrapper — the only function a call site names. It converts the
%% internal `{ok, V}` protocol into the language's own `result<T, E>`, which is
%% `T | (:error, E)` with an untagged success (ticket 15 §2). Doing it here
%% rather than at the call site keeps the call site a bare call with no
%% variables in it, so two `ValidateAs` in one expression cannot collide.
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

root_name(Name)   -> list_to_atom(atom_to_list(Name) ++ "@r").
walker_name(Name) -> list_to_atom(atom_to_list(Name) ++ "@e").

validator_form(Ty, Name, Table) ->
    Err = error_expr(Ty),
    Clauses = ty_clauses(Ty, Name, Table, Err)
              ++ [{clause, ?A, [{var, ?A, '_'}], [], [Err]}],
    Fn = {function, ?A, Name, 2,
          [{clause, ?A, [?VV, ?VP], [], [{'case', ?A, ?VV, Clauses}]}]},
    [Fn | walker_form(Ty, Name, Table, Err)].

%% THE SINGLE SITE THAT BUILDS A `ValidationError`, which is why the path is
%% carried reversed everywhere else: one `lists:reverse/1` per failure rather
%% than an append per step.
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
%% The cofinite case is ticket 10's open atom universe: `atom \ :ok` has no
%% finite spelling, so it is tested as membership minus the exclusions.
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

%% TICKET 20 §4's MEMBERSHIP CHECK, WHICH `PRELUDE.md` HAS BEEN RECORDING AS
%% OWED. `string` is `binary` refined by valid UTF-8 — a SUBSET, not a second
%% type — so the part is a powerset of {valid, invalid} and each of its three
%% inhabited values gets the check its meaning requires. Until now a literal was
%% the only thing that could establish the property, and it did so at compile
%% time; this establishes it for a term that arrived from outside.
bin_clauses([], _Err) -> [];
bin_clauses([other, utf8], _Err) ->
    [{clause, ?A, [{var, ?A, '_'}], [[guard_call(is_binary, [?VV])]], [ok_expr()]}];
bin_clauses([utf8], Err) ->
    [{clause, ?A, [{var, ?A, '_'}], [[guard_call(is_binary, [?VV])]],
      [utf8_case(ok_expr(), Err)]}];
bin_clauses([other], Err) ->
    [{clause, ?A, [{var, ?A, '_'}], [[guard_call(is_binary, [?VV])]],
      [utf8_case(Err, ok_expr())]}].

%% `unicode:characters_to_list/2` answers with a list, or with `{error, _, _}` /
%% `{incomplete, _, _}`. The list is the only success, so it is the only clause
%% that needs naming.
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

%% A SINGLE CANDIDATE — the constructor has already chosen, so the descent is
%% unambiguous and blame is exact. `Fixed` is the discriminating position when
%% there was one: its literal goes in the pattern, which is both what makes the
%% clauses disjoint and what saves a call.
tuple_case({one, Fixed, P}, Table, _Err) ->
    Slots = [slot(I, Fixed, C, "Bs@c") || {I, C} <- indexed(P)],
    Steps = [{C, V, bin_str("(" ++ integer_to_list(I) ++ ")")}
             || {{I, C}, V} <- lists:zip(indexed(P), Slots),
                I =/= Fixed, checked(C)],
    {clause, ?A, [{tuple, ?A, Slots}], [], [chain(Steps, Table, 1)]};
%% SEVERAL — nothing structural chooses between them, so each is tried and the
%% blame stays at this node with this node's whole type as the expectation.
%% Descending into a guessed candidate would be blame tracking, which nothing has
%% decided.
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

%% `[_|_]` rather than a guard, because `is_list/1` is true of an IMPROPER list
%% and `[1|2]` inhabits no `list<T>`. The walker decides properness on the way
%% down, which is the only place the tail is visible.
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

%% The element index is the one path segment computed at RUN time, since the
%% length of the list is not a compile-time fact.
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

%% TICKET 26 §4 — a declared map type is CLOSED, so an extra key is a different
%% type and must be rejected. `#{a := _}` alone would accept it.
closed_guard(closed, N) ->
    [[{op, ?A, '=:=', {call, ?A, {atom, ?A, map_size}, [?VV]}, {integer, ?A, N}}]];
closed_guard(open, _N) ->
    [].

%% The descent. Each step validates one child under an extended path, and the
%% first failure is returned unchanged — the deepest blame wins because it is the
%% only one built.
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

%% Try each candidate; discard its blame and report this node's. Discarding is
%% the point — a failed alternative's path describes a shape the value was never
%% claimed to have.
alternatives([], _Table, Err) -> Err;
alternatives([Ty | Rest], Table, Err) ->
    {'case', ?A, {call, ?A, {atom, ?A, maps:get(Ty, Table)}, [?VV, ?VP]},
     [{clause, ?A, [{tuple, ?A, [{atom, ?A, ok}, {var, ?A, '_'}]}], [], [ok_expr()]},
      {clause, ?A, [{tuple, ?A, [{atom, ?A, error}, {var, ?A, '_'}]}], [],
       [alternatives(Rest, Table, Err)]}]}.

%% A component nobody checks gets `_` rather than a name, so the generated module
%% compiles without an unused-variable warning for every `term` field.
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
%%% Ticket 13's obligation that the frontend never depend on in-process compiler
%%% state is what makes this a *text* file rather than a term handed to `compile`:
%%% `erlc +from_abstr` builds from it with no `.erl` on disk, which is the fact
%%% that freed the host language.
%%% ---------------------------------------------------------------------------

%% THE CODING COMMENT IS LOAD-BEARING, AND F9 IS WHERE THAT WAS FOUND.
%%
%% `~p` prints a list of printable bytes as a quoted string and writes those
%% BYTES; `erlc` has read Erlang source as UTF-8 since OTP 17. So the `.abstr`
%% file was a serialisation boundary whose two ends disagreed, and a string
%% literal `"héllo"` round-tripped as five bytes instead of six — the `c3 a9`
%% pair read back as the single codepoint 233.
%%
%% Measured both ways before choosing: without this line the binary is 5 bytes,
%% with it 6. The alternative — emitting one `bin_element` per byte so no
%% character list is ever printed — fixes strings and leaves the identical trap
%% set for the next non-ASCII thing to reach a form, an atom with an accented
%% name being the obvious one. This fixes the boundary instead of one caller.
%%
%% It failed in the quiet direction: the program compiled, ran, and returned a
%% perfectly good binary that was the wrong one. Only a byte count showed it.
to_abstr(Forms) ->
    iolist_to_binary(["%% coding: latin-1\n"
                      | [io_lib:format("~p.~n", [F]) || F <- Forms]]).
