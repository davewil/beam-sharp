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

-export([check/1, check/2]).
%% F15 — the aggregate entry. `check/2` is now the one-source case of it, so the
%% declaration pass has one implementation rather than two that can drift.
-export([check_dir/2, check_dir/3]).
%% F11 — the import environment a dependent module is checked against. Built by
%% `bsc` from modules it has ALREADY checked in this invocation (41 §3, fork A:
%% the compiler re-checks the dependency's source and keeps its signatures).
-export([exports_of/1]).
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
-record(ctx, {types = #{}, callees = #{}, ret, fname, arity = 0, binds = #{},
              imports = #{}}).

%%% ---------------------------------------------------------------------------
%%% Entry point
%%% ---------------------------------------------------------------------------

%% Returns {ok, Module, [Diagnostic]} | {error, [Diagnostic]}.
check(Decls) -> check(Decls, #{}).

%% `World` maps a module atom to what checking it produced:
%%   #{'Shop.Orders' => #{exports => #{{Name, Arity} => {Params, Ret}},
%%                        behaviours => [atom()]}}
%% It is threaded by `bsc` rather than read from disk, which is 41 §3's fork A:
%% no artefact, nothing that can go stale, correct by construction.
check(Decls, World) ->
    case check_dir([{undefined, Decls}], World, undefined) of
        {ok, Module, Tagged} -> {ok, Module, [D || {_, D} <- Tagged]};
        {error, Tagged}      -> {error, [D || {_, D} <- Tagged]}
    end.

%%% ---------------------------------------------------------------------------
%%% F15 — checking an AGGREGATE: several files, one module
%%%
%%% Ticket 13 §3 makes the directory the unit of compilation, and the thing that
%%% must not be lost on the way is WHICH FILE a diagnostic came from.
%%%
%%% Concatenating every file's declarations and checking the result answers every
%%% typing question correctly and then reports each error against the wrong `.bs`.
%%% The reason is exact: a diagnostic is `{error, Line, FnName, Descriptor}` — a
%%% name and no arity — and ticket 40 §2 permits two arities of one name, which
%%% one-function-per-file then puts in two files. `examples/collections/List.bs`
%%% already has `Length/1` beside `Length/2`. A lookup keyed by name would point
%%% a human at the wrong file with every check green, which is this project's
%%% recorded worst failure shape.
%%%
%%% So the DECLARATION pass runs over the whole directory — one scope, which is
%%% what 41 §4's `index.bs` is for — and the FUNCTION pass runs per file. Each
%%% diagnostic then arrives already beside the path it belongs to, with no lookup
%%% to get wrong.
%%%
%%% `Expect` is the module atom the DIRECTORY PATH implies, or `undefined` for the
%%% callers that have no path at all (`check/2`, the REPL, `compile_string/2`).
%%% The path arithmetic lives in `bsc`, where `--src-root` is parsed; the refusal
%%% lives here, which is where 41 §5's compiler delta puts it.
%%% ---------------------------------------------------------------------------

check_dir(Sources, World) -> check_dir(Sources, World, undefined).

check_dir(Sources, World, Expect) ->
    Decls = lists:append([D || {_, D} <- Sources]),
    one_module_per_directory(Sources, Expect),
    [no_function_in_index(P, D) || {P, D} <- Sources],
    Env = type_env(Decls),
    Module = module_name(Decls),
    module_matches_path(Module, Sources, Expect),
    name_redeclared(Decls),
    PerFile = [{P, collect(D)} || {P, D} <- Sources],
    Fns = lists:append([F || {_, F} <- PerFile]),
    Imports = import_env(Decls, Module, World),
    Ctx = #ctx{types = Env, callees = callees(Decls, Env, Imports),
               imports = Imports},
    Tagged = lists:append(
               [[{P, D} || F <- Fs, {_, Ds} <- [check_fn(F, Ctx)], D <- Ds]
                || {P, Fs} <- PerFile]),
    case [D || {_, D} <- Tagged, element(1, D) =:= error] of
        []     -> {ok, #{module => Module, functions => Fns, env => Env,
                         %% F15 — what the emitter needs in order to put a
                         %% `{attribute, ANNO, file, …}` in front of each file's
                         %% functions, which is 13 §3's measured attribution.
                         files => PerFile,
                         behaviours => behaviours(Decls),
                         %% 41 §2: "the resolution happens at CHECK time, never
                         %% at run time". The emitter reads this table rather
                         %% than resolving a second time — the same reason
                         %% `resolve/2` is exported instead of copied.
                         imports => resolved_funs(Imports),
                         %% The namespace tier resolves a SHORT name to a full
                         %% module, and the emitter needs the same answer: the
                         %% atom it writes into the remote call is the full
                         %% dotted path, never the short spelling the author
                         %% used. Emitting the short one produced `undef` at run
                         %% time from a program the checker had passed.
                         qmods => resolved_mods(Imports),
                         %% F10's rule reaches across the module boundary: whether
                         %% `HandleCall/3` lowers to `handle_call/3` depends on
                         %% what the CALLEE declares, so a remote call needs the
                         %% callee's contract, not this module's. Without this a
                         %% qualified call to another module's callback emits a
                         %% name that module does not export — "compiles and calls
                         %% a function it does not have", which is the exact
                         %% failure `name/2`'s single funnel exists to prevent.
                         remote_names => remote_names(World)}, Tagged};
        _Fatal -> {error, Tagged}
    end.

%%% ---------------------------------------------------------------------------
%%% F15 — the three refusals a directory-shaped module adds
%%% ---------------------------------------------------------------------------

%% One directory is one module. Two files in `Shop/Orders/` declaring different
%% modules is not a program with two modules in it — it is a program whose author
%% believes files are modules, which they were until this feature.
%%
%% A file with NO `module` line inherits the directory's, and that is the common
%% case rather than a concession: one function per file (41 §4) means most files
%% sit beside an `index.bs` that has already named the module.
one_module_per_directory(_Sources, undefined) -> ok;
one_module_per_directory(Sources, _Expect) ->
    Declared = [{P, N, L} || {P, D} <- Sources, {module, L, N} <- D],
    case lists:usort([N || {_, N, _} <- Declared]) of
        []  -> erlang:error({no_module_declaration,
                             [P || {P, _} <- Sources, is_list(P)]});
        [_] -> ok;
        _   -> erlang:error({module_disagreement, lists:sort(Declared)})
    end.

%% Ticket 41 §4. `index.bs` holds everything except functions — an ERROR rather
%% than a convention, because an ungated convention decays exactly as the
%% exemplars' dead dialect and LANGUAGE.md's `true` claim did.
%%
%% A `foreign` declaration is a signature too, and it is deliberately caught:
%% 41 §4's argument is about `write_scope` contention, and a foreign declaration
%% attached to a name is as much a reason for two agents to collide as a native
%% one. The exception 41 §4 refuses to make is for FUNCTIONS, and a foreign
%% declaration is one.
no_function_in_index(Path, Decls) when is_list(Path) ->
    case filename:basename(Path) of
        "index.bs" ->
            case [{N, L} || {signature, L, N, _, _} <- Decls] of
                [{N, L} | _] -> erlang:error({function_in_index, N, L});
                []           -> ok
            end;
        _ -> ok
    end;
no_function_in_index(_Path, _Decls) -> ok.

%% Ticket 41 §5. A file's `module` declaration must match its DIRECTORY path.
%%
%% `Expect` arrives already computed, because the relative-path arithmetic needs
%% `--src-root` and that is a CLI concern. What is here is the comparison and the
%% refusal, which is where 41 §5's compiler delta puts them.
module_matches_path(_Module, _Sources, undefined) -> ok;
module_matches_path(Module, _Sources, Module) -> ok;
module_matches_path(Module, Sources, Expect) ->
    Line = case [L || {_, D} <- Sources, {module, L, N} <- D, N =:= Module] of
               [L | _] -> L;
               []      -> 1
           end,
    erlang:error({module_path_mismatch, Module, Expect, Line}).

%% The behaviours this module implements, checked for completeness — ticket 35 §3.
%%
%% BEFORE THIS, THE ATTRIBUTE WAS EMITTED FOR A CONTRACT THE MODULE COULD NEVER
%% SATISFY, and the consequence landed on the wrong desk: `erlc` and Dialyzer
%% reported three undefined callbacks against an emitted `.abstr` the author never
%% wrote. That is the same complaint F4 made about scope errors, and the same
%% answer applies — the compiler owns a diagnostic about the author's source.
%%
%% It is an ERROR at the declaration rather than a quietly-omitted attribute, and
%% three shipped precedents settle that rather than taste: `kind_field_is_minted`
%% errors at a declaration, a rebinding errors because a name means one thing, and
%% a cyclic alias is refused by name. Silently dropping the attribute would leave
%% a program whose `behaviour GenServer` line means nothing — the compiles-and-
%% means-something-else shape F7 was bitten by.
%%
%% Presence only. Ticket 14 §4's type containment is not owed here: Dialyzer
%% already does it at the boundary against OTP's own `-callback` declarations,
%% and it was measured before this was written — a narrowed callback spec is
%% accepted, a wrong one is still reported `Invalid type specification`.
behaviours(Decls) ->
    Defined = [{N, length(Ps)} || {signature, _, N, _, Ps} <- Decls],
    [begin
         case bs_otp:missing(N, Defined) of
             []      -> ok;
             Missing -> erlang:error({behaviour_not_satisfied, L, N, Missing})
         end,
         N
     end || {behaviour, L, N} <- Decls].

module_name(Decls) ->
    case [N || {module, _, N} <- Decls] of
        [N | _] -> N;
        []      -> 'Main'
    end.

%%% ---------------------------------------------------------------------------
%%% F11 — the module system
%%% ---------------------------------------------------------------------------

%% Ticket 40 §2's owed check. A name may carry MORE THAN ONE ARITY — that is the
%% BEAM's own identity rule and 40 §2 keeps it unmodified — so the duplicate is
%% {Name, Arity}, never Name.
%%
%% It fires BEFORE the exhaustiveness walk, and 40 §2 is explicit about why: the
%% checker otherwise merges two same-arity signatures into one N-clause function
%% and reports the later clauses as UNREACHABLE. That diagnostic reads as a remark
%% about the code when the truth is "you declared this function twice" — the same
%% costume F7's `true`/`false` misparse wore, where the only trace was an
%% unreachable-clause warning. The program was stopped either way; it was stopped
%% by `erlc` against an emitted `.abstr` the author never wrote.
name_redeclared(Decls) ->
    Sigs = [{{N, length(Ps)}, L} || {signature, L, N, _, Ps} <- Decls],
    Grouped = lists:foldl(fun({K, L}, Acc) ->
                                  maps:update_with(K, fun(Ls) -> [L | Ls] end, [L], Acc)
                          end, #{}, Sigs),
    case [{N, A, lists:min(Ls)} || {{N, A}, Ls} <- maps:to_list(Grouped), length(Ls) > 1] of
        []                  -> ok;
        [{N, A, L} | _]     -> erlang:error({name_redeclared, N, A, L})
    end.

%% What a checked module offers its dependents: every function it declares, keyed
%% by name and arity. Every function is public today — ticket 40 §3's
%% `public`/`private` is F12 — so this is the whole signature list, and the
%% filter this becomes when F12 lands is one comprehension guard.
exports_of(Decls) ->
    Env = type_env(Decls),
    maps:from_list([{{N, length(Ps)}, sig(Ps, R, Env)}
                    || {signature, _, N, R, Ps} <- Decls]).

%% The two tables 41 §5 asks for, plus the qualified one, from this module's
%% `using` lines and the modules already checked in this invocation.
%%
%%   funs : {Name, Arity} -> Module      module tier   — `using Shop.Orders`
%%   mods : Short         -> Module      namespace tier — `using Shop`
%%   qual : {q, Mod, Name, Arity} -> Sig  every reachable qualified callee
%%
%% 41 §5: "which table the import populates is decided by WHAT THE PATH RESOLVES
%% TO, not by its spelling" — so one grammar rule covers both tiers and the
%% classification happens here.
import_env(Decls, Self, World) ->
    Imports = [{L, M} || {import, L, M} <- Decls],
    Known = maps:keys(World),
    Local = [{N, length(Ps)} || {signature, _, N, _, Ps} <- Decls],
    lists:foldl(fun({L, M}, Acc) -> add_import(L, M, Self, World, Known, Local, Acc) end,
                #{funs => #{}, mods => #{}, qual => qual_table(World), imported => []},
                Imports).

add_import(L, M, Self, World, Known, Local, Acc) ->
    case maps:is_key(M, World) of
        true  -> add_module_import(L, M, World, Local, Acc);
        false ->
            %% Not a module. 41 §5: a path that is not itself a module but is a
            %% PREFIX of ones that are is a namespace — erased entirely, no atom,
            %% nothing emitted, purely compile-time name resolution.
            %%
            %% Self is excluded because a module sitting inside the namespace it
            %% imports is one of that namespace's children, and importing
            %% yourself is not a dependency.
            case children(M, Known) -- [Self] of
                []       -> erlang:error({unknown_module, M, L});
                Children -> add_namespace_import(M, Children, Acc)
            end
    end.

add_module_import(L, M, World, Local, Acc) ->
    Exports = maps:get(exports, maps:get(M, World)),
    Funs0 = maps:get(funs, Acc),
    %% 41 §2 requirement 2: an import shadowing a local name is an error, fixed
    %% by qualifying. NOT the analogy ticket 40 §2 refused — there `Fib/1` and
    %% `Fib/2` each have a perfectly defined meaning; here the unqualified name
    %% has NO defined meaning at all, which is what makes the same intuition
    %% load-bearing in one case and decorative in the other.
    case [K || K <- maps:keys(Exports), lists:member(K, Local)] of
        [{N, A} | _] -> erlang:error({import_shadows_local, N, A, M, L});
        []           -> ok
    end,
    Funs = maps:fold(fun(K, _Sig, F) ->
                             %% Ambiguity is recorded rather than raised here:
                             %% 41 §2 makes it an error AT THE CALL SITE, so an
                             %% unused collision is not an error at all.
                             maps:update_with(K, fun(Ms) -> [M | Ms] end, [M], F)
                     end, Funs0, Exports),
    Acc#{funs := Funs, imported := [M | maps:get(imported, Acc)]}.

add_namespace_import(Prefix, Children, Acc) ->
    Mods0 = maps:get(mods, Acc),
    Mods = lists:foldl(fun(Child, Ms) ->
                               Short = strip_prefix(Prefix, Child),
                               maps:update_with(Short, fun(L) -> [Child | L] end,
                                                [Child], Ms)
                       end, Mods0, Children),
    Acc#{mods := Mods, imported := Children ++ maps:get(imported, Acc)}.

%% Every module reachable by a qualified call, keyed so `call/6` can look one up
%% without a second code path.
qual_table(World) ->
    maps:fold(fun(M, #{exports := Ex}, Acc) ->
                      maps:fold(fun({N, A}, Sig, In) ->
                                        In#{{q, M, N, A} => Sig}
                                end, Acc, Ex)
              end, #{}, World).

%% Only names with exactly one source reach the emitter. An ambiguous one is an
%% error at its call site, so it must never be silently resolved here.
resolved_funs(Imports) ->
    maps:fold(fun(K, [M], Acc) -> Acc#{K => M};
                 (_, _,   Acc) -> Acc
              end, #{}, maps:get(funs, Imports, #{})).

resolved_mods(Imports) ->
    maps:fold(fun(K, [M], Acc) -> Acc#{K => M};
                 (_, _,   Acc) -> Acc
              end, #{}, maps:get(mods, Imports, #{})).

remote_names(World) ->
    maps:fold(fun(M, #{exports := Ex, behaviours := Bs}, Acc) ->
                      maps:fold(fun({N, A}, _Sig, In) ->
                                        case bs_otp:callback_name(N, A, Bs) of
                                            none -> In;
                                            Otp  -> In#{{M, N, A} => Otp}
                                        end
                                end, Acc, Ex)
              end, #{}, World).

children(Prefix, Known) ->
    P = atom_to_list(Prefix) ++ ".",
    [M || M <- Known, lists:prefix(P, atom_to_list(M))].

strip_prefix(Prefix, Child) ->
    P = atom_to_list(Prefix) ++ ".",
    list_to_atom(lists:nthtail(length(P), atom_to_list(Child))).

%%% ---------------------------------------------------------------------------
%%% Gathering signatures and their clauses
%%% ---------------------------------------------------------------------------

collect(Decls) ->
    %% A foreign declaration is FINISHED, not unfinished: it is a signature with
    %% no clauses that will never have any, so it must not be collected here or
    %% it reports `no_clauses`.
    Sigs = [#fn{name = N, line = L, ret = R, params = P}
            || {signature, L, N, R, P} <- Decls],
    %% BY NAME **AND ARITY**, which ticket 40 §2 forces. Keyed by name alone,
    %% `Length/1` collected `Length/2`'s clauses as well: the checker reported
    %% three unreachable clauses that were nothing of the kind, and the emitter
    %% then crashed in `boundary_guards/4` zipping a two-parameter signature
    %% against a one-argument head. Found by RUNNING the example rather than by
    %% the suite — the arity was never overloaded anywhere before this feature,
    %% so no test could have covered it.
    [F#fn{clauses = [C || C = {clause, _, Name, Ps, _, _} <- Decls,
                          Name =:= F#fn.name,
                          length(Ps) =:= length(F#fn.params)]}
     || F <- Sigs].

%% The callee environment — ticket 33 §6. `collect/1` above excludes foreign
%% declarations on purpose, and that exclusion is right for clause checking and
%% WRONG here: a foreign declaration is a signature attached to the name Erlang
%% already has (ticket 32), so its callees are declared exactly like any other
%% and site 1 applies to them verbatim. Local names key on the atom; foreign
%% ones on `{Module, Function}`, which is the pair `e_foreign_call` carries.
%% F11 KEYS EVERY CALLEE BY NAME **AND ARITY**, and that is ticket 40 §2 rather
%% than tidiness. Overloading is permitted — the BEAM's own identity rule,
%% unmodified — and the old `#{Name => Sig}` could not represent it: two arities
%% of one name went through `maps:from_list/1`, which keeps the rightmost, so
%% `Fib/1` beside `Fib/2` silently typed every call against whichever was written
%% last. Same shape as the duplicate type declaration the features README
%% specifies, one namespace along.
callees(Decls, Env, Imports) ->
    Local = [{{N, length(Ps)}, sig(Ps, R, Env)} || {signature, _, N, R, Ps} <- Decls],
    Foreign = [begin
                   admissible_foreign_ret(L, Mod, N, R, Env),
                   {{f, Mod, N, length(Ps)}, sig(Ps, R, Env)}
               end
               || {foreign, _, Mod, Sigs} <- Decls,
                  {foreign_sig, L, N, R, Ps} <- Sigs],
    maps:merge(maps:get(qual, Imports, #{}),
               maps:from_list(Local ++ Foreign)).

%% F9.11 — ticket 18 §2 made the admissible foreign return type set "what one
%% BEAM guard decides in O(1)", and ticket 20 §5 put `string` in the opaque tier
%% precisely because `valid_utf8` reads the content and no guard decides it.
%%
%% RETURN POSITION ONLY, and the asymmetry is the whole point. A parameter is a
%% value beam-sharp hands OUT to Erlang, already known to be a string by the
%% signature that produced it; nothing arrives and nothing needs establishing. A
%% return is a value arriving from a caller the checker has never seen, which is
%% ticket 21's foreign sender, and the UTF-8 property would have to be
%% established by the O(n) entry check this feature does not have.
%%
%% `binary` is admissible and is not an exception to the rule — 20 §3 measured
%% `byte_size/1` and `bit_size/1` as O(1) guard BIFs at 8 B and 8 MiB alike, so
%% the whole `<<_:M, _:_*N>>` grammar passes the same test that `string` fails.
admissible_foreign_ret(Line, Mod, Fun, Ret, Env) ->
    case opaque_refinement(resolve(Ret, Env)) of
        true  -> erlang:error({opaque_ret_at_boundary, Line, Mod, Fun});
        false -> ok
    end.

%% A proper non-empty subset of the binary part is a refinement of it, and
%% `string` is the only one today. Recursive, because 18 §2 says "anything
%% deeper is a compile error at the declaration" — `list<string>` hides the same
%% unbounded check one bracket down.
opaque_refinement(#{bins := Bs}) when Bs =/= [], Bs =/= [other, utf8] -> true;
opaque_refinement(#{tuples := top}) -> false;
opaque_refinement(#{tuples := Ps, lists := Ls, maps := Ms}) ->
    lists:any(fun opaque_refinement/1, lists:append(Ps))
        orelse (case Ls of
                    {_, E} when is_map(E) -> opaque_refinement(E);
                    _                     -> false
                end)
        orelse (case Ms of
                    top     -> false;
                    Members -> lists:any(
                                 fun({_, Fs}) ->
                                     lists:any(fun opaque_refinement/1,
                                               maps:values(Fs))
                                 end, Members)
                end).

sig(Params, Ret, Env) ->
    {[resolve(T, Env) || {param, T, _} <- Params], resolve(Ret, Env)}.

%%% ---------------------------------------------------------------------------
%%% Resolving surface types into the algebra
%%% ---------------------------------------------------------------------------

type_env(Decls) ->
    Mod = module_name(Decls),
    Aliases = [{N, alias(Params, T)} || {type_alias, _, N, Params, T} <- Decls],
    %% Ticket 20 §5's refinement. It enters the environment as a SURFACE node
    %% rather than pre-resolved, exactly as an alias body does, so it inherits
    %% `resolve/3`'s cycle guard for free — `type A = A where value > 0` is
    %% refused by name rather than spinning.
    Refined = [{N, {t_refined, L, Base, Pred}}
               || {type_refined, L, N, Base, Pred} <- Decls],
    Records = [{N, record_surface(Mod, L, N, Fs)}
               || {record_decl, L, N, Fs} <- Decls],
    Env = maps:merge(prelude(), maps:from_list(Aliases ++ Refined ++ Records)),
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
    bs_types:union([resolve(M, Env, Seen) || M <- Ms]);
%% TICKET 20 §5, AND THE POINT IS THAT IT ADDS NO NODE TO THE ALGEBRA. A
%% refinement is a SUBSET of its base, so it resolves to an ordinary type and
%% `is_subtype(Octet, int)` falls out rather than being asserted — the same shape
%% F6 has, where `option<int>` is gone before `bs_types` sees anything.
resolve({t_refined, Line, Base, Pred}, Env, Seen) ->
    refine(resolve(Base, Env, Seen), Pred, Line).

%% THE REFINEMENT AND THE GUARD GO THROUGH ONE TRANSLATOR, which is what makes
%% F2.5 true by construction rather than by test: a parameter declared `Octet`
%% and a clause guarded `when n > 128` cannot come to disagree about what
%% `>= 0 and <= 255` means, because `alternatives/1` is the only thing that reads
%% either of them.
%%
%% `value` is bound to the EMPTY PATH — the refinement's subject is the whole
%% type — which is the same address a switch arm's guard refines and the reason
%% `refine_at/3` grew its `[]` clause in F7. So this needs nothing new either.
%%
%% AN UNTRANSLATABLE PREDICATE IS AN ERROR, NOT A WIDENING, and that is the one
%% place this differs from a guard. A guard the checker cannot read credits
%% nothing and the clause simply subtracts less, which is sound. A *refinement*
%% the checker cannot read would resolve to its bare base and silently admit
%% ticket 20 §5's opaque tier — the tier 29 amended §5 to bar from clause heads
%% and foreign declarations, and this surface has no other site to check it at.
%% Failing quietly there would mean a `type Email = string where WellFormed(value)`
%% that means `string` and says nothing.
refine(Base, Pred, Line) ->
    case alternatives(Pred) of
        unknown -> erlang:error({opaque_refinement, Line});
        Alts ->
            Results = [refine_all(Base, #{value => []}, A) || A <- Alts],
            case lists:member(none_marker, Results) of
                %% `none_marker` here means the predicate named something other
                %% than `value`, which is the same mistake wearing a different
                %% hat: the compiler cannot read it, so it must not pretend to.
                true  -> erlang:error({opaque_refinement, Line});
                false ->
                    Refined = bs_types:union(Results),
                    case bs_types:is_none(Refined) of
                        %% `int where value > 0 and value < 0` is not a type with
                        %% no values in it by accident — it is a typo, and a
                        %% signature over it declares a function nothing can call.
                        true  -> erlang:error({empty_refinement, Line});
                        false -> Refined
                    end
            end
    end.

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
%% Ticket 20 §4. `string` is not a second type beside `binary` — it is `binary`
%% refined by valid UTF-8, so it resolves to a SUBSET and `string <: binary`
%% falls out of the algebra rather than being asserted here.
builtin(binary) -> bs_types:binary_top();
builtin(string) -> bs_types:string();
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
    {Bound, HeadDiags} = head_scope(Patterns, Line, Name),
    HeadDiags ++
    %% A guard is read in the scope of the CLAUSE HEAD alone — bindings come
    %% after it. Scanned here because F4's rule is that an unbound name is a
    %% `bsc` error, and a guard was the one place it still reached `erlc` as
    %% `variable 'X' is unbound` against a file the author did not write.
    guard_scope(Guard, Bound, Line, Name) ++ check_scope(Body, Bound, Name, Line, []).

%% F8.10 — A REPEATED BARE NAME IN A HEAD IS AN ERROR, AND UNTIL 2026-08-16 IT
%% WAS A SOUNDNESS HOLE.
%%
%% `F(acc, acc) -> :same` as the ONLY clause was accepted as exhaustive over
%% `(int, int)`, and `F(1, 2)` crashed with `function_clause`. A function the
%% compiler proved total, crashing on a value of its declared input type — the one
%% guarantee everything else rests on.
%%
%% The cause was a split between this checker's model and the emitted code.
%% `pattern_type/3` reads the second `acc` as a fresh `p_var`, so the clause looks
%% like it covers the whole domain; the emitter writes `_Acc` twice, and Erlang's
%% repeated-variable rule makes THAT a genuine equality test. So B# already had
%% pin-by-default in clause heads — by accident, through the emitter, with the
%% checker unaware. With a second clause it surfaced as `unreachable_clause`
%% pointing at the clause actually doing the work.
%%
%% The merge site is why it was invisible: `pattern_row/2` folds the per-parameter
%% binding maps with `maps:merge/2`, which silently keeps the rightmost duplicate.
%% That is the SAME mechanism as the duplicate type declaration `type_env/1` has
%% (`maps:from_list/1`, also rightmost) — one bug shape, two locations.
%%
%% Refusing it here rather than teaching `pattern_type/3` about repeats is what
%% ticket 45 settled: a bare name INTRODUCES, and `== name` is how you ask for the
%% match. So this reuses `rebinding`, whose message already says the right thing —
%% *a name means one thing in a clause* — one line lower in a body.
%%
%% A head is ONE simultaneous match, so `== acc` may name a parameter to its left
%% or its right. Order-independence is what the emitted Erlang does, and inventing
%% a left-to-right rule the target does not have would be a rule to be taught.
head_scope(Patterns, Line, Name) ->
    {Bound, Dups} =
        lists:foldl(
          fun(V, {B, A}) ->
                  case lists:member(V, B) of
                      true  -> {B, [{error, Line, Name, {repeated_in_head, V}} | A]};
                      false -> {[V | B], A}
                  end
          end, {[], []},
          lists:append([pattern_vars(P) || P <- Patterns])),
    %% `== acc` READS a name rather than introducing one, so it must resolve. In a
    %% head the only scope is the head itself.
    Refs = lists:append([pattern_matched_vars(P) || P <- Patterns]),
    Unbound = [{error, Line, Name, {unbound_variable, V}}
               || V <- lists:usort(Refs), not lists:member(V, Bound)],
    {Bound, Dups ++ Unbound}.

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
    %% F8 — the other half of the rule above. An arm may not REBIND a name in
    %% scope, and `== name` is now how it MATCHES one; so a `== name` naming
    %% something not in scope is the mirror error, and without this check it
    %% would reach `erlc` as `variable 'X' is unbound` against a file the author
    %% never wrote — F4's rule.
        ++ [{error, Line, Name, {unbound_variable, V}}
            || V <- lists:usort(pattern_matched_vars(P)),
               not lists:member(V, Bound ++ Vars)]
        ++ rebinds(Body, Inner, Name)
        ++ case Guard of none -> []; {guard, G} -> rebinds(G, Inner, Name) end.

pattern_vars({p_var, _, V})            -> [V];
pattern_vars({p_tuple, _, Ps})         -> lists:append([pattern_vars(P) || P <- Ps]);
pattern_vars({p_map, _, Fs})           -> lists:append([pattern_vars(P) || {_, P} <- Fs]);
pattern_vars({p_list, _, Items, Rest}) ->
    lists:append([pattern_vars(P) || P <- Items])
        ++ case Rest of nil -> []; R -> pattern_vars(R) end;
%% `p_eqvar` is deliberately absent: `== acc` MATCHES the value `acc` holds and
%% introduces nothing, so it contributes no binding. That is the whole distinction
%% ticket 45 chose the token to mark.
pattern_vars(_)                        -> [].

%% Every name a pattern READS — which today is exactly `== name`. Separate from
%% `pattern_vars/1` because the two answer opposite questions about the same
%% tree, and a pattern may do both: `F(k, { Kind: == k })` binds `k` and reads it.
pattern_matched_vars({p_eqvar, _, V})          -> [V];
pattern_matched_vars({p_tuple, _, Ps})         ->
    lists:append([pattern_matched_vars(P) || P <- Ps]);
pattern_matched_vars({p_map, _, Fs})           ->
    lists:append([pattern_matched_vars(P) || {_, P} <- Fs]);
pattern_matched_vars({p_list, _, Items, Rest}) ->
    lists:append([pattern_matched_vars(P) || P <- Items])
        ++ case Rest of nil -> []; R -> pattern_matched_vars(R) end;
pattern_matched_vars(_)                        -> [].

%% Every variable an expression READS. Deliberately not shared with the
%% emitter's `used_vars/2`, which answers a different question — whether to
%% underscore a name it is about to emit — and would drag a lowering concern
%% into the checker to save ten lines.
expr_vars({e_var, _, V})               -> [V];
expr_vars({e_proj, _, V, _})           -> [V];
expr_vars({e_tuple, _, Es})            -> lists:append([expr_vars(E) || E <- Es]);
expr_vars({e_call, _, _, As})          -> lists:append([expr_vars(A) || A <- As]);
expr_vars({e_foreign_call, _, _, _, As}) -> lists:append([expr_vars(A) || A <- As]);
expr_vars({e_qcall, _, _, _, As})        -> lists:append([expr_vars(A) || A <- As]);
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
%% Ticket 20 §4 — a literal is a `string` BY CONSTRUCTION. The lexer has already
%% established the UTF-8 property over the bytes, so this synthesises `string`
%% and not `binary`, and nothing downstream re-checks it.
type_of({e_str, _, _}, _S, _C) -> {bs_types:string(), []};
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
    call(L, unqualified_key(Name, length(Args), L, C), Name, Args, S, C);
%% Ticket 32 dissolved the foreign case before it was asked: a foreign
%% declaration is a signature attached to the name Erlang already has, so site 1
%% applies verbatim.
type_of({e_foreign_call, L, Mod, Fun, Args}, S, C) ->
    call(L, {f, Mod, Fun, length(Args)}, foreign_name(Mod, Fun), Args, S, C);
%% `List.Map(xs)` — 41 §1. The module is resolved through the namespace table
%% first, so `using Shop` + `Orders.Sum(o)` and `using Shop.Orders` +
%% `Shop.Orders.Sum(o)` reach the same callee by different spellings.
type_of({e_qcall, L, Mod0, Fun, Args}, S, C) ->
    Mod = qualified_module(Mod0, L, C),
    call(L, {q, Mod, Fun, length(Args)}, qualified_name(Mod, Fun), Args, S, C);
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
         end
        %% Ticket 12 §2 at the switch, for F7's own reason for existing: an arm
        %% is the clause head's pattern grammar one level down, so a rule about
        %% what a head may discard is a rule about what an arm may discard. A `_`
        %% arm over `Disposition` is the same defect as a `_` clause over it.
        ++ catch_all_diags({clause, AL, C#ctx.fname, [P], Guard, ignored},
                           Residual, AL, C#ctx.fname),
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
    %% A RELATIONAL PATTERN IS A CLAUSE HEAD'S, NOT A BIND'S. `var >= 4 = n`
    %% parses — a bind takes a `pattern` and a relational is one — and it is
    %% nonsense in every direction: it binds nothing, so there is no reason to
    %% write it, and a bind must be provably irrefutable (site 5) while a
    %% relational is the refutable construct par excellence.
    %%
    %% It is refused HERE and not left to the residual check, because the
    %% degenerate case where it IS irrefutable — `var >= 0 = n` over an `Octet` —
    %% would pass that check and reach the emitter, which has no guard to hang the
    %% test on and would crash on a pattern it cannot lower. A diagnostic stops
    %% emission entirely, so this closes the hole rather than narrowing it.
    RelDiags = case has_rel(P) of
                   true  -> [{error, L, C#ctx.fname, relational_in_bind}];
                   false -> []
               end,
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
    {maps:merge(S, Bound), D ++ D1 ++ D2 ++ RelDiags}.

%% Whether a pattern carries a relational anywhere. Structural on purpose: the
%% combinators are not, so `>= 4 and <= 7` has to be walked through rather than
%% matched at the top.
has_rel({p_rel, _, _, _})        -> true;
has_rel({p_and, _, A, B})        -> has_rel(A) orelse has_rel(B);
has_rel({p_or,  _, A, B})        -> has_rel(A) orelse has_rel(B);
has_rel({p_tuple, _, Ps})        -> lists:any(fun has_rel/1, Ps);
has_rel({p_map, _, Fs})          -> lists:any(fun({_, P}) -> has_rel(P) end, Fs);
has_rel({p_list, _, Items, Rest}) ->
    lists:any(fun has_rel/1, Items)
        orelse (Rest =/= nil andalso has_rel(Rest));
has_rel(_)                       -> false.

%% SITE 1 — the call argument, and ticket 26 §1's requirement David named:
%% reject `Update(Order o)` called with an `Invoice`.
call(L, Key, Shown, Args, S, C) ->
    {ATys, D} = type_of_all(Args, S, C),
    case maps:get(Key, C#ctx.callees, undefined) of
        undefined ->
            %% KEYING CALLEES BY ARITY MADE THIS A REAL FORK, and taking either
            %% side alone loses something. Ticket 40 §2 permits overloading, so
            %% `F/2` where only `F/1` exists is strictly speaking an unknown
            %% function — but reporting it that way throws away the fact that the
            %% author plainly meant the `F` sitting right there, which is what
            %% the old `arity_mismatch` said.
            %%
            %% So: unknown only when the NAME is unknown. When other arities
            %% exist, name them — the diagnostic then hands over the fix, which
            %% is ticket 04's property at a third site.
            case other_arities(Key, C#ctx.callees) of
                []    -> {reported(),
                          [{error, L, C#ctx.fname,
                            {unknown_callee, Shown, length(Args)}} | D]};
                [One] -> {reported(),
                          [{error, L, C#ctx.fname,
                            {arity_mismatch, Shown, length(Args), One}} | D]};
                Many  -> {reported(),
                          [{error, L, C#ctx.fname,
                            {arity_not_declared, Shown, length(Args),
                             lists:sort(Many)}} | D]}
            end;
        {Ps, Ret} when length(Ps) =/= length(ATys) ->
            {Ret, [{error, L, C#ctx.fname,
                    {arity_mismatch, Shown, length(ATys), length(Ps)}} | D]};
        {Ps, Ret} ->
            {Ret, arg_diags(L, Shown, Args, ATys, Ps, 1, C) ++ D}
    end.

%% Every arity declared for the callee the key names, whichever of the three
%% keyspaces it lives in — local, foreign, or another module's.
other_arities({N, _}, Callees) ->
    lists:sort([A || {Nm, A} <- maps:keys(Callees), Nm =:= N]);
other_arities({f, M, N, _}, Callees) ->
    lists:sort([A || {f, Mm, Nm, A} <- maps:keys(Callees), Mm =:= M, Nm =:= N]);
other_arities({q, M, N, _}, Callees) ->
    lists:sort([A || {q, Mm, Nm, A} <- maps:keys(Callees), Mm =:= M, Nm =:= N]).

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

%% 41 §2's resolution order, stated there as "local, then imports".
%%
%% A LOCAL WINS OUTRIGHT and never reaches the ambiguity rule, because a clash
%% between a local and an import was already refused at the `using` line by
%% `add_module_import/5`. So by the time a call is resolved, an unqualified name
%% is either local or imported, never both.
unqualified_key(Name, Arity, L, C) ->
    Key = {Name, Arity},
    case maps:is_key(Key, C#ctx.callees) of
        true  -> Key;
        false ->
            case maps:get(Key, maps:get(funs, C#ctx.imports, #{}), []) of
                []    -> Key;          %% unknown: `call/6` reports it
                [M]   -> {q, M, Name, Arity};
                %% 41 §2 requirement 1: NOT a silent winner. A quiet resolution
                %% is the failure shape this project has been bitten by three
                %% times, and the candidates are printed QUALIFIED so the error
                %% hands over the fix — the same idiom as the residual.
                Many  -> erlang:error({ambiguous_call, Name, Arity,
                                       lists:sort(Many), L})
            end
    end.

%% A qualified call names either a module or a namespace-relative short name.
%% Requiring the `using` line is 41 §1 reason 3 met rather than decided: a file's
%% `using` lines ARE its dependency list, in the file and checkable (ticket 23
%% §11), and a qualified call that skipped the list would make that list a lie.
qualified_module(Mod, L, C) ->
    Mods = maps:get(mods, C#ctx.imports, #{}),
    case maps:get(Mod, Mods, []) of
        [M]  -> M;
        []   -> require_imported(Mod, L, C);
        Many -> erlang:error({ambiguous_module, Mod, lists:sort(Many), L})
    end.

require_imported(Mod, L, C) ->
    case lists:member(Mod, maps:get(imported, C#ctx.imports, [])) of
        true  -> Mod;
        false -> erlang:error({module_not_imported, Mod, L})
    end.

qualified_name(Mod, Fun) ->
    list_to_atom(atom_to_list(Mod) ++ "." ++ atom_to_list(Fun)).

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
    %% TICKET 12 §2 — a catch-all is legal only over an OPEN residual, and F2 is
    %% the feature that makes the rule reachable. Until refinements landed, every
    %% integer domain the surface could declare was `int`, so a numeric residual
    %% was open by construction and `_` was always legal over one.
    %%
    %% The moment `type Octet = int where value >= 0 and value <= 255` exists, a
    %% wire dispatch naming four frame types has 252 unnamed octets left and the
    %% compiler KNOWS THEIR NAMES. `_` there is the defect the language exists to
    %% catch: it makes the function unfalsifiable when a fifth frame type is
    %% added, and the residual is precisely the checklist that says what to write.
    %%
    %% This is why F2 is ONE feature and not two — recorded in 25c, and learned
    %% rather than assumed. A refinement without a way to name a span would turn
    %% working programs into rejected ones with nothing to answer the compiler in.
    Diags2 = catch_all_diags(C, Residual, CLine, Name) ++ Diags1,
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
    Diags3 = clause_diags(C, Domain, Bindings, Ctx) ++ Diags2,
    walk(Rest, bs_types:subtract(Residual, Certain), Ctx, Diags3, N + 1).

%% WHAT COUNTS AS A CATCH-ALL, stated once, because the rule is only as good as
%% this line and ticket 12 §2 wrote it in terms of the glyph: *"`_` here is an
%% error: name the case."*
%%
%% So it is `_` and not a bare name, and the narrowing is principled rather than
%% timid. `_` DISCARDS the value; a named binder keeps it, and keeping it buys
%% almost nothing over a closed union — projecting a field off it is site 3 and
%% is refused until you have discriminated, so the type system already forces the
%% clause you would have written. Extending the rule to named binders would also
%% make every single-clause function over a record type an error, which is
%% absurd and is how a rule like this gets switched off.
%%
%% A guard means it is not a catch-all: the clause is then saying something about
%% the values, and whether the checker can read that guard is a different
%% question already answered by the `Certain`/`Possible` split.
%%
%% Measured before landing: the compiling corpus has ZERO all-wildcard clauses,
%% so this rejects nothing that runs today. `queue.bs`'s `(true, _, _)` is a
%% tuple with a discriminating component, not a catch-all.
catch_all_diags({clause, _, _, Patterns, none, _}, Residual, Line, Name) ->
    case all_wild(Patterns) andalso closed_and_inhabited(Residual) of
        true  -> [{error, Line, Name, {catch_all_over_closed, Residual}}];
        false -> []
    end;
catch_all_diags(_C, _Residual, _Line, _Name) ->
    [].

all_wild([])       -> false;      % a nullary function has nothing to catch
all_wild(Patterns) -> lists:all(fun({p_wild, _}) -> true; (_) -> false end, Patterns).

closed_and_inhabited(Residual) ->
    not bs_types:is_none(Residual) andalso not bs_types:is_open(Residual).

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
%% F8.6 — A MATCHED NAME CREDITS NOTHING TO `Certain`, AND THIS `false` IS THE
%% SOUNDNESS HEART OF THE FEATURE.
%%
%% `== acc` is a value test whose value the compiler DOES NOT KNOW. So it is
%% inexact in exactly the sense `[0, ..t]` is — an upper bound on what the clause
%% matches, not the thing itself. It may bound `Possible`; crediting `Certain`
%% would claim coverage the clause does not have, which is the one failure this
%% whole project exists to rule out.
%%
%% Note the shape of the mistake if this said `true`: the compiler gets QUIETER,
%% not louder — it accepts a program it should reject. So the test that guards it
%% must assert an error the wrong build OMITS, which is F5.7, F6's hang and F9's
%% byte count wearing a fourth costume.
%%
%% It binds nothing (`#{}`) — that is the distinction the token marks — and it
%% answers `term()` rather than looking the name's type up. Narrowing arrives
%% anyway and for free: `walk/5` intersects `Possible` with the running residual,
%% which comes from the DECLARED domain, so a body reads the declared type at
%% this position rather than `term`. Ticket 33's mechanism already covers what
%% F8.7 asked for.
pattern_type({p_eqvar, _, _V}, _Path, _Env) -> {bs_types:term(), #{}, false};
%% TICKET 42 — a relational pattern, and it is EXACT. `>= 4` matches precisely
%% the integers from 4 up, which is a set the algebra has held since ticket 20;
%% there is no over-estimate to be honest about, so unlike `== acc` it credits
%% `Certain` in full. That is the whole reason this closes a residual at all.
%%
%% It binds nothing, so a body cannot read the value it matched. That is not an
%% omission — `Classify(>= 4 and <= 7) -> :reserved` is the shape every exemplar
%% wants, and a clause needing the number writes `Classify(n) when n >= 4` as it
%% always could. Ticket 42's own worked example has no binder in any clause.
pattern_type({p_rel, Line, Op, K}, Path, _Env) ->
    argument_position(Line, Path),
    {rel_type(Op, K), #{}, true};
%% `and` is intersection and `or` is union, both already implemented — which is
%% F2's claim for itself surviving intact: no new theory, only surface.
%%
%% Both sides carry the SAME path, because a combinator is not structural: it
%% constrains one value twice rather than describing two positions.
pattern_type({p_and, _, A, B}, Path, Env) ->
    rel_combine(fun bs_types:intersect/2, A, B, Path, Env);
pattern_type({p_or, _, A, B}, Path, Env) ->
    rel_combine(fun bs_types:union/2, A, B, Path, Env);
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

rel_combine(Op, A, B, Path, Env) ->
    {TA, BA, EA} = pattern_type(A, Path, Env),
    {TB, BB, EB} = pattern_type(B, Path, Env),
    {Op(TA, TB), maps:merge(BA, BB), EA andalso EB}.

%% The four relational operators, and they agree with `int_cmp/3` below by
%% construction rather than by coincidence — the same four intervals, because a
%% relational pattern and the guard it replaces have to mean the same thing.
%% `==` is absent: ticket 45 gave it the pattern meaning "the value this NAME
%% holds", and the family divides on the operand.
rel_type('>=', K) -> bs_types:range(K, pos_inf);
rel_type('>',  K) -> bs_types:range(K + 1, pos_inf);
rel_type('<=', K) -> bs_types:range(neg_inf, K);
rel_type('<',  K) -> bs_types:range(neg_inf, K - 1).

%% F2 SHIPS THE RELATIONAL PATTERN IN THE PARAMETER POSITION ONLY, and the
%% omission is chosen rather than forgotten — the feature file records it, and
%% this is where the record is enforced.
%%
%% The grammar gives nesting away for free, which is exactly why it needs saying
%% out loud: `pat_field -> uident ':' pattern` and `pattern -> '(' pattern_list
%% ')'` both admit a relational one level down, and the algebra would handle it
%% correctly. Shipping a capability nothing tests because a production happened to
%% compose is how a language acquires behaviour nobody decided on.
%%
%% Ticket 42 pays F7's debt for `{ Total: > 100, Status: :open }` and F2 declines
%% to spend it here: nesting multiplies the check sites F5 enumerated and no
%% exemplar needs it. A later feature costs one scope call and no new theory.
%%
%% A clause-head parameter is `[I]` and a switch subject is `[]`. Anything longer,
%% or anything carrying a field or list step, is inside something.
argument_position(_Line, [])                     -> ok;
argument_position(_Line, [I]) when is_integer(I) -> ok;
argument_position(Line, _Path) ->
    erlang:error({relational_pattern_nested, Line}).

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
    %% A guard is normalised to alternatives (`or`), each a conjunction (`and`)
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
%%
%% The operator atoms are `and`/`or` since ticket 44; they were `&&`/`||` until
%% F2, and the AST carries the surviving spelling rather than the removed one.
alternatives({e_op, _, 'or', L, R}) ->
    case {alternatives(L), alternatives(R)} of
        {unknown, _} -> unknown;
        {_, unknown} -> unknown;
        {A, B}       -> A ++ B
    end;
alternatives({e_op, _, 'and', L, R}) ->
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
