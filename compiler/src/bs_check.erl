%%% The checker: declarations, scope, exhaustiveness and clause bodies.
%%% Exhaustiveness subtracts each clause's matched type from the declared
%%% input; a signature is required to supply that input. Translatable guards
%%% narrow the subtraction; other guards leave only the pattern's contribution.
%%% `bs_emit` shares this module's resolver and tables.

-module(bs_check).

-export([check/1, check/2]).
%% `check/2` is the single-source case of the `check_dir/3` declaration pass.
-export([check_dir/2, check_dir/3]).
%% `bsc` builds imports from modules already checked in this invocation.
-export([exports_of/1, exports_of/2, exports_of/3, private_of/1, types_of/3, hinted/2]).
%% The emitter publishes polymorphic signatures under the erased environment.
-export([polys_of/2, erased_env/2, type_source/1]).
%% The emitter shares type resolution and qualified record tags here.
-export([resolve/2, qualified/2, record_fields/1, view_pattern/3]).
%% The emitter subtracts clause-head guarantees from the declared refinement so
%% boundary guards check only the remainder.
-export([clause_accepts/2]).
%% The emitter uses these tables to lower reserved calls locally and emit only
%% operations admitted by the checker.
-export([reserved_qualifiers/0, reserved_table/0]).
%% The emitter builds `ParseAtom<T>` arms from the admitted member list.
-export([parse_atom_members/1, built_obligations/0, codegen_obligations/0]).

%% Fault injection reaches otherwise unreachable branches in `as_pasted/2` and
%% `declared_text/2`.
-ifdef(TEST).
-export([as_pasted/2, declared_text/2, declarations_pasted/3, declared_records/6]).
-endif.

%% Keep record field positions stable: `bs_emit` reads them with `element/2`
%% (`element(5, F)` is `params`). Append fields after `tvars`.
-record(fn, {name, line, ret, params, clauses = [], vis = private, tvars = []}).

%% `resolve/2` reads only `types`; the emitter passes that map directly.
%% `params` holds every `{Name, ResolvedType}` so diagnostics can suggest
%% complete clause heads.
-record(ctx, {types = #{}, callees = #{}, ret, fname, arity = 0, binds = #{},
              params = [],
              imports = #{},
              %% Polymorphic return templates use the same keys as `callees`.
              polys = #{},
              %% Own type variables prevent codegen obligations over unresolved
              %% types.
              tvars = []}).

%%% Entry point

%% Returns {ok, Module, [Diagnostic]} | {error, [Diagnostic]}.
check(Decls) -> check(Decls, #{}).

%% `World` maps module atoms to checked exports, behaviours and resolved types.
%% `bsc` supplies modules checked in this invocation; nothing is read from
%% disk.
check(Decls, World) ->
    case check_dir([{undefined, Decls}], World, undefined) of
        {ok, Module, Tagged} -> {ok, Module, [D || {_, D} <- Tagged]};
        {error, Tagged}      -> {error, [D || {_, D} <- Tagged]}
    end.

%%% Checking a directory
%%% The declaration pass covers the whole directory; functions are checked per
%%% file to preserve diagnostic paths. A name alone cannot identify a file
%%% because different arities may live in different files. `Expect` is the
%%% module atom computed by `bsc` from the directory path, or `undefined` for
%%% callers without a path.
%%% Rationale: compiler/features/F15-module-is-a-directory.md.

check_dir(Sources, World) -> check_dir(Sources, World, undefined).

check_dir(Sources, World, Expect) ->
    %% Unknown-type errors can suggest a `using` from the reachable world.
    with_type_hints(World, fun() -> check_dir1(Sources, World, Expect) end).

check_dir1(Sources, World, Expect) ->
    Decls = lists:append([D || {_, D} <- Sources]),
    {Imports, Env} = declared(Sources, World, Expect, strict),
    Module = module_name(Decls),
    PerFile = [{P, collect(D)} || {P, D} <- Sources],
    Fns = lists:append([F || {_, F} <- PerFile]),
    Foreigns = foreign_wrappers(Decls, Env),
    Ctx = #ctx{types = Env, callees = callees(Decls, Env, Imports),
               polys = polys(Decls, Env, Imports),
               imports = Imports},
    Tagged0 = lists:append([check_file(P, Fs, Ctx) || {P, Fs} <- PerFile]),
    %% Internal notes travel through the diagnostic channel; remove them before
    %% printing diagnostics.
    {Notes, Tagged} = lists:partition(
                        fun({_, D}) -> lists:member(element(1, D), [prune, fname, fdiv, vproj]) end,
                        Tagged0),
    Prunes = maps:from_list([{B, Dead} || {_, {prune, B, Dead}} <- Notes]),
    %% Token positions uniquely key bare names' resolved arities; the emitter
    %% uses them for `fun Name/Arity`.
    Fnames = maps:from_list([{Loc, Key} || {_, {fname, Loc, Key}} <- Notes]),
    %% The emitter lowers these float-operand sites to BEAM `/`; other `/`
    %% sites lower to `div`. Keys are operator positions.
    Fdivs = maps:from_list([{Loc, float} || {_, {fdiv, Loc, float}} <- Notes]),
    %% F60: projections the checker resolved onto a view's tuple position.
    Vprojs = maps:from_list([{Loc, Pos} || {_, {vproj, Loc, Pos}} <- Notes]),
    Fns1 = prune_valves(Fns, Prunes),
    PerFile1 = [{P, prune_valves(Fs, Prunes)} || {P, Fs} <- PerFile],
    case [D || {_, D} <- Tagged, element(1, D) =:= error] of
        []     -> behaviours_satisfied(Decls),
                  {ok, #{module => Module, functions => Fns1, env => Env,
                         %% The emitter places file attributes before each
                         %% file's functions.
                         files => PerFile1,
                         %% The emitter retains atoms from all declared types
                         %% in the chunk. Opaque alias variables preserve
                         %% literals that `term` would absorb; `type_vars` lets
                         %% the emitter exclude the variables' own atoms.
                         declared_types => declared_types(Decls, Env),
                         type_vars => lists:usort(lists:append(
                             [Ps || {type_alias, _, _, Ps, _} <- Decls])),
                         behaviours => [B || {behaviour, _, B} <- Decls],
                         %% The emitter consumes imports resolved at check
                         %% time.
                         imports => resolved_funs(Imports, local_keys(Decls)),
                         %% The emitter writes full module atoms for short
                         %% names.
                         qmods => resolved_mods(Imports),
                         %% Remote callback names depend on each callee's
                         %% declared behaviours.
                         remote_names => remote_names(World),
                         %% The emitter uses the `e_foreign_call` triple to
                         %% find calls requiring `try`.
                         foreigns => Foreigns,
                         fnames => Fnames,
                         fdivs => Fdivs,
                         vprojs => Vprojs}, Tagged};
        _Fatal -> {error, Tagged}
    end.

%% Raised function errors retain their source file. Pathless `check/2` callers
%% receive bare tuples.
check_file(undefined, Fns, Ctx) ->
    [{undefined, D} || F <- Fns, {_, Ds} <- [check_fn(F, Ctx)], D <- Ds];
check_file(Path, Fns, Ctx) ->
    try [{Path, D} || F <- Fns, {_, Ds} <- [check_fn(F, Ctx)], D <- Ds]
    catch
        error:Reason when is_tuple(Reason), element(1, Reason) =/= in_file ->
            erlang:error({in_file, Path, Reason})
    end.

%%% Directory declarations

%% Files without a module declaration inherit the directory's module.
one_module_per_directory(_Sources, undefined) -> ok;
one_module_per_directory(Sources, _Expect) ->
    Declared = [{P, N, L} || {P, D} <- Sources, {module, L, N} <- D],
    case lists:usort([N || {_, N, _} <- Declared]) of
        []  -> erlang:error({no_module_declaration,
                             [P || {P, _} <- Sources, is_list(P)]});
        [_] -> ok;
        _   -> erlang:error({module_disagreement, lists:sort(Declared)})
    end.

%% `index.bs` excludes functions, including foreign signatures.
no_function_in_index(Path, Decls) when is_list(Path) ->
    case filename:basename(Path) of
        "index.bs" ->
            case [{N, L} || {signature, L, N, _, _, _, _} <- Decls] of
                %% `resolve_error/2` unwraps this file attribution and
                %% re-dispatches.
                [{N, L} | _] ->
                    erlang:error({in_file, Path, {function_in_index, N, L}});
                []           -> ok
            end;
        _ -> ok
    end;
no_function_in_index(_Path, _Decls) -> ok.

%% `bsc` computes `Expect` from the directory path.
module_matches_path(_Module, _Sources, undefined) -> ok;
module_matches_path(Module, _Sources, Module) -> ok;
module_matches_path(Module, Sources, Expect) ->
    %% The fallback must be `{1, 1}`: `bs_diag` requires both line and column
    %% when the file has no module declaration.
    Line = case [L || {_, D} <- Sources, {module, L, N} <- D, N =:= Module] of
               [L | _] -> L;
               []      -> {1, 1}
           end,
    erlang:error({module_path_mismatch, Module, Expect, Line}).

%% Only whole module names are reserved; a path segment such as `List` in
%% `Shop.Collections.List` is legal.
reserved_module_name(Module, Sources) ->
    case lists:member(Module, reserved_qualifiers()) of
        false -> ok;
        true  ->
            %% The fallback must include both line and column for `bs_diag`.
            Line = case [L || {_, D} <- Sources, {module, L, N} <- D,
                              N =:= Module] of
                       [L | _] -> L;
                       []      -> {1, 1}
                   end,
            erlang:error({reserved_module_name, Module, Line})
    end.

%% Missing callbacks are declaration errors. Only presence is checked here;
%% Dialyzer checks types against OTP's `-callback` declarations.
behaviours_satisfied(Decls) ->
    Defined = [{N, length(Ps)} || {signature, _, N, _, Ps, _, _} <- Decls],
    [case bs_otp:missing(N, Defined) of
         []      -> ok;
         Missing -> erlang:error({behaviour_not_satisfied, L, N, Missing})
     end || {behaviour, L, N} <- Decls],
    ok.

module_name(Decls) ->
    case [N || {module, _, N} <- Decls] of
        [N | _] -> N;
        []      -> 'Main'
    end.

%%% The module system

%% Duplicates are keyed by name and arity to allow overloading. Check before
%% exhaustiveness can merge duplicate signatures and report unreachable
%% clauses.
name_redeclared(Decls) ->
    Sigs = [{{N, length(Ps)}, L} || {signature, L, N, _, Ps, _, _} <- Decls],
    Grouped = lists:foldl(fun({K, L}, Acc) ->
                                  maps:update_with(K, fun(Ls) -> [L | Ls] end, [L], Acc)
                          end, #{}, Sigs),
    case [{N, A, lists:min(Ls)} || {{N, A}, Ls} <- maps:to_list(Grouped), length(Ls) > 1] of
        []                  -> ok;
        [{N, A, L} | _]     -> erlang:error({name_redeclared, N, A, L})
    end.

%%% Visibility

%% The parser marks unannotated signatures `none`. Only `public` is exported;
%% testing for absence of `private` would export unannotated signatures.

%% OTP calls require exports; `-behaviour` has no runtime effect. Require
%% public visibility only for callbacks of this module's declared behaviours.
private_callback(Decls) ->
    Behaviours = [B || {behaviour, _, B} <- Decls],
    Private = [{N, length(Ps), L} || {signature, L, N, _, Ps, V, _} <- Decls, V =/= public],
    case [{N, A, L, Otp} || {N, A, L} <- Private,
                            Otp <- [bs_otp:callback_name(N, A, Behaviours)],
                            Otp =/= none] of
        []                    -> ok;
        [{N, A, L, Otp} | _]  -> erlang:error({private_callback, N, A, Otp, L})
    end.

%%% The declaration pass
%%% A compile and `bsc --api` both refuse a module through `declared/4`, so a
%%% refusal added here reaches both; one wired beside it reaches only one.
%%% Order decides which diagnostic a module with several faults reports.
%%% `behaviours_satisfied/1` is the one declaration check outside it: a compile
%%% runs it after the bodies so their errors are not hidden, and `exports_of/3`,
%%% which checks no bodies, runs it straight after this list.

declared(Sources, World, Expect, Mode) ->
    Decls = lists:append([D || {_, D} <- Sources]),
    one_module_per_directory(Sources, Expect),
    [no_function_in_index(P, D) || {P, D} <- Sources],
    compiler_known_redeclared(Decls),
    compiler_known_function(Decls),
    %% Imports must precede the type environment: local declarations may refer
    %% to imported records and aliases.
    Self = module_name(Decls),
    Imports = import_env(Decls, Self, World, Mode),
    Env = type_env(Decls, Imports, World),
    %% Refuse collapsed failure channels before later diagnostics can describe
    %% the collapsed type.
    collapse_refused(Decls, Env),
    %% Refuse undecidable foreign returns before `foreign_wrappers/2` calls
    %% `error_members/1`, which requires non-recursive members.
    foreign_rets_decidable(Decls, Env),
    %% Scan bodies for `ToJson<T>` refusals: `--api` does not type bodies.
    to_json_refused(Decls, Env),
    %% Reserved-name checks precede path checks so the reserved-name diagnostic
    %% is independent of the directory.
    reserved_module_name(Self, Sources),
    module_matches_path(Self, Sources, Expect),
    name_redeclared(Decls),
    private_callback(Decls),
    {Imports, Env}.

%% `private_of/1` distinguishes private callees from unknown names in
%% cross-module diagnostics.
exports_of(Decls) -> exports_of(Decls, #{}).

%% `one_module_per_directory/2` passes an `undefined` expectation and
%% `no_function_in_index/2` an `undefined` path, so a pathless caller skips
%% both, and `module_matches_path/3` too.
exports_of(Decls, World) -> exports_of([{undefined, Decls}], World, undefined).

%% Resolve imported types as compilation does, but skip unknown imports: `bsc
%% --api` reads available declarations without building dependencies.
exports_of(Sources, World, Expect) ->
    Decls = lists:append([D || {_, D} <- Sources]),
    {_, Env} = declared(Sources, World, Expect, lenient),
    behaviours_satisfied(Decls),
    maps:from_list([{{N, length(Ps)},
                     at_loc(L, fun() -> erased_sig(Ps, R, TV, Env) end)}
                    || {signature, L, N, R, Ps, V, TV} <- Decls, V =:= public]).

%% Build public polymorphic templates under the same environment as
%% `exports_of/2`, so dependents resolve names consistently.
polys_of(Decls, World) ->
    Self = module_name(Decls),
    Imports = import_env(Decls, Self, World, lenient),
    Env = type_env(Decls, Imports, World),
    maps:from_list([{{N, length(Ps)},
                     at_loc(L, fun() -> template(TV, Ps, R, Env) end)}
                    || {signature, L, N, R, Ps, V, TV} <- Decls,
                       V =:= public, TV =/= []]).

%% Dependents receive every declared type under its qualified name and, with a
%% module-tier import, its bare name. Ground types retain producer tags.
%% Qualify references in parametric templates to the producer's declarations
%% and imports; leave template parameters untouched.
%% Rationale: compiler/features/F44-type-names-cross-using.md.
types_of(Decls, Self, World) ->
    Imports = import_env(Decls, Self, World, lenient),
    Env = type_env(Decls, Imports, World),
    Own = declared_type_names(Decls),
    %% Qualify references to the producer's unqualified imports too.
    Theirs = [{N, qualified(M, N)}
              || {N, [M]} <- maps:to_list(maps:get(types, Imports))],
    Rename = maps:from_list(Theirs ++ [{N, qualified(Self, N)} || N <- Own]),
    maps:from_list([{N, crossing(maps:get(N, Env), Rename)} || N <- Own]).

%% Opaque alias variables preserve literals for the emitted atom chunk.
declared_types(Decls, Env) ->
    [resolve(Body, opaque_env(Params, Env)) || {type_alias, _, _, Params, Body} <- Decls]
        ++ [resolve({t_ref, N}, Env) || {type_refined, _, N, _, _} <- Decls]
        ++ [resolve({t_ref, N}, Env) || {record_decl, _, N, _} <- Decls].

declared_type_names(Decls) ->
    [N || {type_alias, _, N, _, _} <- Decls]
        ++ [N || {type_refined, _, N, _, _} <- Decls]
        ++ [N || {record_decl, _, N, _} <- Decls].

crossing({parametric, Params, Body}, Rename) ->
    {parametric, Params, qualify_refs(Body, maps:without(Params, Rename))};
crossing(T, _Rename) ->
    T.

qualify_refs({t_ref, N} = T, Rename) ->
    case maps:find(N, Rename) of
        {ok, Q} -> {t_ref, Q};
        error   -> T
    end;
qualify_refs({t_generic, N, Args}, Rename) ->
    {t_generic, maps:get(N, Rename, N), [qualify_refs(A, Rename) || A <- Args]};
qualify_refs({t_union, Ms}, Rename) ->
    {t_union, [qualify_refs(M, Rename) || M <- Ms]};
qualify_refs({t_tuple, Cs}, Rename) ->
    {t_tuple, [qualify_refs(C, Rename) || C <- Cs]};
qualify_refs({t_map, Fields}, Rename) ->
    {t_map, [{field, F, qualify_refs(T, Rename)} || {field, F, T} <- Fields]};
qualify_refs({t_map_open, Fields}, Rename) ->
    {t_map_open, [{field, F, qualify_refs(T, Rename)} || {field, F, T} <- Fields]};
qualify_refs({t_refined, L, Base, Pred}, Rename) ->
    {t_refined, L, qualify_refs(Base, Rename), Pred};
qualify_refs(T, _Rename) ->
    T.

%%% Unknown-type hints
%%% `resolve/3` knows only the current environment; `hinted/2` uses the world
%%% to distinguish missing imports, missing types and unreachable modules.
%%% Preserve position and file wrappers when rewriting errors.

with_type_hints(World, Fun) ->
    try Fun()
    catch
        error:Reason:S when is_tuple(Reason) ->
            erlang:raise(error, hinted(Reason, World), S)
    end.

hinted({at, Loc, R}, World)     -> {at, Loc, hinted(R, World)};
hinted({in_file, P, R}, World)  -> {in_file, P, hinted(R, World)};
hinted({unknown_type, N}, World) ->
    case split_qualified(N) of
        {Mod, Name} ->
            case reachable(Mod, World) of
                []      -> {type_module_not_imported, Mod, Name};
                [Full]  -> {unknown_type_in_module, Full, Name};
                [_ | _] -> {unknown_type, N}
            end;
        bare ->
            case suppliers(N, World) of
                []   -> {unknown_type, N};
                Mods -> {unknown_type, N, Mods}
            end
    end;
hinted(R, _World) -> R.

split_qualified(N) ->
    case string:split(atom_to_list(N), ".", trailing) of
        [Mod, Name] -> {list_to_atom(Mod), list_to_atom(Name)};
        _           -> bare
    end.

%% Exact and suffix module matches are diagnostic suggestions only; this lookup
%% imports nothing.
reachable(Mod, World) ->
    Suffix = "." ++ atom_to_list(Mod),
    lists:sort([M || M <- maps:keys(World),
                     M =:= Mod orelse
                         lists:suffix(Suffix, atom_to_list(M))]).

suppliers(N, World) ->
    lists:sort([M || {M, Entry} <- maps:to_list(World),
                     maps:is_key(N, maps:get(types, Entry, #{}))]).

private_of(Decls) ->
    maps:from_keys([{N, length(Ps)} || {signature, _, N, _, Ps, V, _} <- Decls,
                                       V =/= public],
                   true).

%% Import tables use modules checked in this invocation:
%%   funs: {Name, Arity} -> [Module], module-tier imports
%%   mods: Short -> [Module], namespace-tier imports
%%   qual: {q, Mod, Name, Arity} -> Sig, reachable qualified callees
%%   types: Name -> [Module], consumed by `imported_types/2`
%% The resolved path determines the import tier, not its spelling. Compilation
%% refuses unknown imports; `--api` skips them.
import_env(Decls, Self, World, Mode) ->
    Imports = [{L, M} || {import, L, M} <- Decls],
    Known = maps:keys(World),
    lists:foldl(fun({L, M}, Acc) -> add_import(L, M, Self, World, Known, Mode, Acc) end,
                #{funs => #{}, mods => #{}, types => #{}, qual => qual_table(World),
                  polys => poly_table(World),
                  privates => private_table(World), imported => []},
                Imports).

add_import(L, M, Self, World, Known, Mode, Acc) ->
    case maps:is_key(M, World) of
        true  -> add_module_import(M, World, Acc);
        false ->
            %% Namespaces emit nothing. Exclude `Self`: importing its namespace
            %% must not make a module its own dependency.
            case {children(M, Known) -- [Self], Mode} of
                {[], strict}  -> erlang:error({unknown_module, M, L});
                {[], lenient} -> Acc;
                {Children, _} -> add_namespace_import(M, Children, Acc)
            end
    end.

%% Local names take precedence over imports at `unqualified_key/4`.
add_module_import(M, World, Acc) ->
    Entry = maps:get(M, World),
    Exports = maps:get(exports, Entry),
    Funs0 = maps:get(funs, Acc),
    Funs = maps:fold(fun(K, _Sig, F) ->
                             %% Collisions are errors only at use sites.
                             maps:update_with(K, fun(Ms) -> [M | Ms] end, [M], F)
                     end, Funs0, Exports),
    %% Type collisions are also refused at use sites. A missing `types` entry
    %% means the module offers no types.
    Types = maps:fold(fun(N, _T, T0) ->
                              maps:update_with(N, fun(Ms) -> [M | Ms] end, [M], T0)
                      end, maps:get(types, Acc), maps:get(types, Entry, #{})),
    Acc#{funs := Funs, types := Types, imported := [M | maps:get(imported, Acc)]}.

add_namespace_import(Prefix, Children, Acc) ->
    Mods0 = maps:get(mods, Acc),
    Mods = lists:foldl(fun(Child, Ms) ->
                               Short = strip_prefix(Prefix, Child),
                               maps:update_with(Short, fun(L) -> [Child | L] end,
                                                [Child], Ms)
                       end, Mods0, Children),
    Acc#{mods := Mods, imported := Children ++ maps:get(imported, Acc)}.

%% Qualified keys match those resolved by `call/6`.
qual_table(World) ->
    maps:fold(fun(M, #{exports := Ex}, Acc) ->
                      maps:fold(fun({N, A}, Sig, In) ->
                                        In#{{q, M, N, A} => Sig}
                                end, Acc, Ex)
              end, #{}, World).

%% Polymorphic templates use the same keys as `call/6`. A missing `polys` entry
%% means no polymorphic exports.
poly_table(World) ->
    maps:fold(fun(M, Entry, Acc) ->
                      maps:fold(fun({N, A}, Tpl, In) ->
                                        In#{{q, M, N, A} => Tpl}
                                end, Acc, maps:get(polys, Entry, #{}))
              end, #{}, World).

%% Keep private names separate from callable entries in `qual_table/1`, using
%% the same keys.
private_table(World) ->
    maps:fold(fun(M, Entry, Acc) ->
                      maps:fold(fun({N, A}, _, In) -> In#{{q, M, N, A} => true} end,
                                Acc, maps:get(private, Entry, #{}))
              end, #{}, World).

%% Only unambiguous imports reach the emitter. Drop locally declared names so
%% the emitter agrees with `unqualified_key/4`'s local precedence.
resolved_funs(Imports, Local) ->
    maps:fold(fun(K, [M], Acc) ->
                      case lists:member(K, Local) of
                          true  -> Acc;
                          false -> Acc#{K => M}
                      end;
                 (_, _, Acc) -> Acc
              end, #{}, maps:get(funs, Imports, #{})).

local_keys(Decls) ->
    [{N, length(Ps)} || {signature, _, N, _, Ps, _, _} <- Decls].

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

%%% Signatures and clauses

collect(Decls) ->
    %% Exclude foreign signatures: they have no clauses to check.
    Sigs = [#fn{name = N, line = L, ret = R, params = P, vis = V, tvars = TV}
            || {signature, L, N, R, P, V, TV} <- Decls],
    [F#fn{clauses = [C || C = {clause, _, Name, Ps, _, _} <- Decls,
                          Name =:= F#fn.name,
                          length(Ps) =:= length(F#fn.params)]}
     || F <- Sigs].

%% Foreign signatures are callees even though `collect/1` excludes them. Local
%% keys are `{Name, Arity}`; foreign keys match `e_foreign_call` as `{f,
%% Module, Function, Arity}`. Arity distinguishes overloads.
callees(Decls, Env, Imports) ->
    %% Polymorphic argument checks use the maximal extent; only the return
    %% requires solving type variables.
    Local = [{{N, length(Ps)},
              at_loc(SL, fun() -> erased_sig(Ps, R, TV, Env) end)}
             || {signature, SL, N, R, Ps, _, TV} <- Decls],
    Foreign = [{{f, Mod, N, length(Ps)},
                at_loc(L, fun() -> sig(Ps, R, Env) end)}
               || {foreign, _, Mod, Sigs} <- Decls,
                  {foreign_sig, L, N, R, Ps} <- Sigs],
    maps:merge(maps:get(qual, Imports, #{}),
               maps:from_list(Local ++ Foreign)).

%%% Foreign returns
%%% A foreign return must be decidable by one O(1) BEAM guard. Parameters are
%%% established by their producers and are not checked by this pass. Recursive
%%% types are not unfolded. Refined list elements, map domains and UTF-8
%%% strings require walks; `list<term>` and `map<term, term>` do not. Named
%%% records require a compiler-minted `Kind` absent from Erlang values; inline
%%% map fields can be checked with `map_get`. Check structural offenders before
%%% strings so suggestions address the required walk rather than only replacing
%%% `string` with `binary`.
%%% Rationale: compiler/features/F40-foreign-return-rule.md.

foreign_rets_decidable(Decls, Env) ->
    _ = [foreign_ret_decidable(L, Mod, N, R, Env)
         || {foreign, _, Mod, Sigs} <- Decls,
            {foreign_sig, L, N, R, _Ps} <- Sigs],
    ok.

foreign_ret_decidable(Line, Mod, Fun, Ret, Env) ->
    Ty = resolve(Ret, Env),
    case beyond_one_guard(Ty) of
        none ->
            ok;
        {Why, Name, Fields, At} ->
            erlang:error({foreign_ret_beyond_one_guard, Line, Mod, Fun,
                          declared_text(Ret, Ty), Why, Name, Fields, At})
    end.

%% Returns `none` or `{Why, Name, Fields, At}`. `Fields` supplies the suggested
%% inline record form; `At` selects a whole-return or nested edit.
beyond_one_guard(Ty) ->
    case offender(Ty, structural, whole) of
        none  -> offender(Ty, string, whole);
        Found -> Found
    end.

offender(#{mu := _} = Ty, structural, At) ->
    {recursive, bs_types:rec_name(Ty), none, At};
offender(#{recvar := _} = Ty, structural, At) ->
    {recursive, bs_types:rec_name(Ty), none, At};
offender(#{mu := _}, string, _At) ->
    none;
offender(#{recvar := _}, string, _At) ->
    none;
offender(Ty = #{tuples := Ts, maps := Ms, bins := Bs, funs := Fs}, Pass, At) ->
    first([fun() -> list_offender(Ty, Pass, only(Ty, lists, At)) end,
           fun() -> map_offender(Ms, Pass, only(Ty, maps, At)) end,
           fun() -> tuple_offender(Ts, Pass) end,
           fun() -> bin_offender(Bs, Pass, only(Ty, bins, At)) end,
           fun() -> fun_offender(Fs, Pass, only(Ty, funs, At)) end]).

%% `is_function/2` checks arity, not argument or return types. Only the
%% unrestricted fun part of `term` is guard-decidable.
fun_offender([], _Pass, _At)       -> none;
fun_offender(top, _Pass, _At)      -> none;
fun_offender(_Fs, structural, At)  -> {arrow, none, none, At};
fun_offender(_Fs, string, _At)     -> none.

%% A part inside a union is `inside`, even at the top level; suggesting a
%% whole-type replacement there would discard the union's other members.
only(_Ty, _Part, inside) ->
    inside;
only(Ty, Part, whole) ->
    Alone = (bs_types:none())#{Part => maps:get(Part, Ty)},
    case bs_types:is_subtype(Ty, Alone) of
        true  -> whole;
        false -> inside
    end.

first([])       -> none;
first([F | Fs]) ->
    case F() of
        none  -> first(Fs);
        Found -> Found
    end.

%% List spines require element-type inspection, except `[]`, which has no
%% elements and is decided by exact equality.
list_offender(Ty, structural, At) ->
    case bs_types:has_lists(Ty) of
        false -> none;
        true  ->
            Elem = bs_types:list_elem(Ty),
            case bs_types:is_none(Elem)
                orelse bs_types:is_subtype(bs_types:term(), Elem) of
                true  -> none;
                false -> {list, none, none, At}
            end
    end;
list_offender(_Ty, string, _At) ->
    none.

map_offender(top, _Pass, _At) ->
    none;
map_offender(Members, Pass, At) ->
    first([fun() -> map_member_offender(M, Pass, At) end || M <- Members]).

map_member_offender({dom, K, V}, structural, At) ->
    Term = bs_types:term(),
    case bs_types:is_subtype(Term, K) andalso bs_types:is_subtype(Term, V) of
        true  -> none;
        false -> {map, none, none, At}
    end;
map_member_offender({dom, _K, _V}, string, _At) ->
    none;
map_member_offender({_Kind, Fs}, Pass, At) ->
    case maps:find('Kind', Fs) of
        {ok, #{atoms := {finite, [Tag]}}} when Pass =:= structural ->
            {record, record_short_name(Tag),
             bs_types:to_string(bs_types:map_closed(maps:remove('Kind', Fs))),
             At};
        {ok, _} ->
            none;
        error ->
            first([fun() -> offender(F, Pass, inside) end
                   || F <- maps:values(Fs)])
    end.

%% Record `Kind` holds a qualified name; diagnostics use its last segment.
record_short_name(Tag) ->
    list_to_atom(lists:last(string:split(atom_to_list(Tag), ".", all))).

tuple_offender(top, _Pass) ->
    none;
tuple_offender(Products, Pass) ->
    first([fun() -> offender(M, Pass, inside) end || M <- lists:append(Products)]).

%% `string` is the only proper non-empty refinement of the binary part.
bin_offender(Bs, string, At) when Bs =/= [], Bs =/= [other, utf8] ->
    {string, none, none, At};
bin_offender(_Bs, _Pass, _At) ->
    none.

sig(Params, Ret, Env) ->
    {[resolve(T, Env) || {param, T, _} <- Params], resolve(Ret, Env)}.

%%% Polymorphic signatures
%%% Erased variables give callers the maximal extent and emit `any()` specs.
%%% Declarations instead bind variables to opaque singleton atoms the source
%%% cannot spell bare. This prevents assumptions about an instantiation's shape
%%% and checks exhaustiveness once for every instantiation.
%%% Rationale: compiler/features/F45-polymorphic-signatures.md.

erased_env(Vars, Env) ->
    maps:merge(Env, maps:from_list([{V, bs_types:term()} || V <- Vars])).

%% Erasure respects variance: arrow domains reverse polarity, so `fn(T) -> U`
%% has maximal extent `fn(none) -> term`. Using `term` for its domain would
%% reject valid function arguments.
erased_sig(Params, Ret, [], Env) ->
    sig(Params, Ret, Env);
erased_sig(Params, Ret, Vars, Env) ->
    {[erase_ty(T, Vars, Env, pos, []) || {param, T, _} <- Params],
     erase_ty(Ret, Vars, Env, pos, [])}.

erase_ty(T, Vars, Env, Pol, Seen) ->
    case vars_in(T, Vars) of
        [] -> resolve(T, Env);
        _  -> erase_ty1(T, Vars, Env, Pol, Seen)
    end.

erase_ty1({t_ref, _V}, _Vars, _Env, pos, _Seen) -> bs_types:term();
erase_ty1({t_ref, _V}, _Vars, _Env, neg, _Seen) -> bs_types:none();
erase_ty1({t_fun, Ds, C}, Vars, Env, Pol, Seen) ->
    bs_types:fun_ty([erase_ty(D, Vars, Env, contra(Pol), Seen) || D <- Ds],
                    erase_ty(C, Vars, Env, Pol, Seen));
erase_ty1({t_union, Ms}, Vars, Env, Pol, Seen) ->
    bs_types:union([erase_ty(M, Vars, Env, Pol, Seen) || M <- Ms]);
erase_ty1({t_tuple, Cs}, Vars, Env, Pol, Seen) ->
    bs_types:tuple([erase_ty(C, Vars, Env, Pol, Seen) || C <- Cs]);
erase_ty1({t_generic, list, [A]}, Vars, Env, Pol, Seen) ->
    bs_types:list(erase_ty(A, Vars, Env, Pol, Seen));
erase_ty1({t_generic, N, Args} = T, Vars, Env, Pol, Seen) when N =/= map ->
    case {maps:get(N, Env, undefined), lists:member({N, Args}, Seen)} of
        {{parametric, Params, Body}, false} when length(Params) =:= length(Args) ->
            Sub = maps:from_list(lists:zip(Params, Args)),
            erase_ty(subst(Body, Sub), Vars, Env, Pol, [{N, Args} | Seen]);
        _ ->
            resolve(T, erased_env(Vars, Env))
    end;
%% Map fields, refinements and domain maps use the positive extent; `tpl1/5`
%% records these positions as erased.
erase_ty1(T, Vars, Env, _Pol, _Seen) ->
    resolve(T, erased_env(Vars, Env)).

contra(pos) -> neg;
contra(neg) -> pos.

opaque_env(Vars, Env) ->
    maps:merge(Env, maps:from_list([{V, bs_types:atom_lit(V)} || V <- Vars])).

%% Keys match `callees/3` for local and imported polymorphic callees.
polys(Decls, Env, Imports) ->
    Local = [{{N, length(Ps)}, at_loc(SL, fun() -> template(TV, Ps, R, Env) end)}
             || {signature, SL, N, R, Ps, _, TV} <- Decls, TV =/= []],
    maps:merge(maps:get(polys, Imports, #{}), maps:from_list(Local)).

%% Ground parts resolve at the declaration, so consumers need no producer
%% aliases. Variables survive in lists, tuples, unions and arrows. Other
%% positions erase to their extent and force the variable to `term`: values can
%% reach the body through those positions.
%% Rationale: compiler/features/F45-polymorphic-signatures.md.
template(Vars, Params, Ret, Env) ->
    {PsT, E1} = lists:mapfoldl(fun({param, T, _}, E) -> tpl(T, Vars, Env, [], E) end,
                               [], Params),
    {RetT, E2} = tpl(Ret, Vars, Env, [], E1),
    {poly, Vars, PsT, RetT, lists:usort(E2)}.

tpl(T, Vars, Env, Seen, Erased) ->
    case mentions(T, Vars) of
        false -> {resolve(T, Env), Erased};
        true  -> tpl1(T, Vars, Env, Seen, Erased)
    end.

tpl1({t_ref, V}, _Vars, _Env, _Seen, Erased) ->
    {{t_ref, V}, Erased};
tpl1({t_generic, list, [A]}, Vars, Env, Seen, Erased) ->
    {A1, E1} = tpl(A, Vars, Env, Seen, Erased),
    {{t_generic, list, [A1]}, E1};
tpl1({t_tuple, Cs}, Vars, Env, Seen, Erased) ->
    {Cs1, E1} = lists:mapfoldl(fun(C, E) -> tpl(C, Vars, Env, Seen, E) end, Erased, Cs),
    {{t_tuple, Cs1}, E1};
tpl1({t_union, Ms}, Vars, Env, Seen, Erased) ->
    {Ms1, E1} = lists:mapfoldl(fun(M, E) -> tpl(M, Vars, Env, Seen, E) end, Erased, Ms),
    {{t_union, Ms1}, E1};
tpl1({t_fun, Ds, C}, Vars, Env, Seen, Erased) ->
    {Ds1, E1} = lists:mapfoldl(fun(D, E) -> tpl(D, Vars, Env, Seen, E) end, Erased, Ds),
    {C1, E2} = tpl(C, Vars, Env, Seen, E1),
    {{t_fun, Ds1, C1}, E2};
tpl1({t_generic, N, Args} = T, Vars, Env, Seen, Erased) when N =/= map ->
    case {maps:get(N, Env, undefined), lists:member({N, Args}, Seen)} of
        {{parametric, Params, Body}, false} when length(Params) =:= length(Args) ->
            Sub = maps:from_list(lists:zip(Params, Args)),
            tpl(subst(Body, Sub), Vars, Env, [{N, Args} | Seen], Erased);
        _ -> erase(T, Vars, Env, Erased)
    end;
tpl1(T, Vars, Env, _Seen, Erased) ->
    erase(T, Vars, Env, Erased).

erase(T, Vars, Env, Erased) ->
    {resolve(T, erased_env(Vars, Env)), vars_in(T, Vars) ++ Erased}.

mentions(T, Vars) -> vars_in(T, Vars) =/= [].

vars_in({t_ref, N}, Vars) ->
    case lists:member(N, Vars) of true -> [N]; false -> [] end;
vars_in({t_union, Ms}, Vars)      -> lists:append([vars_in(M, Vars) || M <- Ms]);
vars_in({t_tuple, Cs}, Vars)      -> lists:append([vars_in(C, Vars) || C <- Cs]);
vars_in({t_generic, _, As}, Vars) -> lists:append([vars_in(A, Vars) || A <- As]);
vars_in({t_map, Fields}, Vars)    -> lists:append([vars_in(T, Vars) || {_, T} <- Fields]);
vars_in({t_map_open, Fields}, Vars) -> vars_in({t_map, Fields}, Vars);
vars_in({t_refined, _, B, _}, Vars) -> vars_in(B, Vars);
vars_in({t_fun, Ds, C}, Vars)     -> lists:append([vars_in(T, Vars) || T <- Ds ++ [C]]);
vars_in(_, _)                     -> [].

%% Argument occurrences supply lower bounds covariantly and upper bounds
%% contravariantly, tagged with their argument index for diagnostics. Return
%% variance selects the solution: join lower bounds for positive or absent
%% variables, meet upper bounds for negative ones, join both for mixed. A lower
%% bound outside an upper bound is a conflict. Erased variables stay `term`
%% regardless of bounds. Solving is total even for arguments rejected by
%% `arg_diags/7`.
%% Rationale: compiler/features/F46-function-as-a-value.md.
solution({poly, Vars, PsT, RetT, Erased}, ATys) ->
    Bounds = bounds(PsT, lists:zip(lists:seq(1, length(ATys)), ATys)),
    Pols = polarity(RetT, pos, #{}),
    Sub = maps:from_list(
            [{V, case lists:member(V, Erased) of
                     true  -> bs_types:term();
                     false -> pick(maps:get(V, Pols, absent), bounds_of(V, Bounds))
                 end} || V <- Vars]),
    Conflicts = [{V, Conflict}
                 || V <- Vars, not lists:member(V, Erased),
                    Conflict <- [escape(bounds_of(V, Bounds))],
                    Conflict =/= none],
    {Sub, Conflicts}.

bounds(PsT, Typed) ->
    lists:foldl(fun({I, Ty}, Acc) -> solve(lists:nth(I, PsT), Ty, pos, I, Acc) end,
                #{}, Typed).

bounds_of(V, Bounds) -> maps:get(V, Bounds, {[], []}).

pick(neg, {_Lo, Up})        -> meet(Up);
pick(both, {Lo, Up})        -> join(Lo ++ Up);
pick(_Covariant, {Lo, _Up}) -> join(Lo).

%% Partial argument bounds supply expectations only (`retype/8`).
known({[], Up}) -> meet(Up);
known({Lo, _})  -> join(Lo).

%% The join of no bounds is `none` and the meet of none is `term`.
join(Bounds) -> bs_types:union([T || {_, T} <- Bounds]).

meet(Bounds) -> lists:foldl(fun({_, U}, Acc) -> bs_types:intersect(Acc, U) end,
                            bs_types:term(), Bounds).

%% Check lower bounds separately so diagnostics name the contributing arguments
%% and the offending value, not their union.
escape({Lo, Up}) ->
    case [{LI, L, UI, U} || {UI, U} <- Up, {LI, L} <- Lo,
                            not bs_types:is_subtype(L, U)] of
        []          -> none;
        [First | _] -> First
    end.

%% Unmentioned variables are absent from the polarity map.
polarity(T, _Pol, Acc) when is_map(T) -> Acc;
polarity({t_ref, V}, Pol, Acc) ->
    maps:update_with(V, fun(P) when P =:= Pol -> P; (_) -> both end, Pol, Acc);
polarity({t_generic, list, [E]}, Pol, Acc) -> polarity(E, Pol, Acc);
polarity({t_tuple, Cs}, Pol, Acc) ->
    lists:foldl(fun(C, A) -> polarity(C, Pol, A) end, Acc, Cs);
polarity({t_union, Ms}, Pol, Acc) ->
    lists:foldl(fun(M, A) -> polarity(M, Pol, A) end, Acc, Ms);
polarity({t_fun, Ds, C}, Pol, Acc) ->
    Acc1 = lists:foldl(fun(D, A) -> polarity(D, contra(Pol), A) end, Acc, Ds),
    polarity(C, Pol, Acc1).

%% Maximal argument share a union member can claim.
extent(T) when is_map(T)         -> T;
extent({t_ref, _})               -> bs_types:term();
extent({t_generic, list, [A]})   -> bs_types:list(extent(A));
extent({t_tuple, Cs})            -> bs_types:tuple([extent(C) || C <- Cs]);
extent({t_union, Ms})            -> bs_types:union([extent(M) || M <- Ms]);
%% The largest arrow is `fn(none, ...) -> term`: domains are contravariant.
extent({t_fun, Ds, _C})          -> bs_types:fun_ty([bs_types:none() || _ <- Ds],
                                                    bs_types:term()).

%% Bounds accumulate as `#{V => {Lower, Upper}}`, each a list of `{Arg, Ty}`.
solve(T, _A, _Pol, _I, Acc) when is_map(T) -> Acc;
solve({t_ref, V}, A, Pol, I, Acc) ->
    {Lo, Up} = maps:get(V, Acc, {[], []}),
    Acc#{V => case Pol of
                  pos -> {Lo ++ [{I, A}], Up};
                  neg -> {Lo, Up ++ [{I, A}]}
              end};
solve({t_generic, list, [E]}, A, Pol, I, Acc) ->
    solve(E, bs_types:list_elem(bs_types:unfold(A)), Pol, I, Acc);
solve({t_tuple, Cs}, A, Pol, I, Acc) ->
    N = length(Cs),
    {_, Out} = lists:foldl(fun(C, {J, S}) ->
                                   {J + 1, solve(C, bs_types:tuple_comp(A, N, J), Pol, I, S)}
                           end, {1, Acc}, Cs),
    Out;
solve({t_union, Ms}, A, Pol, I, Acc) ->
    %% A member gets the argument minus every other member's extent.
    Indexed = lists:zip(lists:seq(1, length(Ms)), Ms),
    lists:foldl(fun({J, M}, S) ->
                        Others = bs_types:union([extent(O) || {K, O} <- Indexed, K =/= J]),
                        solve(M, bs_types:subtract(A, Others), Pol, I, S)
                end, Acc, Indexed);
%% Every matching-arity arrow contributes bounds; domains flip polarity. Upper
%% bounds meet because either function must accept the variable. The top
%% contributes no bounds.
solve({t_fun, Ds, C}, A, Pol, I, Acc) ->
    N = length(Ds),
    Arrows = case bs_types:arrows(A) of
                 top -> [];
                 Fs  -> [F || {ADs, _} = F <- Fs, length(ADs) =:= N]
             end,
    lists:foldl(fun({ADs, AC}, S0) ->
                        S1 = lists:foldl(fun({D, AD}, S) ->
                                                 solve(D, AD, contra(Pol), I, S)
                                         end, S0, lists:zip(Ds, ADs)),
                        solve(C, AC, Pol, I, S1)
                end, Acc, Arrows).

subst_tpl(T, _S) when is_map(T)       -> T;
subst_tpl({t_ref, V}, S)              -> maps:get(V, S);
subst_tpl({t_generic, list, [E]}, S)  -> bs_types:list(subst_tpl(E, S));
subst_tpl({t_tuple, Cs}, S)           -> bs_types:tuple([subst_tpl(C, S) || C <- Cs]);
subst_tpl({t_union, Ms}, S)           -> bs_types:union([subst_tpl(M, S) || M <- Ms]);
subst_tpl({t_fun, Ds, C}, S)          -> bs_types:fun_ty([subst_tpl(D, S) || D <- Ds],
                                                         subst_tpl(C, S)).


%% Every type variable must occur in a parameter for call-site inference. A
%% bare type-variable parameter permits only a binder or wildcard. Reject shape
%% tests before the walk can misreport opaque atoms as vacuous.
recoverable_diags(#fn{tvars = []}) -> [];
recoverable_diags(#fn{name = Name, line = L, params = Params, tvars = Vars}) ->
    InParams = lists:append([vars_in(T, Vars) || {param, T, _} <- Params]),
    [{error, L, Name, {unrecoverable_type_variable, V}}
     || V <- Vars, not lists:member(V, InParams)].

opacity_diags(_Clauses, _Params, [], _Name) -> [];
opacity_diags(Clauses, Params, Vars, Name) ->
    Bare = [{I, V} || {I, {param, {t_ref, V}, _}}
                          <- lists:zip(lists:seq(1, length(Params)), Params),
                      lists:member(V, Vars)],
    [{error, L, Name, {pattern_on_type_variable, V, I}}
     || {clause, L, _, Ps, _, _} <- Clauses,
        {I, V} <- Bare,
        not binds_only(lists:nth(I, Ps))].

binds_only({p_var, _, _}) -> true;
binds_only({p_wild, _})   -> true;
binds_only(_)             -> false.

%% Type expressions have no source position. Positionless resolve errors use
%% the nearest enclosing declaration; positioned errors keep their own. Prelude
%% entries have no declaration and pass `undefined`.
at_loc(undefined, Fun) ->
    Fun();
at_loc(Loc, Fun) ->
    try Fun()
    catch
        error:Reason:S when is_tuple(Reason), tuple_size(Reason) > 0 ->
            case positionless(element(1, Reason)) of
                true  -> erlang:raise(error, {at, Loc, Reason}, S);
                false -> erlang:raise(error, Reason, S)
            end
    end.

%% Explicit opt-in for errors that need an enclosing declaration's position.
positionless(unknown_type)    -> true;
positionless(ambiguous_type)  -> true;
positionless(unknown_builtin) -> true;
positionless(generic_arity)   -> true;
positionless(needs_type_args) -> true;
positionless(not_parametric)  -> true;
positionless(cyclic_type)     -> true;
positionless(_)               -> false.

%%% --- Foreign wrappers ---

%% Entries use `e_foreign_call` keys. The emitter reads both the wrapper flag
%% and resolved return type; the boundary guard sits outside the wrapper.
%% Aliases trigger wrapping by resolved type, not spelling.
%% Rationale: compiler/features/F19-foreign-try-wrapper.md,
%% compiler/features/F52-channelled-foreign-return-guard.md.
foreign_wrappers(Decls, Env) ->
    maps:from_list(
      [{{Mod, N, length(Ps)}, #{wrapped => wraps(Ty, Env), ret => Ty}}
       || {foreign, _, Mod, Sigs} <- Decls,
          {foreign_sig, _L, N, R, Ps} <- Sigs,
          Ty <- [resolve(R, Env)]]).

%% The payload must equal `foreign_error` exactly; containment is insufficient.
%% `result<int, term>` gets no wrapper. The boundary guard catches bad returns.
%% OTP error tuples can be ordinary values, so throwing functions that also
%% return errors must declare both payloads separately.
wraps(Ret, Env) ->
    Fe = maps:get(foreign_error, Env),
    lists:any(fun(P) -> same_type(P, Fe) end, error_members(Ret)).

%% `term` has tuple part `top`, with no named payload to trigger wrapping.
error_members(#{tuples := top}) -> [];
error_members(#{tuples := Products}) ->
    Err = bs_types:atom_lit(error),
    [Payload || [Tag, Payload] <- Products, same_type(Tag, Err)].

same_type(A, B) -> bs_types:is_subtype(A, B) andalso bs_types:is_subtype(B, A).

%%% --- Union declaration checks ---
%%%
%%% Absorption must raise before indiscriminability: only surviving members
%%% reach the pairwise check, so `:ok | atom` fails absorption alone.
%%% Declarations supply lines; paths distinguish nested positions on one line.
%%% Rationale: compiler/features/F36-an-absorbed-member.md.


collapse_refused(Decls, Env) ->
    lists:foreach(fun(D) -> collapse_decl(D, Env) end, Decls).

%% Parametric aliases wait for instantiation before normalisation. Paths start
%% at the return name, `Fn.arg` or `Rec.Field`.
collapse_decl({signature, L, N, Ret, Params, _, TV}, Env0) ->
    Env = opaque_env(TV, Env0),
    collapse_ty(Ret, Env, L, root(N)),
    lists:foreach(fun({param, T, P}) -> collapse_ty(T, Env, L, seg(root(N), P))
                  end, Params);
collapse_decl({foreign, _, _Mod, Sigs}, Env) ->
    lists:foreach(
      fun({foreign_sig, L, N, Ret, Ps}) ->
              collapse_ty(Ret, Env, L, root(N)),
              lists:foreach(
                fun({param, T, P}) -> collapse_ty(T, Env, L, seg(root(N), P))
                end, Ps)
      end, Sigs);
collapse_decl({type_alias, L, N, [], Body}, Env)  ->
    collapse_ty(Body, Env, L, root(N));
collapse_decl({type_refined, L, N, Base, _}, Env) ->
    collapse_ty(Base, Env, L, root(N));
collapse_decl({record_decl, L, N, Fields}, Env) ->
    lists:foreach(fun({field, F, T}) -> collapse_ty(T, Env, L, seg(root(N), F))
                  end, Fields);
collapse_decl(_, _Env) -> ok.

%% `bs_diag` renders these dotted paths unchanged; tuple ordinals are 1-based.
root(N) when is_atom(N) -> atom_to_list(N);
root(N) when is_list(N) -> N;
%% F58: a string key reads `["a"]`, as a validation path spells it.
root(N) when is_binary(N) -> "[" ++ bs_types:key_str(N) ++ "]";
root(N)                 -> lists:flatten(io_lib:format("~p", [N])).

seg(Path, S) when is_binary(S) -> Path ++ root(S);
seg(Path, S) -> Path ++ "." ++ root(S).

%% Resolution errors belong to the later `callees/3` and `check_fn/2` passes.
%% Only this pass's own refusals propagate, with their stacks intact.
collapse_ty(T, Env, L, Path) ->
    try scan_ty(T, Env, L, Path, [])
    catch
        error:{absorbed_member, _, _, _, _, _} = E:S ->
            erlang:raise(error, E, S);
        error:{indiscriminable_union, _, _, _, _} = E:S ->
            erlang:raise(error, E, S);
        error:_ ->
            ok
    end.

%% `Seen` stops contractive aliases expanding forever; `resolve/3` handles
%% their recursive meaning.
scan_ty({t_union, Ms}, Env, L, Path, Seen) ->
    collapse_members(Ms, Env, L, Path),
    indiscriminable_members(Ms, Env, L, Path),
    lists:foreach(fun(M) -> scan_ty(M, Env, L, Path, Seen) end, Ms);
%% Expand before `bs_types:union/1` erases member boundaries. Arguments resolve
%% in the caller's chain before substitution.
scan_ty({t_generic, N, Args}, Env, L, Path, Seen) ->
    lists:foreach(fun(A) -> scan_ty(A, Env, L, Path, Seen) end, Args),
    case maps:get(N, Env, undefined) of
        {parametric, Params, Body} when length(Params) =:= length(Args) ->
            case lists:member(N, Seen) of
                true ->
                    ok;
                false ->
                    Sub = maps:from_list(
                            lists:zip(Params, [resolve(A, Env) || A <- Args])),
                    scan_ty(subst(Body, Sub), Env, L, Path, [N | Seen])
            end;
        _ ->
            ok
    end;
scan_ty({t_tuple, Cs}, Env, L, Path, Seen) ->
    lists:foreach(fun({I, C}) -> scan_ty(C, Env, L, seg(Path, I), Seen) end,
                  lists:zip(lists:seq(1, length(Cs)), Cs));
scan_ty({t_map_open, Fields}, Env, L, Path, Seen) ->
    scan_ty({t_map, Fields}, Env, L, Path, Seen);
scan_ty({t_map, Fields}, Env, L, Path, Seen) ->
    lists:foreach(fun({field, F, T}) -> scan_ty(T, Env, L, seg(Path, F), Seen)
                  end, Fields);
scan_ty({t_refined, _, Base, _}, Env, L, Path, Seen) ->
    scan_ty(Base, Env, L, Path, Seen);
scan_ty({t_fun, Ds, C}, Env, L, Path, Seen) ->
    lists:foreach(fun({I, D}) -> scan_ty(D, Env, L, seg(Path, I), Seen) end,
                  lists:zip(lists:seq(1, length(Ds)), Ds)),
    scan_ty(C, Env, L, seg(Path, ret), Seen);
%% Do not follow `t_ref`: its declaration owns the diagnostic.
scan_ty(_, _Env, _L, _Path, _Seen) ->
    ok.

collapse_members(Ms, _Env, _L, _Path) when length(Ms) < 2 -> ok;
collapse_members(Ms, Env, L, Path) ->
    each_member(Ms, [resolve(M, Env) || M <- Ms], [], L, Path).

%% Check every member. The surface shape selects only the diagnostic hint.
%% Reversing `Before` is safe because union is commutative.
each_member([], [], _Before, _L, _Path) ->
    ok;
each_member([M | Ms], [R | Rs], Before, L, Path) ->
    Others = bs_types:union(Before ++ Rs),
    case absorbed(R, Others) of
        true  -> erlang:error({absorbed_member, L, Path, failure_channel(M),
                               R, Others});
        false -> ok
    end,
    each_member(Ms, Rs, [R | Before], L, Path).

%% Substitution preserves these surface shapes for failure-channel hints.
failure_channel({t_atom, nothing})                 -> nothing;
failure_channel({t_tuple, [{t_atom, error}, _]})   -> error;
failure_channel(_)                                 -> none.

%%% --- Union discriminability ---
%%%
%%% Pair normalised constituents, not written members: aliases may be unions.
%%% Either constituent's pattern reach or disjoint BEAM guard buckets suffice.
%%% `bs_types:head_reach/1` must track the pattern grammar. Reachability does
%%% not prove separation: a pattern reaching both counts.


indiscriminable_members(Ms, _Env, _L, _Path) when length(Ms) < 2 -> ok;
indiscriminable_members(Ms, Env, L, Path) ->
    Normalised = bs_types:union([resolve(M, Env) || M <- Ms]),
    pairwise(bs_types:constituents(Normalised), L, Path).

pairwise([], _L, _Path) -> ok;
pairwise([R | Rs], L, Path) ->
    lists:foreach(fun(O) -> discriminable(R, O, L, Path) end, Rs),
    pairwise(Rs, L, Path).

discriminable(A, B, L, Path) ->
    case reaches(A) orelse reaches(B) orelse disjoint_buckets(A, B) of
        true  -> ok;
        false -> erlang:error({indiscriminable_union, L, Path, A, B})
    end.

%% `pattern` reaches a member. A bare binder (`guard`) needs the bucket test; a
%% typed binder (`none`) is not a pattern.
reaches(T) -> bs_types:head_reach(T) =:= pattern.

disjoint_buckets(A, B) ->
    Bs = bs_types:guard_buckets(B),
    [] =:= [X || X <- bs_types:guard_buckets(A), lists:member(X, Bs)].

%%% --- Resolving surface types ---

%% Local declarations shadow imported names.
%% Rationale: compiler/features/F44-type-names-cross-using.md.
type_env(Decls, Imports, World) ->
    Mod = module_name(Decls),
    %% Shared positions for duplicate checks and entry resolution.
    Locs = [{N, L} || {type_alias, L, N, _, _} <- Decls]
        ++ [{N, L} || {type_refined, L, N, _, _} <- Decls]
        ++ [{N, L} || {record_decl, L, N, _} <- Decls],
    %% All type declarations share one namespace. Reject duplicates before
    %% `maps:from_list/1` silently keeps the rightmost entry.
    type_redeclared(Locs),
    Aliases = [{N, alias(Params, T)} || {type_alias, _, N, Params, T} <- Decls],
    %% Keep refinements as surface nodes to inherit `resolve/3`'s cycle guard.
    Refined = [{N, {t_refined, L, Base, Pred}}
               || {type_refined, L, N, Base, Pred} <- Decls],
    Records = [{N, record_surface(Mod, L, N, Fs)}
               || {record_decl, L, N, Fs} <- Decls],
    Local = maps:from_list(Aliases ++ Refined ++ Records),
    Imported = imported_types(Imports, World),
    Env = maps:merge(maps:merge(prelude(), Imported), Local),
    %% Ground entries resolve once; parametric templates wait for substitution.
    %% Resolve under each entry's name to tie recursive references at its root.
    %% Sort keys for deterministic cycle errors; map traversal order is
    %% undefined. Use declaration positions; prelude entries pass `undefined`
    %% to `at_loc/2`.
    LocOf = maps:from_list(Locs),
    %% Imports retain their declaration-site resolution. Local and prelude
    %% entries resolve against an environment containing those imports.
    Own = lists:sort(maps:keys(prelude()) ++ maps:keys(Local)),
    lists:foldl(
      fun(N, Acc) ->
              case maps:get(N, Env) of
                  {parametric, _, _} = P -> Acc#{N => P};
                  T ->
                      Loc = maps:get(N, LocOf, undefined),
                      Acc#{N => at_loc(Loc,
                                       fun() ->
                                           bs_types:mu(N, resolve(T, Env, [N]))
                                       end)}
              end
      end, Imported, Own).

alias([], Body)     -> Body;
alias(Params, Body) -> {parametric, Params, Body}.

%% Source order is deliberate: report the first duplicate at its second
%% declaration, carrying the first position, and stop.
type_redeclared(Locs) ->
    type_redeclared(lists:keysort(2, Locs), #{}).

type_redeclared([], _Seen) ->
    ok;
type_redeclared([{N, L} | Rest], Seen) ->
    case Seen of
        #{N := First} -> erlang:error({type_redeclared, N, L, First});
        _             -> type_redeclared(Rest, Seen#{N => L})
    end.

%% Reachable modules supply `Mod.Name`; namespace imports supply `Short.Name`;
%% module imports supply bare names. Ambiguities are refused at use sites. Full
%% names win over short names, so `Orders` is not hidden by `Shop.Orders`.
imported_types(no_imports, _World) ->
    #{};
imported_types(Imports, World) ->
    Full = maps:fold(fun(M, Entry, Acc) ->
                             maps:fold(fun(N, T, In) ->
                                               In#{qualified(M, N) => T}
                                       end, Acc, maps:get(types, Entry, #{}))
                     end, #{}, World),
    Short = maps:fold(fun(S, Ms, Acc) -> short_types(S, Ms, World, Acc) end,
                      #{}, maps:get(mods, Imports)),
    Bare = maps:map(fun(N, [M]) -> world_type(M, N, World);
                       (_N, Ms) -> {ambiguous, lists:sort(Ms)}
                    end, maps:get(types, Imports)),
    maps:merge(maps:merge(Short, Full), Bare).

short_types(S, [M], World, Acc) ->
    maps:fold(fun(N, T, In) -> In#{qualified(S, N) => T} end, Acc,
              maps:get(types, maps:get(M, World), #{}));
short_types(S, Ms, World, Acc) ->
    Names = lists:usort(lists:append([maps:keys(maps:get(types, maps:get(M, World), #{}))
                                      || M <- Ms])),
    lists:foldl(fun(N, In) -> In#{qualified(S, N) => {ambiguous, lists:sort(Ms)}} end,
                Acc, Names).

world_type(M, N, World) ->
    maps:get(N, maps:get(types, maps:get(M, World))).

%% The prelude combines ordinary aliases and compiler-known types.
prelude() -> maps:merge(stratum_one(), stratum_two()).

%% Lowercase prelude aliases cannot collide with PascalCase user aliases.
stratum_one() ->
    #{option => {parametric, ['T'],
                 {t_union, [{t_ref, 'T'}, {t_atom, nothing}]}},
      result => {parametric, ['T', 'E'],
                 {t_union, [{t_ref, 'T'},
                            {t_tuple, [{t_atom, error}, {t_ref, 'E'}]}]}},
      %% Exception classes are distinct by tag, so collapse checks accept them.
      foreign_error =>
          {t_union, [{t_tuple, [{t_atom, error}, {t_builtin, term}]},
                     {t_tuple, [{t_atom, throw}, {t_builtin, term}]},
                     {t_tuple, [{t_atom, exit},  {t_builtin, term}]}]}}.

%% `ValidationError` is the validator's record payload: path and expected type.
%% `record_of/3` and `bs_emit:record_tag/2` read its tag from this map layout.
%% Its bare tag cannot collide with user record tags, which contain a dot.
%% `compiler_known_redeclared/1` prevents shadowing; merge order does not.
%% Rationale: compiler/features/F49-validation-error-record.md.
stratum_two() ->
    #{'ValidationError' =>
          {t_map, [{field, 'Kind', {t_atom, 'ValidationError'}},
                   {field, 'Path', {t_generic, list, [{t_builtin, string}]}},
                   {field, 'Expected', {t_builtin, string}}]},
      %% F60 (ticket 88): the tuples OTP sends, named by `bs_types:views/0`.
      'Down' =>
          {t_tuple, [{t_atom, 'DOWN'},
                     {t_builtin, reference},
                     {t_union, [{t_atom, process}, {t_atom, port}]},
                     {t_union, [{t_builtin, pid}, {t_builtin, port},
                                {t_tuple, [{t_builtin, atom}, {t_builtin, atom}]}]},
                     {t_builtin, term}]},
      'Exit' =>
          {t_tuple, [{t_atom, 'EXIT'}, {t_builtin, pid}, {t_builtin, term}]}}.

%% F60: a view pattern is the tuple it names, with `_` where a part is unnamed.
%% A part the view does not have is refused as a record's unknown field is.
view_pattern(Line, Name, Fields) ->
    case maps:find(Name, bs_types:views()) of
        error -> none;
        {ok, {Tag, Declared}} ->
            [case lists:member(K, Declared) of
                 true  -> ok;
                 false -> erlang:error({pattern_field_unknown, Line, Name, K, Declared})
             end || {K, _} <- Fields],
            {ok, {p_tuple, Line,
                  [{p_atom, Line, Tag}
                   | [case lists:keyfind(F, 1, Fields) of
                          {F, P} -> P;
                          false  -> {p_wild, Line}
                      end || F <- Declared]]}}
    end.

%% The closed set of names after which `<` opens a type bracket rather than
%% a comparison. Checked here rather than in the lexer, because here a
%% built name, a decided-but-unbuilt name and a non-obligation differ.
%% Rationale: compiler/features/F6-angle-brackets.md.
codegen_obligations() -> ['ValidateAs', 'ParseAtom', 'ToExistingAtom', 'ToJson'].

%% The names this compiler generates code for. The unbuilt-obligation
%% diagnostic reads this list rather than carrying its own sentence, so it
%% cannot go stale when the next name is built.
built_obligations() -> ['ValidateAs', 'ParseAtom', 'ToExistingAtom', 'ToJson'].

%%% --- Reserved qualifiers ---
%%%
%%% Obligations are unqualified; operations require a qualifier.
%%% Rationale: compiler/features/F32-reserved-qualifiers.md.

%% `Map` is reserved even without operations.
reserved_qualifiers() -> ['List', 'Map', 'Term', 'Float'].

%% Lowering keys include arity, matching BEAM identity and preventing extra
%% arguments from being silently ignored.
reserved_table() ->
    [{'List', 'Sum', 1}, {'List', 'Length', 1}, {'List', 'Reverse', 1},
     {'List', 'Map', 2}, {'List', 'Filter', 2}, {'List', 'Fold', 3},
     {'Term', 'Compare', 2}, {'Float', 'FromInt', 1}].

%% `Reverse` preserves the call site's element type.
reserved_sig('List', 'Sum', 1, _ATys) ->
    {ok, {[bs_types:list(bs_types:int())], bs_types:int()}};
reserved_sig('Float', 'FromInt', 1, _ATys) ->
    {ok, {[bs_types:int()], bs_types:float_top()}};
reserved_sig('List', 'Length', 1, _ATys) ->
    {ok, {[bs_types:list(bs_types:term())], bs_types:int()}};
reserved_sig('List', 'Reverse', 1, [ATy]) ->
    {ok, {[bs_types:list(bs_types:term())],
          bs_types:list(bs_types:list_elem(ATy))}};
%% Function arguments accept wider domains and narrower codomains. `Fold` joins
%% the seed and callback result for its accumulator type.
reserved_sig('List', 'Map', 2, [ATy, FTy]) ->
    Elem = elem_expected(ATy),
    {ok, {[bs_types:list(bs_types:term()), bs_types:fun_ty([Elem], bs_types:term())],
          bs_types:list(codomain(FTy, 1))}};
reserved_sig('List', 'Filter', 2, [ATy, _FTy]) ->
    Elem = elem_expected(ATy),
    {ok, {[bs_types:list(bs_types:term()), bs_types:fun_ty([Elem], bool())],
          bs_types:list(Elem)}};
reserved_sig('List', 'Fold', 3, [ATy, SeedTy, FTy]) ->
    Elem = elem_expected(ATy),
    Acc = bs_types:union(SeedTy, codomain(FTy, 2)),
    {ok, {[bs_types:list(bs_types:term()), Acc, bs_types:fun_ty([Acc, Elem], Acc)],
          Acc}};
reserved_sig('Term', 'Compare', 2, _ATys) ->
    %% Three singleton atoms enable exhaustive switches and named residuals.
    {ok, {[bs_types:term(), bs_types:term()], order_type()}};
reserved_sig(_Q, _Fun, _Arity, _ATys) -> error.

order_type() ->
    bs_types:union([bs_types:atom_lit(lt),
                    bs_types:atom_lit(eq),
                    bs_types:atom_lit(gt)]).

%% `unresolved/6` distinguishes an unknown name from a wrong arity.
reserved_arities(Q, Fun) ->
    [A || {Q1, F1, A} <- reserved_table(), Q1 =:= Q, F1 =:= Fun].

%% Every type-declaration form must reject compiler-known names.
compiler_known_redeclared(Decls) ->
    Known = maps:keys(stratum_two()),
    Declared = [{N, L} || {type_alias,   L, N, _, _} <- Decls]
            ++ [{N, L} || {type_refined, L, N, _, _} <- Decls]
            ++ [{N, L} || {record_decl,  L, N, _}    <- Decls],
    case [{N, L} || {N, L} <- Declared, lists:member(N, Known)] of
        []             -> ok;
        [{N, L} | _]   -> erlang:error({compiler_known_type, N, L})
    end.

%% Records desugar to tagged maps; the algebra has no record node.
record_surface(Mod, Line, Name, Fields) ->
    %% Reject author `Kind` fields before minting overwrites them.
    case [F || F = {field, 'Kind', _} <- Fields] of
        [] -> ok;
        _  -> erlang:error({kind_field_is_minted, Line, Name})
    end,
    {t_map, [{field, 'Kind', {t_atom, qualified(Mod, Name)}} | Fields]}.

%% Mint tags from qualified names so records in different modules stay distinct.
qualified(Mod, Name) ->
    list_to_atom(atom_to_list(Mod) ++ "." ++ atom_to_list(Name)).

%% Preserve declared field order for the emitter; minted `Kind` is not assigned.
record_fields({t_map, Fields}) -> [N || {field, N, _} <- Fields, N =/= 'Kind'].

%% The record tag comes from the resolved type, matching `qualified/2` and
%% `bs_emit:record_tag/2`. Only one closed map with a singleton `Kind` is a
%% record.
%% Rationale: compiler/features/F22-record-pattern-and-binder.md.
record_of(Name, Line, Env) ->
    case resolve({t_ref, Name}, Env) of
        #{maps := [{closed, Fs}], atoms := {finite, []}, ints := [],
          floats := {finite, []}, tuples := [], lists := [], bins := [],
          opaques := [], funs := []} ->
            case maps:find('Kind', Fs) of
                {ok, #{atoms := {finite, [Tag]}, ints := [], floats := {finite, []},
                       tuples := [], lists := [], maps := [], bins := [],
                       opaques := [], funs := []}} ->
                    %% `Kind` is compiler-minted and cannot be written in a
                    %% record pattern.
                    {Tag, maps:keys(Fs) -- ['Kind']};
                _ -> erlang:error({not_a_record, Line, Name})
            end;
        _ -> erlang:error({not_a_record, Line, Name})
    end.

%% The emitter may pass surface types or already-resolved types. `Seen` tracks
%% aliases and constructor crossings: recursion must cross a constructor;
%% unions and refinements do not count. `$` keeps `'$ctor'` out of the
%% type-name grammar.
%% Rationale: compiler/features/F28-recursive-types.md.
resolve(T, Env) -> resolve(T, Env, []).

resolve(T, _Env, _Seen) when is_map(T) -> T;
resolve({t_atom, A}, _Env, _Seen)    -> bs_types:atom_lit(A);
%% Lowercase declared entries may be surface types during `type_env/1` or
%% resolved maps afterwards. They need the same cycle guard as aliases. The
%% environment distinguishes missing type arguments from unknown types.
resolve({t_builtin, B}, Env, Seen) ->
    case maps:get(B, Env, undefined) of
        {parametric, Params, _} ->
            erlang:error({needs_type_args, B, length(Params)});
        undefined -> builtin(B);
        T when is_map(T) -> T;
        Surface ->
            case revisit(B, Seen) of
                knot -> bs_types:recvar(B);
                new  -> bs_types:mu(B, resolve(Surface, Env, [B | Seen]))
            end
    end;
%% A contractive revisit returns a back-reference to the entering `mu`.
%% `bs_types:mu/2` drops unused binders.
resolve({t_ref, N}, Env, Seen) ->
    case revisit(N, Seen) of
        knot -> bs_types:recvar(N);
        new ->
            case maps:get(N, Env, undefined) of
                undefined -> erlang:error({unknown_type, N});
                {parametric, Params, _} ->
                    erlang:error({needs_type_args, N, length(Params)});
                %% Import collisions are refused at use, so unused collisions
                %% are valid. Qualified names disambiguate.
                {ambiguous, Mods} ->
                    erlang:error({ambiguous_type, N, Mods});
                T when is_map(T) -> T;
                Surface -> bs_types:mu(N, resolve(Surface, Env, [N | Seen]))
            end
    end;
resolve({t_tuple, Cs}, Env, Seen) ->
    bs_types:tuple([resolve(C, Env, ctor(Seen)) || C <- Cs]);
%% Declared maps are closed: extra fields make a different type.
resolve({t_map, Fields}, Env, Seen) ->
    bs_types:map_closed(
      maps:from_list([{N, resolve(T, Env, ctor(Seen))} || {field, N, T} <- Fields]));
%% F59: an open member admits keys it does not name.
resolve({t_map_open, Fields}, Env, Seen) ->
    bs_types:map_open(
      maps:from_list([{N, resolve(T, Env, ctor(Seen))} || {field, N, T} <- Fields]));
%% Lists are algebra primitives, not expressible as alias bodies.
resolve({t_generic, list, [T]}, Env, Seen) ->
    bs_types:list(resolve(T, Env, ctor(Seen)));
resolve({t_generic, list, Args}, _Env, _Seen) ->
    erlang:error({generic_arity, list, 1, length(Args)});
%% Domain maps are algebra primitives. `bs_types:map_dom/2` owns the `Kind`
%% exclusion.
resolve({t_generic, map, [K, V]}, Env, Seen) ->
    bs_types:map_dom(resolve(K, Env, ctor(Seen)), resolve(V, Env, ctor(Seen)));
resolve({t_generic, map, Args}, _Env, _Seen) ->
    erlang:error({generic_arity, map, 2, length(Args)});
%% Substitution removes type variables before the algebra sees the body.
%% Recursion keys on the resolved instantiation, not just the alias name.
%% Recurrence with different arguments is non-regular and must be refused to
%% avoid unbounded expansion.
resolve({t_generic, N, Args}, Env, Seen) ->
    case maps:get(N, Env, undefined) of
        undefined -> erlang:error({unknown_generic, N});
        {parametric, Params, Body} when length(Params) =:= length(Args) ->
            %% Resolve arguments in the caller's chain: they are siblings of
            %% this application, not descendants.
            RArgs = [resolve(A, Env, Seen) || A <- Args],
            Key = {N, RArgs},
            case revisit(Key, Seen) of
                knot -> bs_types:recvar(gen_name(Key));
                new ->
                    non_regular_check(N, RArgs, Seen),
                    Sub = maps:from_list(lists:zip(Params, RArgs)),
                    bs_types:mu(gen_name(Key),
                                resolve(subst(Body, Sub), Env, [Key | Seen]))
            end;
        {parametric, Params, _} ->
            erlang:error({generic_arity, N, length(Params), length(Args)});
        {ambiguous, Mods} ->
            erlang:error({ambiguous_type, N, Mods});
        _Ground ->
            erlang:error({not_parametric, N})
    end;
resolve({t_union, Ms}, Env, Seen) ->
    bs_types:union([resolve(M, Env, Seen) || M <- Ms]);
%% Both arrow domains and codomains count as constructor crossings.
resolve({t_fun, Ds, C}, Env, Seen) ->
    bs_types:fun_ty([resolve(D, Env, ctor(Seen)) || D <- Ds],
                    resolve(C, Env, ctor(Seen)));
%% A refinement is a subset of its base, not a constructor crossing.
resolve({t_refined, Line, Base, Pred}, Env, Seen) ->
    refine(resolve(Base, Env, Seen), Pred, Line).

%% Refinements and guards share `alternatives/1`; `value` names the whole type
%% at the empty path. Unreadable refinements must error: resolving to the base
%% would silently widen the declared type.
refine(Base, Pred, Line) ->
    case alternatives(Pred) of
        unknown -> erlang:error({opaque_refinement, Line});
        Alts ->
            Results = [refine_all(Base, #{value => []}, A) || A <- Alts],
            case lists:member(none_marker, Results) of
                %% `none_marker` means a name other than `value` was read.
                true  -> erlang:error({opaque_refinement, Line});
                false ->
                    Refined = bs_types:union(Results),
                    case bs_types:is_none(Refined) of
                        %% An empty parameter refinement would make a function
                        %% uncallable.
                        true  -> erlang:error({empty_refinement, Line});
                        false -> Refined
                    end
            end
    end.

%% One marker per descent; constructor components are siblings.
ctor(Seen) -> ['$ctor' | Seen].

%% The caller binds a contractive revisit; other cycles are errors. Keys are
%% alias atoms or `{Name, ResolvedArgs}` instantiations.
revisit(Key, Seen) ->
    case lists:member(Key, Seen) of
        false -> new;
        true  ->
            Since = lists:takewhile(fun(E) -> E =/= Key end, Seen),
            case lists:member('$ctor', Since) of
                true  -> knot;
                false -> erlang:error({cyclic_type, key_name(Key)})
            end
    end.

key_name({N, _}) -> N;
key_name(N)      -> N.

%% Hash resolved arguments so repeated instantiations use the same binder.
gen_name({N, RArgs}) ->
    list_to_atom(atom_to_list(N) ++ "$" ++ integer_to_list(erlang:phash2(RArgs))).

non_regular_check(N, RArgs, Seen) ->
    case [K || {M, A} = K <- Seen, M =:= N, A =/= RArgs] of
        []      -> ok;
        [_ | _] -> erlang:error({non_regular_recursion, N})
    end.

%% Substituted arguments are resolved maps; `resolve/3` passes them through
%% without re-walking them.
subst(T, _Sub) when is_map(T)      -> T;
subst({t_ref, N} = T, Sub)         -> maps:get(N, Sub, T);
subst({t_union, Ms}, Sub)          -> {t_union, [subst(M, Sub) || M <- Ms]};
subst({t_tuple, Cs}, Sub)          -> {t_tuple, [subst(C, Sub) || C <- Cs]};
subst({t_generic, N, Args}, Sub)   -> {t_generic, N, [subst(A, Sub) || A <- Args]};
subst({t_fun, Ds, C}, Sub)         -> {t_fun, [subst(D, Sub) || D <- Ds], subst(C, Sub)};
subst({t_map, Fields}, Sub) ->
    {t_map, [{field, N, subst(T, Sub)} || {field, N, T} <- Fields]};
subst({t_map_open, Fields}, Sub) ->
    {t_map_open, [{field, N, subst(T, Sub)} || {field, N, T} <- Fields]};
subst(T, _Sub)                     -> T.

builtin(int)  -> bs_types:int();
%% BEAM floats are disjoint from integers.
builtin(float) -> bs_types:float_top();
builtin(atom) -> bs_types:atom_top();
builtin(term) -> bs_types:term();
builtin(none) -> bs_types:none();
builtin(bool) -> bs_types:union(bs_types:atom_lit(true), bs_types:atom_lit(false));
%% `string` is the valid UTF-8 subset of `binary`.
builtin(binary) -> bs_types:binary_top();
builtin(string) -> bs_types:string();
%% F60 (ticket 88 Q3): opaque, each decided by one guard; `pid` carries no
%% message type (ticket 14 §1).
builtin(pid)       -> bs_types:opaque(pid);
builtin(reference) -> bs_types:opaque(reference);
builtin(port)      -> bs_types:opaque(port);
builtin(B)    -> erlang:error({unknown_builtin, B}).

%%% Checking one function

check_fn(F = #fn{name = Name, line = Line, params = Params, ret = Ret}, Ctx0) ->
    %% Type variables stay opaque in the declaration and body environment.
    Env = opaque_env(F#fn.tvars, Ctx0#ctx.types),
    %% Exhaustiveness uses the parameter product: redundancy can span columns.
    Declared = bs_types:tuple([resolve(T, Env) || {param, T, _} <- Params]),
    Ctx = Ctx0#ctx{types = Env, ret = resolve(Ret, Env), fname = Name,
                   arity = length(Params), tvars = F#fn.tvars,
                   params = [{PName, resolve(T, Env)} || {param, T, PName} <- Params]},
    case F#fn.clauses of
        [] ->
            {F, [{error, Line, Name, no_clauses}]};
        Clauses ->
            {Residual, Diags0} =
                case map_pattern_diags(Clauses, Params, Env, Name)
                     ++ recoverable_diags(F)
                     ++ opacity_diags(Clauses, Params, F#fn.tvars, Name) of
                    %% Reject unsupported domain-map destructuring before the
                    %% walk. Empty the residual to suppress a consequential
                    %% inexhaustive error.
                    [_ | _] = Ds -> {bs_types:none(), Ds};
                    []           -> walk(Clauses, Declared, Declared, Ctx, [], 1)
                end,
            Diags = with_corrected_signature(F, Ctx#ctx.ret, Env, Diags0),
            Final =
                case bs_types:is_none(Residual) of
                    true  -> Diags;
                    %% Keep the residual as a type so the caller can print a
                    %% clause head.
                    false -> Diags ++ [{error, Line, Name,
                                       {inexhaustive, Residual,
                                        record_names(Env)}}]
                end,
            {F, Final}
    end.

%%% Corrected signatures
%%% Union all clauses' return residuals before attaching one correction
%%% throughout the function. Synthesis is limited to heads, never bodies.
%%% Rationale: compiler/features/F25-corrected-signature.md.

with_corrected_signature(F, Declared, Env, Diags) ->
    case [R || {error, _, _, {return_not_declared, R}} <- Diags] of
        []  -> Diags;
        Rs  -> C = corrected_signature(F, Declared, bs_types:union(Rs), Env),
               [attach_correction(D, C) || D <- Diags]
    end.

attach_correction({error, L, N, {return_not_declared, R}}, C) ->
    {error, L, N, {return_not_declared, R, C}};
attach_correction(D, _C) ->
    D.

%% What `bs_diag` is handed, one of four:
%%
%%   Line                       the signature to paste
%%   {replacing, Line, D, New}  the same, where it drops the declared `D`
%%                              because `New` contains it
%%   {refused, {SA, A}, {SB, B}, Records}
%%                              no clause head can tell `A` from `B`, which
%%                              the author wrote as `SA` and `SB`; `Records`
%%                              is the named type of records to use instead,
%%                              or why none is shown
%%   {withhold, Why}            no line, and `Why` says why
%%
%% A line never disappears without a reason and never replaces the declared
%% type silently. Each travels with the declared return as written, because
%% every return mismatch leads with the clause: the signature states intent.
corrected_signature(F = #fn{ret = Ret}, Declared, Union, Env) ->
    {declared_text(Ret, Declared), correction_of(F, Declared, Union, Env)}.

%% Prose preserves written names and inline-map field order; algebra text is a
%% fallback, never source to paste.
declared_text(Ret, Declared) ->
    case written(Ret) of
        none -> bs_types:to_string(Declared);
        Src  -> Src
    end.

written({t_map, Fields}) ->
    joined("{ ", [field_written(F) || F <- Fields], ", ", " }");
written({t_map_open, Fields}) ->
    joined("{ ", [field_written(F) || F <- Fields] ++ [".."], ", ", " }");
%% Preserve inline maps inside composites too; `type_source/1` refuses them.
written({t_union, Ms}) ->
    joined("", [written(M) || M <- Ms], " | ", "");
written({t_tuple, Cs}) ->
    joined("(", [written(C) || C <- Cs], ", ", ")");
written({t_generic, N, As}) ->
    joined(atom_to_list(N) ++ "<", [written(A) || A <- As], ", ", ">");
written({t_fun, Ds, C}) ->
    case {joined("fn(", [written(D) || D <- Ds], ", ", ") -> "), written(C)} of
        {none, _} -> none;
        {_, none} -> none;
        {D, S}    -> D ++ S
    end;
written(T) ->
    type_source(T).

joined(Open, Parts, Sep, Close) ->
    case lists:member(none, Parts) of
        true  -> none;
        false -> lists:flatten([Open, lists:join(Sep, Parts), Close])
    end.

field_written({field, Name, T}) ->
    case written(T) of
        none -> none;
        S    -> lists:flatten([bs_types:key_str(Name), ": ", S])
    end.

correction_of(F, Declared, Union, Env) ->
    case signature_line(F, Declared, Union) of
        {withhold, _} = Withheld -> Withheld;
        {Line, Replaced} ->
            case {as_pasted(Line, Env), Replaced} of
                {ok, none}       -> Line;
                {ok, {Src, New}} -> {replacing, Line, Src, New};
                {Refusal, _}     -> as_written(Refusal, F, Line, Env)
            end
    end.

%%% Refusals in the author's words
%%% Pair resolved members with written names, falling back to algebra text for
%%% unnamed constituents. Repair advice uses two named records and a named
%%% union; `Kind` remains compiler-minted.

as_written({refused, A, B}, F, Line, Env) ->
    Ms = returned_members(Line),
    {refused, {written_as(A, Ms, Env), A}, {written_as(B, Ms, Env), B},
     records_for(F, Ms, A, B, Env)};
as_written({withhold, {absorbed_member, M, By}}, _F, Line, Env) ->
    {withhold, {absorbed_member, {written_as(M, returned_members(Line), Env), M}, By}};
as_written(Refusal, _F, _Line, _Env) ->
    Refusal.

returned_members(Line) ->
    {signature, _, _, Ret, _, _, _} = pasted_signature(Line),
    return_members(Ret).

return_members({t_union, Ms}) -> Ms;
return_members(T)             -> [T].

written_as(T, Ms, Env) ->
    case locate(T, Ms, Env) of
        {top, _, W}    -> source_or_printed(W, T);
        {arg, _, _, W} -> source_or_printed(W, T);
        none           -> bs_types:to_string(T)
    end.

source_or_printed(W, T) ->
    case type_source(W) of
        none -> bs_types:to_string(T);
        Src  -> Src
    end.

%% Only top-level members and generic arguments placed directly in a union have
%% replaceable positions. A list element is not a union member.
locate(T, Ms, Env) ->
    case [{top, I, W} || {I, W} <- lists:enumerate(Ms), equivalent(resolve(W, Env), T)] of
        [P | _] -> P;
        []      -> case [{arg, I, K, A} || {I, W} <- lists:enumerate(Ms),
                                           {K, A} <- member_args(W, Env),
                                           equivalent(resolve(A, Env), T)] of
                       [P | _] -> P;
                       []      -> none
                   end
    end.

member_args({t_generic, N, Args}, Env) ->
    case maps:get(N, Env, undefined) of
        {parametric, Ps, {t_union, Body}} when length(Ps) =:= length(Args) ->
            [{K, A} || {K, {P, A}} <- lists:enumerate(lists:zip(Ps, Args)),
                       lists:member({t_ref, P}, Body)];
        _ ->
            []
    end;
member_args(_, _Env) ->
    [].

%% Aliases and expansions are equivalent by value set, not term identity.
equivalent(S, T) -> bs_types:is_subtype(S, T) andalso bs_types:is_subtype(T, S).

%% Record advice requires written positions for both members; members hidden
%% inside resolved aliases cannot be safely rewritten.
records_for(F, Ms, A, B, Env) ->
    case {locate(A, Ms, Env), locate(B, Ms, Env)} of
        {none, _} ->
            {no_records, nested(A, Ms, Env)};
        {_, none} ->
            {no_records, nested(B, Ms, Env)};
        %% Two generic arguments cannot share one replacement position.
        {{arg, _, _, _}, {arg, J, _, _}} ->
            {no_records, nested(B, [lists:nth(J, Ms)], Env)};
        {PA, PB} ->
            {First, Second, Place} = placed(PA, PB),
            declared_records(F, First, Second, Place, Ms, Env)
    end.

%% Keep the generic position to preserve its wrapper; otherwise keep the first
%% written member.
placed({top, I, WA}, {top, J, WB}) when I < J -> {WA, WB, {top, I, J}};
placed({top, I, WA}, {top, J, WB})            -> {WB, WA, {top, J, I}};
placed({arg, I, K, WA}, {top, J, WB})         -> {WA, WB, {arg, I, K, J}};
placed({top, J, WB}, {arg, I, K, WA})         -> {WA, WB, {arg, I, K, J}}.

nested(T, Ms, Env) ->
    Holder = [W || W <- Ms, bs_types:is_subtype(T, resolve(W, Env))],
    {nested, bs_types:to_string(T), holder_source(Holder)}.

holder_source([W | _]) ->
    case type_source(W) of
        none -> "the declared type";
        Src  -> Src
    end;
holder_source([]) ->
    "the declared type".

declared_records(F, First, Second, Place, Ms, Env) ->
    {Union, R1, R2} = placeholders(Env),
    Renamed = renamed(Place, Ms, {t_ref, list_to_atom(Union)}),
    case [type_source(T) || T <- [First, Second, Renamed]] of
        [S1, S2, Returns] when S1 =/= none, S2 =/= none, Returns =/= none ->
            Decls = ["record " ++ R1 ++ " { Value: " ++ S1 ++ " }",
                     "record " ++ R2 ++ " { Value: " ++ S2 ++ " }",
                     "type " ++ Union ++ " = " ++ R1 ++ " | " ++ R2],
            case declarations_pasted(Decls, line_of(F, Returns), Env) of
                ok  -> {records, Decls, Returns};
                Why -> {no_records, Why}
            end;
        _ ->
            {no_records, {check_failed, unwritable}}
    end.

renamed({top, Keep, Drop}, Ms, Name) ->
    union_node([case I of Keep -> Name; _ -> W end
                || {I, W} <- lists:enumerate(Ms), I =/= Drop]);
renamed({arg, Keep, K, Drop}, Ms, Name) ->
    union_node([case I of Keep -> with_arg(W, K, Name); _ -> W end
                || {I, W} <- lists:enumerate(Ms), I =/= Drop]).

with_arg({t_generic, N, Args}, K, Name) ->
    {t_generic, N, [case J of K -> Name; _ -> A end || {J, A} <- lists:enumerate(Args)]}.

union_node([One]) -> One;
union_node(Many)  -> {t_union, Many}.

%% Placeholder names must avoid the module's existing types. Check without
%% creating atoms: unused names have no environment keys. Names are chosen per
%% function and may collide across suggestions; authors must choose distinct
%% names when combining them.
placeholders(Env) -> placeholders("Name", Env).

placeholders(Base, Env) ->
    Names = [Base, Base ++ "1", Base ++ "2"],
    case lists:any(fun(S) -> in_env(S, Env) end, Names) of
        true  -> placeholders("New" ++ Base, Env);
        false -> list_to_tuple(Names)
    end.

in_env(S, Env) ->
    try maps:is_key(list_to_existing_atom(S), Env)
    catch error:badarg -> false
    end.

%% Before printing, parse and declaration-check the suggested records and
%% signature in the author's environment. Refusal is a compiler defect.
declarations_pasted(Decls, Signature, Env) ->
    Src = lists:flatten([lists:join("\n", Decls ++ [Signature]), "\n"]),
    try
        {ok, Toks, _} = bs_lexer:string(Src),
        {ok, Parsed} = bs_parser:parse(Toks),
        {signature, _, _, Ret, _, _, _} = lists:last(Parsed),
        Env1 = with_declared(Env, lists:droplast(Parsed)),
        _ = resolve(Ret, Env1),
        collapse_refused(Parsed, Env1),
        ok
    catch
        _:Reason -> {check_failed, reason_name(Reason)}
    end.

%% Suggested records mint under the default module name; this check needs only
%% distinct tags. Resolve declarations as `type_env/1` does.
with_declared(Env, Decls) ->
    Mod = module_name([]),
    New = [{N, record_surface(Mod, L, N, Fs)} || {record_decl, L, N, Fs} <- Decls]
          ++ [{N, Body} || {type_alias, _, N, [], Body} <- Decls],
    Surface = maps:merge(Env, maps:from_list(New)),
    lists:foldl(fun({N, T}, Acc) -> Acc#{N => bs_types:mu(N, resolve(T, Surface, [N]))} end,
                Env, New).

%% Before printing, parse and resolve the signature in the module's type
%% environment, then run the declaration check shared by `check/2` and
%% `exports_of/1`. This catches unwritable types, indistinguishable members and
%% absorbed members. Unexpected failures withhold only the suggestion and carry
%% their class and reason to `bs_diag` as compiler defects.
as_pasted(Line, Env) ->
    case pasted_signature(Line) of
        none ->
            {withhold, unspellable};
        {signature, _, _, Ret, _, _, _} = Sig ->
            try
                _ = resolve(Ret, Env),
                collapse_decl(Sig, Env),
                ok
            catch
                error:{indiscriminable_union, _, _, A, B} ->
                    {refused, A, B};
                error:{absorbed_member, _, _, _, M, By} ->
                    {withhold, {absorbed_member, M, By}};
                error:{unknown_type, _} ->
                    {withhold, unspellable};
                error:{unknown_builtin, _} ->
                    {withhold, unspellable};
                Class:Reason ->
                    {withhold, {crashed, Class, reason_name(Reason)}}
            end
    end.

pasted_signature(Line) ->
    case bs_lexer:string(Line ++ "\n") of
        {ok, Toks, _} ->
            case bs_parser:parse(Toks) of
                {ok, [{signature, _, _, _, _, _, _} = Sig]} -> Sig;
                _                                        -> none
            end;
        _ ->
            none
    end.

%% OTP error reasons are atoms or atom-led tuples. Keep only the reason name:
%% the `~0p` descriptor must not carry types or source fragments.
reason_name(R) when is_tuple(R), tuple_size(R) > 0 -> element(1, R);
reason_name(R)                                     -> R.

%% Withhold signatures containing unwritable residuals or declared forms. Keep
%% this function's name: naming it `pasteable` creates that atom before
%% `bs_diag` creates `kind`, changing `~0p` map-key order between batch and
%% standalone runs.
signature_line(F = #fn{ret = Ret, params = Params}, Declared, Union) ->
    Rendered = bs_types:to_string(Union),
    case writable(Rendered) of
        false -> {withhold, unspellable};
        true  ->
            case {type_source(Ret), params_source(Params)} of
                {none, _} -> {withhold, declared_form};
                {_, none} -> {withhold, declared_form};
                {RetSrc, _Ps} ->
                    Absorbed = bs_types:is_subtype(Declared, Union),
                    Line = line_of(F, declared_member(Absorbed, RetSrc) ++ Rendered),
                    Replaced = Absorbed andalso not bs_types:is_none(Declared),
                    {Line, replaced(Replaced, RetSrc, Rendered)}
            end
    end.

%% Requires parameters accepted by `params_source/1`.
line_of(#fn{name = Name, params = Params, vis = Vis, tvars = TV}, RetText) ->
    lists:flatten([vis_source(Vis), RetText, " ", atom_to_list(Name),
                   vars_source(TV), "(", params_source(Params), ")"]).

vars_source([]) -> "";
vars_source(Vs) -> "<" ++ lists:join(", ", [atom_to_list(V) || V <- Vs]) ++ ">".

%% Concatenate source to preserve the declared alias name. Omit it when the
%% resolved residual contains it, since absorbed members are refused.
%% Subtraction can overapproximate: a domain-map residual may still contain the
%% declared type.
declared_member(true, _RetSrc) -> "";
declared_member(false, RetSrc) -> RetSrc ++ " | ".

%% Report a replaced type by its written name. Exclude `none`: every type
%% contains it.
replaced(true, RetSrc, Rendered) -> {RetSrc, Rendered};
replaced(false, _RetSrc, _Rendered) -> none.

%% Check rendered text: `bs_types` prints unwritable record field sets with
%% braces and binary complements with backslashes, even inside composites.
writable(S) ->
    string:find(S, "{") =:= nomatch andalso string:find(S, "\\") =:= nomatch.

%% Preserve the original visibility in the suggested signature.
vis_source(public) -> "public ";
vis_source(_)      -> "".

params_source(Params) ->
    Rendered = [param_source(P) || P <- Params],
    case lists:member(none, Rendered) of
        true  -> none;
        false -> lists:join(", ", Rendered)
    end.

param_source({param, T, Name}) ->
    case type_source(T) of
        none -> none;
        S    -> S ++ " " ++ atom_to_list(Name)
    end.

%% Render declarations from the AST to preserve writable record names; algebra
%% text exposes minted tags. Unknown forms withhold the whole line. Atom
%% quoting follows the type printer's source-spelling rules.
type_source({t_atom, A})        -> bs_types:atom_str(A);
type_source({t_builtin, B})     -> atom_to_list(B);
type_source({t_ref, N})         -> atom_to_list(N);
type_source({t_tuple, Cs})      -> bracket("(", Cs, ", ", ")");
type_source({t_union, Ms})      -> join_source(Ms, " | ");
type_source({t_generic, N, As}) ->
    case bracket("<", As, ", ", ">") of
        none -> none;
        S    -> atom_to_list(N) ++ S
    end;
type_source({t_fun, Ds, C}) ->
    case {join_source(Ds, ", "), type_source(C)} of
        {none, _}    -> none;
        {_, none}    -> none;
        {DsS, CS}    -> "fn(" ++ DsS ++ ") -> " ++ CS
    end;
%% Inline maps may carry `Kind` fields and are not rendered as suggestions.
%% Named records arrive as `t_ref` and remain writable.
type_source({t_map, _Fields})   -> none;
type_source({t_map_open, _})    -> none;
type_source(_)                  -> none.

join_source(Ts, Sep) ->
    Rendered = [type_source(T) || T <- Ts],
    case lists:member(none, Rendered) of
        true  -> none;
        false -> lists:flatten(lists:join(Sep, Rendered))
    end.

bracket(Open, Ts, Sep, Close) ->
    case join_source(Ts, Sep) of
        none -> none;
        S    -> Open ++ S ++ Close
    end.

%%% Scope
%%% Report unbound names against source, before `erlc` sees emitted forms.
%%% Bindings cannot shadow. These checks are syntactic, not type inference.
%%% Rationale: compiler/features/F8-bind-and-match.md.

scope_diags({clause, Line, Name, Patterns, Guard, Body}) ->
    {Bound, HeadDiags} = head_scope(Patterns, Line, Name),
    HeadDiags ++
    %% Guards see only clause-head bindings.
    guard_scope(Guard, Bound, Line, Name) ++ check_scope(Body, Bound, Name, Line, []).

%% Repeated bare head names must be refused: the checker treats variables as
%% covering the domain, but Erlang repeats impose equality. Duplicates must be
%% caught before `pattern_row/2` silently merges their bindings. Heads match
%% simultaneously, so `== name` may refer left or right.
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
    %% Head match references must resolve within the head itself.
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
             ({dbind, L, P, E}, {B, A}) ->
                  bind_names(E, pattern_vars(P), B, L, Name, A)
          end, {Bound0, Acc0}, Binds),
    %% The parser gives the final expression no line; use the clause's line.
    name_diags(Final, Bound, Line, Name, Acc);
check_scope(Final, Bound, Name, Line, Acc) ->
    name_diags(Final, Bound, Line, Name, Acc).

%% Read the right-hand side before introducing names; bindings cannot shadow.
bind_names(Expr, Vars, Bound, Line, Name, Acc) ->
    Acc1 = name_diags(Expr, Bound, Line, Name, Acc),
    lists:foldl(
      fun(V, {B, A}) ->
              case lists:member(V, B) of
                  true  -> {B, [{error, Line, Name, {rebinding, V}} | A]};
                  false -> {[V | B], A}
              end
      end, {Bound, Acc1}, Vars).

name_diags(Expr, Bound, Line, Name, Acc) ->
    [{error, Line, Name, {unbound_variable, V}}
     || V <- lists:usort(expr_vars(Expr)), not lists:member(V, Bound)]
        ++ rebinds(Expr, Bound, Name) ++ Acc.

%% Reject switch-arm rebinding: Erlang treats an already-bound pattern variable
%% as an equality test. Traverse generically below special cases because
%% switches can occur anywhere in an expression.
rebinds({e_switch, _, Subject, Arms}, Bound, Name) ->
    rebinds(Subject, Bound, Name)
        ++ lists:append([arm_rebinds(A, Bound, Name) || A <- Arms]);
%% Lambda parameters cannot shadow outer bindings or repeat each other.
rebinds({e_lambda, Line, Params, Body}, Bound, Name) ->
    Vars = lists:append([pattern_vars(P) || P <- Params]),
    Dups = Vars -- lists:usort(Vars),
    [{error, Line, Name, {rebinding, V}}
     || V <- lists:usort(Vars ++ Dups), lists:member(V, Bound) orelse lists:member(V, Dups)]
        ++ rebinds(Body, Bound ++ Vars, Name);
rebinds(T, Bound, Name) when is_tuple(T) -> rebinds(tuple_to_list(T), Bound, Name);
rebinds(L, Bound, Name) when is_list(L) ->
    lists:append([rebinds(E, Bound, Name) || E <- L]);
rebinds(_, _, _) -> [].

arm_rebinds({arm, Line, P, Guard, Body}, Bound, Name) ->
    Vars = pattern_vars(P),
    Inner = Bound ++ Vars,
    [{error, Line, Name, {rebinding, V}}
     || V <- lists:usort(Vars), lists:member(V, Bound)]
    %% Arm match references must resolve before emission to Erlang.
        ++ [{error, Line, Name, {unbound_variable, V}}
            || V <- lists:usort(pattern_matched_vars(P)),
               not lists:member(V, Bound ++ Vars)]
        ++ rebinds(Body, Inner, Name)
        ++ case Guard of none -> []; {guard, G} -> rebinds(G, Inner, Name) end.

pattern_vars({p_var, _, V})            -> [V];
%% Segment sizes read names; only segment binders introduce them.
pattern_vars({p_bin, _, Segs})         ->
    [V || {seg_bind, _, V, _} <- Segs];
pattern_vars({p_tuple, _, Ps})         -> lists:append([pattern_vars(P) || P <- Ps]);
pattern_vars({p_map, _, Fs})           -> lists:append([pattern_vars(P) || {_, P} <- Fs]);
%% Record type names bind nothing; their field patterns bind normally.
pattern_vars({p_rec, _, _, Fs})        -> lists:append([pattern_vars(P) || {_, P} <- Fs]);
%% A trailing binder and its nested pattern both introduce names.
pattern_vars({p_bind, _, V, P})        -> [V | pattern_vars(P)];
%% A type prefix binds only its trailing name.
pattern_vars({p_type, _, _, V})        -> [V];
pattern_vars({p_list, _, Items, Rest}) ->
    lists:append([pattern_vars(P) || P <- Items])
        ++ case Rest of nil -> []; R -> pattern_vars(R) end;
%% `p_eqvar` is deliberately absent: it reads a value without binding.
pattern_vars(_)                        -> [].

%% A pattern can both bind and read names; keep these walks separate.
pattern_matched_vars({p_eqvar, _, V})          -> [V];
pattern_matched_vars({p_tuple, _, Ps})         ->
    lists:append([pattern_matched_vars(P) || P <- Ps]);
pattern_matched_vars({p_map, _, Fs})           ->
    lists:append([pattern_matched_vars(P) || {_, P} <- Fs]);
pattern_matched_vars({p_rec, _, _, Fs})        ->
    lists:append([pattern_matched_vars(P) || {_, P} <- Fs]);
pattern_matched_vars({p_bind, _, _, P})        -> pattern_matched_vars(P);
pattern_matched_vars({p_list, _, Items, Rest}) ->
    lists:append([pattern_matched_vars(P) || P <- Items])
        ++ case Rest of nil -> []; R -> pattern_matched_vars(R) end;
pattern_matched_vars(_)                        -> [].

%% Reads free variables; the emitter's `used_vars/2` decides underscoring.
expr_vars({e_var, _, V})               -> [V];
expr_vars({e_proj, _, V, _})           -> [V];
expr_vars({e_tuple, _, Es})            -> lists:append([expr_vars(E) || E <- Es]);
expr_vars({e_call, _, _, As})          -> lists:append([expr_vars(A) || A <- As]);
%% Type arguments contain no value variables.
expr_vars({e_inst, _, _, _, As})       -> lists:append([expr_vars(A) || A <- As]);
expr_vars({e_foreign_call, _, _, _, As}) -> lists:append([expr_vars(A) || A <- As]);
expr_vars({e_qcall, _, _, _, As})        -> lists:append([expr_vars(A) || A <- As]);
expr_vars({e_op, _, _, A, B})          -> expr_vars(A) ++ expr_vars(B);
expr_vars({e_neg, _, E})               -> expr_vars(E);
expr_vars({e_record, _, _, Fs})        -> lists:append([expr_vars(E) || {_, E} <- Fs]);
expr_vars({e_map, _, Fs})              -> lists:append([expr_vars(E) || {_, E} <- Fs]);
expr_vars({e_with, _, Base, Fs})       ->
    expr_vars(Base) ++ lists:append([expr_vars(E) || {_, E} <- Fs]);
expr_vars({e_list, _, Items, Rest})    ->
    lists:append([expr_vars(E) || E <- Items])
        ++ case Rest of nil -> []; R -> expr_vars(R) end;
expr_vars({e_block, _, Binds, Final})  ->
    lists:append([expr_vars(element(4, B)) || B <- Binds]) ++ expr_vars(Final);
%% Subtract pattern bindings per arm; sibling arms do not share scope.
expr_vars({e_switch, _, Subject, Arms}) ->
    expr_vars(Subject) ++ lists:append([arm_free_vars(A) || A <- Arms]);
expr_vars({e_valve, _, Switch})        -> expr_vars(Switch);
expr_vars({e_raise, _, Reason})        -> expr_vars(Reason);
%% Lambda parameters are local to the body; applying a bound name reads it.
expr_vars({e_lambda, _, Params, Body}) ->
    Bound = lists:append([pattern_vars(P) || P <- Params]),
    [V || V <- expr_vars(Body), not lists:member(V, Bound)];
expr_vars({e_apply, _, V, As})         -> [V | lists:append([expr_vars(A) || A <- As])];
expr_vars(_)                           -> [].

arm_free_vars({arm, _, P, Guard, Body}) ->
    Bound = pattern_vars(P),
    Read = case Guard of none -> []; {guard, G} -> expr_vars(G) end ++ expr_vars(Body),
    [V || V <- Read, not lists:member(V, Bound)].

%%% --- The body check ---
%%%
%%% Containment sites: call argument, construction, projection, clause return
%%% and destructuring bind. Structural expressions synthesise types.
%%% Construction reports field names: closed maps with different keys are
%%% disjoint. Other sites report residuals rendered as clause heads.
%%% Rationale: compiler/features/F5-body-check-site.md.

clause_diags(C = {clause, Line, _, Patterns, Guard, Body}, Domain, GuardDomain,
             Bindings, Ctx0) ->
    case segment_diags(Patterns, Ctx0#ctx.fname) of
        %% Broken segment bindings make downstream type diagnostics invalid.
        [_ | _] = SegErrors -> SegErrors;
        [] -> clause_diags_1(C, Line, Patterns, Guard, Body, Domain, GuardDomain,
                             Bindings, Ctx0)
    end.

clause_diags_1(C, Line, Patterns, Guard, Body, Domain, GuardDomain, Bindings, Ctx0) ->
    guard_diags(Guard, Ctx0) ++
    case scope_diags(C) of
        [] ->
            Ctx = Ctx0#ctx{binds = Bindings},
            Scope = clause_scope(Patterns, Bindings, Domain),
            GuardScope = clause_scope(Patterns, Bindings, GuardDomain),
            %% The declared return supplies a body lambda's expected arrow.
            {Ty, Diags} = expected(Body, Ctx#ctx.ret, Scope, Ctx),
            mixed_guard_diags(Guard, GuardScope, Ctx) ++ Diags
                ++ return_diags(Ty, Line, Ctx);
        Errors ->
            %% Unbound names yield `term`; skip typing to avoid cascading
            %% errors.
            Errors
    end.

%% Guard refinement credits only readable guards. This check retains numeric
%% refusals: the emitter adds integer tests to integer comparisons, so a float
%% compared against an int literal would silently never match.
mixed_guard_diags(none, _Scope, _Ctx) -> [];
mixed_guard_diags({guard, Expr}, Scope, Ctx) ->
    %% `guard_diags/2` owns illegal-call errors. Typing such calls can raise,
    %% including on inaccessible qualified modules; suppress those raises.
    try type_of(Expr, Scope, Ctx) of
        {_, Diags} -> [D || D <- Diags, keep_from_guard(D)]
    catch
        _:_ -> []
    end.

%% Preserve float-division sites for the emitter, including inside guards.
keep_from_guard({fdiv, _, _}) -> true;
keep_from_guard({vproj, _, _}) -> true;
keep_from_guard(D)            -> mixed_pair(D).

mixed_pair({error, _, _, {mixed_operands, _, _, _, _}}) -> true;
%% Numeric-union refusals must survive guard filtering too.
mixed_pair({error, _, _, {numeric_union_operand, _, _, _, _}}) -> true;
mixed_pair(_)                                           -> false.

%%% --- Binary patterns ---
%%%
%%% A size must name an earlier binding in the same pattern; an unbound size
%%% can compile in Erlang yet silently never match.

segment_diags(Patterns, Name) ->
    lists:append([bin_diags(P, Name) || P <- Patterns]).

bin_diags({p_bin, _, Segs}, Name)         -> seg_list_diags(Segs, Name);
bin_diags({p_tuple, _, Ps}, Name)         -> segment_diags(Ps, Name);
bin_diags({p_map, _, Fs}, Name)           -> segment_diags([P || {_, P} <- Fs], Name);
bin_diags({p_rec, _, _, Fs}, Name)        -> segment_diags([P || {_, P} <- Fs], Name);
bin_diags({p_bind, _, _, P}, Name)        -> bin_diags(P, Name);
bin_diags({p_list, _, Items, Rest}, Name) ->
    segment_diags(Items, Name)
        ++ case Rest of nil -> []; R -> bin_diags(R, Name) end;
bin_diags(_, _)                           -> [].

seg_list_diags(Segs, Name) ->
    lists:reverse(element(2, lists:foldl(
        fun(Seg, {Bound, Acc}) ->
            {seg_binds(Seg) ++ Bound, seg_diags(Seg, Segs, Bound, Name) ++ Acc}
        end, {[], []}, Segs))).

seg_binds({seg_bind, _, V, _}) -> [V];
seg_binds(_)                   -> [].

seg_diags(Seg, All, Bound, Name) ->
    size_diags(Seg, All, Bound, Name) ++ literal_diags(Seg, Name).

%% Erlang requires an unsized remainder segment to be last.
size_diags(Seg, All, Bound, Name) when element(1, Seg) =:= seg_bind;
                                       element(1, Seg) =:= seg_wild ->
    Line = element(2, Seg),
    Size = element(tuple_size(Seg), Seg),
    Last = lists:last(All),
    case Size of
        rest when Seg =/= Last ->
            [{error, Line, Name, {unsized_segment_not_last, Size, Line}}];
        {width, N} when not (is_integer(N) andalso N > 0) ->
            [{error, Line, Name, {segment_width_not_positive, N, Line}}];
        {sized_by, V} ->
            case lists:member(V, Bound) of
                true  -> [];
                false -> [{error, Line, Name, {segment_size_not_bound, V, Line}}]
            end;
        _ -> []
    end;
size_diags(_, _, _, _) -> [].

literal_diags({seg_int, Line, K, N}, Name) when is_integer(N), N > 0 ->
    Max = (1 bsl N) - 1,
    case K >= 0 andalso K =< Max of
        true  -> [];
        false -> [{error, Line, Name, {segment_literal_too_wide, K, N, Line}}]
    end;
literal_diags({seg_int, Line, _K, N}, Name) ->
    [{error, Line, Name, {segment_width_not_positive, N, Line}}];
literal_diags(_, _) -> [].

%% Guards share the expression grammar, so reject forms before emission: `_`
%% crashes `bs_emit:expr/2`; switches and raises are illegal Erlang guards.
%% Calls are legal only to guard BIFs, as defined by erl_internal:guard_bif/2.
%% Rationale: compiler/features/F41-call-in-guard.md.
guard_diags(none, _Ctx) -> [];
guard_diags({guard, Expr}, C) ->
    [{error, L, C#ctx.fname, wildcard_as_value} || L <- nodes_of(e_wild, Expr)]
        ++ [{error, L, C#ctx.fname, switch_in_guard} || L <- nodes_of(e_switch, Expr)]
        ++ [{error, L, C#ctx.fname, raise_in_guard} || L <- nodes_of(e_raise, Expr)]
        ++ [{error, L, C#ctx.fname, R}
            || Call <- subtrees_of([e_call, e_qcall, e_inst, e_foreign_call,
                                    e_apply, e_lambda, e_switch, e_raise], Expr),
               {L, R} <- guard_call(Call)].

%% Diagnostics preserve authored callee spelling, before import resolution.
%% Stop at switches and raises: their own errors cover nested calls.
guard_call({e_switch, _, _, _}) -> [];
guard_call({e_raise, _, _}) -> [];
guard_call({e_call, L, Name, _Args}) ->
    [{L, {call_in_guard, Name}}];
%% BEAM guards admit neither lambdas nor calls through bound names.
guard_call({e_apply, L, Var, _Args}) ->
    [{L, {call_in_guard, Var}}];
guard_call({e_lambda, L, _, _}) ->
    [{L, lambda_in_guard}];
guard_call({e_inst, L, Name, _TypeArgs, _Args}) ->
    [{L, {call_in_guard, Name}}];
guard_call({e_qcall, L, Mod, Fun, _Args}) ->
    [{L, {call_in_guard, qualified_name(Mod, Fun)}}];
guard_call({e_foreign_call, L, erlang, Fun, Args}) ->
    case erl_internal:guard_bif(Fun, length(Args)) of
        true  -> [];
        false -> [{L, {foreign_call_in_guard, foreign_name(erlang, Fun)}}]
    end;
guard_call({e_foreign_call, L, Mod, Fun, _Args}) ->
    [{L, {foreign_call_in_guard, foreign_name(Mod, Fun)}}].

%% Stop at matched nodes to avoid duplicate errors for nested refused forms.
%% All expression nodes carry their source line in the second tuple element.
nodes_of(Tag, T) -> [element(2, N) || N <- subtrees_of([Tag], T)].

subtrees_of(Tags, T) when is_tuple(T), tuple_size(T) > 0 ->
    case lists:member(element(1, T), Tags) of
        true  -> [T];
        false -> subtrees_of(Tags, tuple_to_list(T))
    end;
subtrees_of(Tags, L) when is_list(L) ->
    lists:append([subtrees_of(Tags, E) || E <- L]);
subtrees_of(_Tags, _) -> [].

%% Every emitted function has a -spec; the body must satisfy its return type.
return_diags(Ty, Line, #ctx{ret = Ret, fname = Name}) ->
    case bs_types:subtract(Ty, Ret) of
        R ->
            case bs_types:is_none(R) of
                true  -> [];
                false -> [{error, Line, Name, {return_not_declared, R}}]
            end
    end.

%% Read variable types from the refined domain at the recorded pattern path; a
%% bare variable's pattern type is only `term`.
clause_scope(Patterns, Bindings, Domain) ->
    Named = lists:append([pattern_vars(P) || P <- Patterns]),
    maps:from_list([{V, var_type(V, Bindings, Domain)} || V <- Named]).

var_type(V, Bindings, Domain) ->
    case maps:get(V, Bindings, undefined) of
        %% Unaddressable list-item bindings use the safe overestimate `term`.
        undefined -> bs_types:term();
        no_path   -> bs_types:term();
        Path      -> at_path(Domain, Path)
    end.

%% Union alternatives at each path step: tuple domains contain products, and
%% map domains contain members.
at_path(Ty, []) -> Ty;
at_path(#{tuples := top}, [I | _]) when is_integer(I) -> bs_types:term();
at_path(#{tuples := Products}, [I | Rest]) when is_integer(I) ->
    at_path(union_of([lists:nth(I, P) || P <- Products, length(P) >= I]), Rest);
at_path(#{maps := top}, [{field, _} | _]) -> bs_types:term();
at_path(#{maps := Members}, [{field, K} | Rest]) ->
    at_path(union_of([maps:get(K, Fs) || {_, Fs} <- Members, maps:is_key(K, Fs)]), Rest);
%% Binary types have no addressable components; the pattern's segment width
%% supplies the type instead.
at_path(_Ty, [{seg, SegTy} | Rest]) ->
    at_path(SegTy, Rest);
%% F56: the tail after string literals is a `string` exactly when the subject's
%% binary part is.
at_path(Ty, [{str_tail} | Rest]) ->
    Bin = bs_types:intersect(Ty, bs_types:binary_top()),
    Tail = case not bs_types:is_none(Bin)
                    andalso bs_types:is_subtype(Bin, bs_types:string()) of
               true  -> bs_types:string();
               false -> bs_types:binary_top()
           end,
    at_path(Tail, Rest);
at_path(Ty, [{elem} | Rest]) ->
    at_path(elem_of(Ty), Rest);
%% A non-empty list's tail may be empty, with the same element type.
at_path(Ty, [{tail} | Rest]) ->
    at_path(bs_types:list(elem_of(Ty)), Rest).

elem_of(Ty) -> bs_types:list_elem(Ty).

union_of([]) -> bs_types:none();
union_of(Ts) -> bs_types:union(Ts).

%%% --- Synthesis and containment ---

%% Nested calls are checked during synthesis, when argument types are known.
type_of({e_int, _, N}, _S, _C)  -> {bs_types:range(N, N), []};
type_of({e_float, _, F}, _S, _C) -> {bs_types:float_lit(F), []};
%% Unary minus preserves int/float kind; rewriting it as `0 - e` would
%% introduce mixed operands for floats. Other operand types yield `int`.
type_of({e_neg, _, E}, S, C) ->
    {Ty, D} = type_of(E, S, C),
    case in_part(Ty, float) of
        true  -> {bs_types:float_top(), D};
        false -> {bs_types:int(), D}
    end;
type_of({e_atom, _, A}, _S, _C) -> {bs_types:atom_lit(A), []};
%% The lexer guarantees UTF-8 for string literals; downstream passes trust it.
type_of({e_str, _, _}, _S, _C) -> {bs_types:string(), []};
type_of({e_var, _, V}, S, _C)   -> {maps:get(V, S, bs_types:term()), []};
%% `_` parses as an expression for destructuring, but erlc forbids it as a
%% value.
type_of({e_wild, L}, _S, C) ->
    {reported(), [{error, L, C#ctx.fname, wildcard_as_value}]};
%% A raise cannot return, so bottom satisfies any declared return and adds
%% nothing to the justified return type. Unlike reported(), it is not an error.
type_of({e_raise, _, Reason}, S, C) ->
    {_, D} = type_of(Reason, S, C),
    {bs_types:none(), D};
type_of({e_tuple, _, Es}, S, C) ->
    {Tys, D} = type_of_all(Es, S, C),
    {bs_types:tuple(Tys), D};
%% Arithmetic synthesises numeric types, not exact result intervals.
type_of({e_op, L, Op, A, B}, S, C) ->
    {ATy, D1} = type_of(A, S, C),
    {BTy, D2} = type_of(B, S, C),
    {Ty, D3} = op_result(Op, ATy, BTy, L, C),
    {Ty, D1 ++ D2 ++ D3 ++ divisor_diags(Op, BTy, L, C)};
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
%% Projection requires the field in every member; the residual names those
%% without.
type_of({e_proj, L, V, Field}, S, C) ->
    Recv = maps:get(V, S, bs_types:term()),
    case view_projection(Recv, Field) of
        {ok, Pos, Ty} -> {Ty, [{vproj, L, Pos}]};
        none          -> record_projection(L, Recv, Field, C)
    end;
%% F57: a brace with no type name builds an exact field set from its values'
%% types; the check sites compare it against what the site expects, as they do
%% any value. A repeated key is refused: an Erlang map literal keeps the last.
%% Rationale: compiler/features/F57-brace-expression.md.
type_of({e_map, L, Fields}, S, C) ->
    brace(L, Fields, fun(Es) -> type_of_all(Es, S, C) end, C);
%% Construction requires exactly the declared fields and their declared types.
type_of({e_record, L, Name, _Fields}, _S, C) when Name =:= 'Down'; Name =:= 'Exit' ->
    {reported(), [{error, L, C#ctx.fname, {view_constructed, Name}}]};
type_of({e_record, L, Name, Fields}, S, C) ->
    RecTy = maps:get(Name, C#ctx.types, undefined),
    %% Declared field types supply expectations for lambda values.
    {Tys, D} = record_field_types(Fields, RecTy, S, C),
    case RecTy of
        undefined ->
            {reported(), [{error, L, C#ctx.fname, {unknown_record, Name}} | D]};
        Ty ->
            case declared_fields(Ty) of
                unknown -> {Ty, D};
                Declared ->
                    Keys = [K || {K, _} <- Fields],
                    case field_delta(Keys, Declared) of
                        %% Check names first: undeclared keys have no type
                        %% against which to check their values.
                        {[], []} ->
                            {Ty, field_value_diags(Keys, Tys, Ty, Name, L, C) ++ D};
                        {Missing, Extra} ->
                            {Ty, [{error, L, C#ctx.fname,
                                   {field_set_mismatch, Name, construction,
                                    Missing, Extra}} | D]}
                    end
            end
    end;
%% Updates preserve the base type and check values against declared fields.
%% Every base member must carry each updated key; unions are checked per
%% member.
type_of({e_with, L, Base, Fields}, S, C) ->
    {T, D1} = type_of(Base, S, C),
    {Tys, D2} = type_of_all([E || {_, E} <- Fields], S, C),
    Keys = [K || {K, _} <- Fields],
    {Ty, D3} =
        case {declared_fields(T), record_name(T)} of
            {Declared, Name} when Declared =/= unknown, Name =/= unknown ->
                case lists:sort(Keys -- Declared) of
                    [] ->
                        {T, field_value_diags(Keys, Tys, T, Name, L, C)};
                    Extra ->
                        {T, [{error, L, C#ctx.fname,
                              {field_set_mismatch, Name, update, [], Extra}}]}
                end;
            _ ->
                with_subject(T, Keys, Tys, L, C)
        end,
    {Ty, D1 ++ D2 ++ D3};
%% A switch uses the clause walk over one synthesised column, sharing pattern
%% and guard refinement, certainty and residuals. Its type unions arm results.
type_of({e_switch, L, Subject, Arms}, S, C) ->
    {SubjTy, D0} = type_of(Subject, S, C),
    {Ty, D1} = switch_over(L, SubjTy, Arms, S, C, authored),
    {Ty, D0 ++ D1};
%% Check the switch generated by bs_lower. An infallible subject gets a valve
%% diagnostic; the generated value catch-all is exempt from authored-arm rules.
%% Rationale: compiler/features/F30-valve-short-circuit-set.md.
type_of({e_valve, L, {e_switch, _, Subject, Arms}}, S, C) ->
    {SubjTy, D0} = type_of(Subject, S, C),
    %% All but the last arm define the stop set; derive it from bs_lower's
    %% patterns so lowering and checking cannot disagree.
    StopPats = [P || {arm, _, P, _, _} <- lists:droplast(Arms)],
    StopTy = union_of([element(1, pattern_type(P, [], C#ctx.types))
                       || P <- StopPats]),
    case bs_types:is_none(bs_types:intersect(StopTy, SubjTy)) of
        true ->
            {reported(),
             D0 ++ [{error, L, C#ctx.fname, {valve_on_infallible, SubjTy}}]};
        false ->
            {Ty, D1} = switch_over(L, SubjTy, Arms, S, C, generated),
            %% bs_lower runs before typing and emits both stop arms. Prune
            %% unreachable arms before emission to avoid Dialyzer warnings.
            %% Keep the emptiness predicate identical to `arms/10`: disjoint
            %% stop patterns make each arm's domain its intersection with
            %% SubjTy. The note records dead arms; the stop set remains fixed.
            {Ty, D0 ++ D1 ++ prune_note(Arms, SubjTy, C)}
    end;
%% ValidateAs generates code for a concrete compile-time type; no runtime type
%% variable or callee survives. Check nested argument expressions even though
%% validation accepts any input type.
%% Rationale: compiler/features/F18-validate-as.md.
type_of({e_inst, L, 'ValidateAs', TypeArgs, Args}, S, C) ->
    {_, D0} = type_of_all(Args, S, C),
    case {TypeArgs, Args, over_variable(TypeArgs, C)} of
        {_, _, [V | _]} ->
            {reported(),
             D0 ++ [{error, L, C#ctx.fname,
                     {obligation_over_type_variable, 'ValidateAs', V}}]};
        {[TypeExpr], [_], []} ->
            %% resolve/2 owns diagnostics for unknown, cyclic or recursive
            %% types.
            Ty = resolve(TypeExpr, C#ctx.types),
            %% Fun types cannot be recovered at runtime for validation. Check
            %% member separability last so arrows and collapse each produce
            %% only their own diagnostic.
            case {has_arrow(Ty), validate_collapses(Ty, C#ctx.types)} of
                {true, _} ->
                    {reported(),
                     D0 ++ [{error, L, C#ctx.fname, {validate_over_arrow, Ty}}]};
                {_, true} ->
                    {reported(),
                     D0 ++ [{error, L, C#ctx.fname, {validate_collapses, Ty}}]};
                _ ->
                    case inseparable_pair(Ty) of
                        {A, B} ->
                            {reported(),
                             D0 ++ [{error, L, C#ctx.fname,
                                     {validate_indiscriminable, Ty, A, B}}]};
                        none ->
                            {validate_result(Ty, C#ctx.types), D0}
                    end
            end;
        _ ->
            {reported(),
             D0 ++ [{error, L, C#ctx.fname,
                     {obligation_arity, 'ValidateAs', length(TypeArgs),
                      length(Args)}}]}
    end;
%% ParseAtom generates matches from printed names to a finite set of atoms. Its
%% result is T | :nothing for strings naming no member.
%% Rationale: compiler/features/F39-parse-atom.md.
type_of({e_inst, L, 'ParseAtom', TypeArgs, Args}, S, C) ->
    {ATys, D0} = type_of_all(Args, S, C),
    case {TypeArgs, Args, over_variable(TypeArgs, C)} of
        {_, _, [V | _]} ->
            {reported(),
             D0 ++ [{error, L, C#ctx.fname,
                     {obligation_over_type_variable, 'ParseAtom', V}}]};
        {[TypeExpr], [_], []} ->
            Ty = resolve(TypeExpr, C#ctx.types),
            case parse_atom_members(Ty) of
                error ->
                    {reported(),
                     D0 ++ [{error, L, C#ctx.fname, {parse_atom_not_finite, Ty}}]};
                {ok, _} ->
                    parse_atom_arg(L, Ty, ATys, D0, C)
            end;
        _ ->
            {reported(),
             D0 ++ [{error, L, C#ctx.fname,
                     {obligation_arity, 'ParseAtom', length(TypeArgs),
                      length(Args)}}]}
    end;
%% to_json_refused/2 checks wire forms before body typing. Here T must be
%% ground and the argument must be contained in T, as for an ordinary call.
type_of({e_inst, L, 'ToJson', TypeArgs, Args}, S, C) ->
    case {TypeArgs, Args, over_variable(TypeArgs, C)} of
        {_, _, [V | _]} ->
            {_, D0} = type_of_all(Args, S, C),
            {reported(),
             D0 ++ [{error, L, C#ctx.fname,
                     {obligation_over_type_variable, 'ToJson', V}}]};
        {[TypeExpr], [_], []} ->
            Ty = resolve(TypeExpr, C#ctx.types),
            {ATys, D0} = expected_all(Args, [Ty], S, C),
            {bs_types:string(), arg_diags(L, 'ToJson', Args, ATys, [Ty], 1, C) ++ D0};
        _ ->
            {_, D0} = type_of_all(Args, S, C),
            {reported(),
             D0 ++ [{error, L, C#ctx.fname,
                     {obligation_arity, 'ToJson', length(TypeArgs),
                      length(Args)}}]}
    end;
%% ToExistingAtom takes no type argument, but remains in the parser's closed
%% bracket-name set so an instantiation gets an arity diagnostic.
type_of({e_inst, L, 'ToExistingAtom', TypeArgs, Args}, S, C) ->
    to_existing_atom(L, TypeArgs, Args, S, C);
type_of({e_inst, L, Name, _TypeArgs, Args}, S, C) ->
    {_, D0} = type_of_all(Args, S, C),
    Reason = case lists:member(Name, codegen_obligations()) of
                 true  -> {obligation_unbuilt, Name};
                 false -> {not_an_obligation, Name}
             end,
    {reported(), D0 ++ [{error, L, C#ctx.fname, Reason}]};
%% Must precede user-function lookup; compiler_known_function/1 reserves this
%% name against user declarations.
type_of({e_call, L, 'ToExistingAtom', Args}, S, C) ->
    to_existing_atom(L, [], Args, S, C);
type_of({e_call, L, Name, Args}, S, C) ->
    call(L, unqualified_key(Name, length(Args), L, C), Name, Args, S, C);
%% A lambda requires an expected arrow; type_of/3 has no expectation.
type_of({e_lambda, L, _Params, _Body}, _S, C) ->
    {reported(), [{error, L, C#ctx.fname, lambda_without_expectation}]};
type_of({e_fname, L, Name, unknown}, S, C) ->
    case declared_arities(Name, C) of
        [N]  -> fname_type(L, Name, N, S, C);
        Many -> {reported(), [{error, L, C#ctx.fname, {name_arity_unfixed, Name, Many}}]}
    end;
type_of({e_fname, L, Name, Arity}, S, C) ->
    fname_type(L, Name, Arity, S, C);
%% Callable types contain only arrows of the requested arity. Arguments must
%% fit the meet of domains; results join codomains. `term` is not callable.
%% Rationale: compiler/features/F46-function-as-a-value.md.
type_of({e_apply, L, V, Args}, S, C) ->
    Ty = maps:get(V, S, bs_types:term()),
    N = length(Args),
    Arrows = case bs_types:arrows(Ty) of
                 top -> [];
                 Fs  -> Fs
             end,
    Callable = Arrows =/= []
        andalso lists:all(fun({Ds, _}) -> length(Ds) =:= N end, Arrows)
        andalso bs_types:is_none(bs_types:subtract(Ty, bs_types:funs_of(Ty))),
    case {bs_types:is_none(Ty), Callable} of
        {true, _} ->
            %% Suppress a second error for an already-refused expression.
            {_, D} = type_of_all(Args, S, C),
            {reported(), D};
        {_, false} ->
            {_, D} = type_of_all(Args, S, C),
            {reported(), D ++ [{error, L, C#ctx.fname, {not_callable, V, N, Ty}}]};
        {_, true} ->
            Doms = [lists:foldl(fun bs_types:intersect/2, bs_types:term(),
                                [lists:nth(I, Ds) || {Ds, _} <- Arrows])
                    || I <- lists:seq(1, N)],
            {ATys, D} = expected_all(Args, Doms, S, C),
            Ret = bs_types:union([Cod || {_, Cod} <- Arrows]),
            {Ret, arg_diags(L, V, Args, ATys, Doms, 1, C) ++ D}
    end;
type_of({e_foreign_call, L, Mod, Fun, Args}, S, C) ->
    call(L, {f, Mod, Fun, length(Args)}, foreign_name(Mod, Fun), Args, S, C);
type_of({e_qcall, L, Mod0, Fun, Args}, S, C) ->
    %% Handle reserved qualifiers before import resolution: they have no
    %% entries in the import tables.
    case lists:member(Mod0, reserved_qualifiers()) of
        true  -> reserved_call(L, Mod0, Fun, Args, S, C);
        false ->
            Mod = qualified_module(Mod0, L, C),
            call(L, {q, Mod, Fun, length(Args)}, qualified_name(Mod, Fun),
                 Args, S, C)
    end;
type_of(_, _S, _C) ->
    {bs_types:term(), []}.

%% Codegen type arguments must be ground before resolve/2: signature variables
%% erase to names absent from the emitter's validator environment.
over_variable(TypeArgs, C) ->
    lists:append([vars_in(T, C#ctx.tvars) || T <- TypeArgs]).

%% Namespace imports may shadow reserved qualifiers. Reject only ambiguous
%% short-qualified calls; imports, unqualified and fully qualified calls stand.
reserved_call(L, Q, Fun, Args, S, C) ->
    case maps:get(Q, maps:get(mods, C#ctx.imports, #{}), []) of
        [] -> reserved_op(L, Q, Fun, Args, S, C);
        Claimants ->
            {_ATys, D} = type_of_all(Args, S, C),
            {reported(),
             D ++ [{error, L, C#ctx.fname,
                    {reserved_qualifier_shadowed, Q, Fun, lists:sort(Claimants)}}]}
    end.

reserved_op(L, Q, Fun, Args, S, C) ->
    {ATys, D} = reserved_args(Q, Fun, Args, S, C),
    case reserved_sig(Q, Fun, length(Args), ATys) of
        error ->
            {reported(),
             D ++ [{error, L, C#ctx.fname,
                    {unknown_reserved_operation, Q, Fun, length(Args),
                     reserved_arities(Q, Fun)}}]};
        {ok, {Ps, Ret}} ->
            {Ret, arg_diags(L, qualified_name(Q, Fun), Args, ATys, Ps, 1, C) ++ D}
    end.

%% Type the list before the callback to supply its element-type expectation.
%% Fold also needs an accumulator expectation computed by iteration.
reserved_args('List', Op, [Xs, F], S, C) when Op =:= 'Map'; Op =:= 'Filter' ->
    {XTy, D1} = type_of(Xs, S, C),
    Elem = elem_expected(XTy),
    Cod = case Op of 'Map' -> bs_types:term(); 'Filter' -> bool() end,
    {FTy, D2} = expected(F, bs_types:fun_ty([Elem], Cod), S, C),
    {[XTy, FTy], D1 ++ D2};
reserved_args('List', 'Fold', [Xs, Seed, F], S, C) ->
    {XTy, D1} = type_of(Xs, S, C),
    {STy, D2} = type_of(Seed, S, C),
    {FTy, D3} = fold_fun(F, STy, elem_expected(XTy), S, C, 3),
    {[XTy, STy, FTy], D1 ++ D2 ++ D3};
reserved_args(_Q, _Fun, Args, S, C) ->
    type_of_all(Args, S, C).

%% Join the seed with callback results until the accumulator stabilises. After
%% three growing iterations, type the callback once more over `term`.
fold_fun(F, _Acc, Elem, S, C, 0) ->
    expected(F, bs_types:fun_ty([bs_types:term(), Elem], bs_types:term()), S, C);
fold_fun(F, Acc, Elem, S, C, N) ->
    {FTy, D} = expected(F, bs_types:fun_ty([Acc, Elem], bs_types:term()), S, C),
    Acc1 = bs_types:union(Acc, codomain(FTy, 2)),
    case bs_types:is_subtype(Acc1, Acc) of
        true  -> {FTy, D};
        false -> fold_fun(F, Acc1, Elem, S, C, N - 1)
    end.

bool() -> bs_types:union(bs_types:atom_lit(true), bs_types:atom_lit(false)).

%% Bottom after a diagnostic satisfies enclosing containment checks,
%% suppressing cascading errors.
reported() -> bs_types:none().

%% Build result<T, ValidationError> from the standard environment's entry so
%% the validator's failure type cannot drift from its declaration.
validate_result(Ty, Env) ->
    bs_types:union(Ty, validate_error(Env)).

validate_error(Env) ->
    bs_types:tuple([bs_types:atom_lit(error),
                    maps:get('ValidationError', Env)]).

%% Reject targets that absorb the validator's tagged failure member.
validate_collapses(Ty, Env) ->
    absorbed(validate_error(Env), Ty).

%% T | M equals T exactly when M is a subtype of T. Validation and declaration
%% checks share this predicate to keep their collapse rules aligned.
absorbed(Member, Others) -> bs_types:is_subtype(Member, Others).

%% Validator members must be separable by clause heads. Declaration checking
%% asks only whether patterns reach members, which does not ensure separation.
inseparable_pair(Ty) ->
    first_inseparable(bs_types:constituents(Ty)).

first_inseparable([]) ->
    none;
first_inseparable([A | Rest]) ->
    case [B || B <- Rest, not bs_types:separable(A, B)] of
        [B | _] -> {A, B};
        []      -> first_inseparable(Rest)
    end.

%%% --- ParseAtom<T> ---

%% Require a nonempty finite atom union with no other type parts. Checking only
%% atoms would silently discard other members; cofinite sets cannot be
%% enumerated for code generation.
parse_atom_members(#{atoms := {finite, As}, ints := [], floats := {finite, []},
                     tuples := [], lists := [], maps := [], bins := [],
                     opaques := [], funs := []}) when As =/= [] ->
    {ok, lists:usort(As)};
parse_atom_members(_) ->
    error.

%% Binary input distinguishes an unknown name from a value that is not a name.
%% `none` suppresses duplicate diagnostics for an already-refused argument.
parse_atom_arg(L, Ty, [ATy], D0, C) ->
    case bs_types:is_subtype(ATy, bs_types:binary_top()) of
        true  -> {bs_types:union(Ty, bs_types:atom_lit(nothing)), D0};
        false -> {reported(),
                  D0 ++ [{error, L, C#ctx.fname, {parse_atom_arg, ATy}}]}
    end.

%%% --- `ToExistingAtom` ---

%% The result includes the tagged failure even if the signature omits it. Input
%% must be `string`: failure returns the name as a string, and
%% `binary_to_existing_atom` raises `badarg` for both invalid UTF-8 and missing
%% names. `none` suppresses duplicate argument diagnostics.
%% Rationale: compiler/features/F54-to-existing-atom.md.
to_existing_atom(L, [], [Arg], S, C) ->
    {[ATy], D0} = type_of_all([Arg], S, C),
    case bs_types:is_subtype(ATy, bs_types:string()) of
        true  -> {existing_atom_result(), D0};
        false -> {reported(),
                  D0 ++ [{error, L, C#ctx.fname, {to_existing_atom_arg, ATy}}]}
    end;
to_existing_atom(L, TypeArgs, Args, S, C) ->
    {_, D0} = type_of_all(Args, S, C),
    {reported(),
     D0 ++ [{error, L, C#ctx.fname,
             {obligation_arity, 'ToExistingAtom', length(TypeArgs), length(Args)}}]}.

existing_atom_result() ->
    bs_types:union(bs_types:atom_top(),
                   bs_types:tuple([bs_types:atom_lit(error), bs_types:string()])).

%% `type_of/3` intercepts this name before callee lookup, so signatures and
%% clauses must both reject redeclarations.
compiler_known_function(Decls) ->
    Declared = [{N, L} || {signature, L, N, _, _, _, _} <- Decls]
            ++ [{N, L} || {clause, L, N, _, _, _} <- Decls],
    case [{N, L} || {N, L} <- Declared, N =:= 'ToExistingAtom'] of
        []           -> ok;
        [{N, L} | _] -> erlang:error({compiler_known_function, N, L})
    end.

%%% --- `ToJson<T>` ---
%%%
%%% `json:encode` rejects tuples, arrows and invalid UTF-8 binaries. Walk the
%%% resolved type to find these behind aliases; `term` admits them too. Check
%%% clause bodies in the declaration pass: `bsc --api` skips typing bodies.
%%% Rationale: compiler/features/F50-to-json.md.

to_json_refused(Decls, Env) ->
    TVars = maps:from_list([{{N, length(Ps)}, TV}
                            || {signature, _, N, _, Ps, _, TV} <- Decls]),
    lists:foreach(
      fun({clause, _, Fn, Ps, _, _} = Clause) ->
              Vars = maps:get({Fn, length(Ps)}, TVars, []),
              lists:foreach(
                fun({e_inst, L, 'ToJson', [TE], _}) ->
                        to_json_site(L, Fn, TE, Vars, Env)
                end, to_json_nodes(Clause));
         (_) ->
              ok
      end, Decls).

%% Walk arbitrary expression positions without duplicating the node grammar.
%% The dependency is `bs_emit` -> `bs_check`; this cannot call the emitter's
%% equivalent walk.
to_json_nodes(T) when is_tuple(T) ->
    Here = case T of
               {e_inst, _, 'ToJson', [_], _} -> [T];
               _                             -> []
           end,
    Here ++ to_json_nodes(tuple_to_list(T));
to_json_nodes(L) when is_list(L) -> lists:append([to_json_nodes(E) || E <- L]);
to_json_nodes(_)                 -> [].

%% `type_of/3` diagnoses type variables; `resolve/2` diagnoses resolution
%% failures. Catch all resolution errors here to avoid duplicate reports.
to_json_site(L, Fn, TE, Vars, Env) ->
    Resolved = case vars_in(TE, Vars) of
                   [] -> try {ok, resolve(TE, Env)} catch error:_ -> skip end;
                   _  -> skip
               end,
    case Resolved of
        {ok, Ty} ->
            case unencodable(Ty) of
                none ->
                    ok;
                {Segs, Member, Kind} ->
                    erlang:error({unencodable_member, L, Fn, Ty, Segs, Member, Kind})
            end;
        skip ->
            ok
    end.

%% Return `{Segments, Member, Kind}` or `none`. Segments use `.Field`, `[_]`
%% for elements/values and `[key]` for keys. Member is the failing constituent,
%% not the whole union.
unencodable(Ty) -> unencodable(Ty, [], []).

unencodable(#{mu := N} = T, Segs, Seen) ->
    case lists:member(N, Seen) of
        true  -> none;
        false -> unencodable(bs_types:unfold(T), Segs, [N | Seen])
    end;
unencodable(#{recvar := _}, _Segs, _Seen) ->
    none;
unencodable(T, Segs, Seen) ->
    #{tuples := Ts, funs := Fs, bins := Bs, maps := Ms, opaques := Os} = T,
    At = lists:reverse(Segs),
    %% F59: an open member would publish keys no type declares.
    Open = is_list(Ms) andalso lists:any(fun({open, _}) -> true; (_) -> false end, Ms),
    case bs_types:is_subtype(bs_types:term(), T) orelse Ms =:= top of
        true -> {At, T, term};
        false when Ts =/= [] -> {At, holding(tuples, T), tuple};
        false when Fs =/= [] -> {At, holding(funs, T), arrow};
        false when Open      -> {At, open_member(T), open_map};
        %% F60: a process, reference or port has no value outside this VM.
        false when Os =/= [] -> {At, holding(opaques, T), opaque};
        false ->
            case lists:member(other, Bs) of
                true  -> {At, holding(bins, T), binary};
                false -> first_unencodable(inner_positions(T), Segs, Seen)
            end
    end.

%% The caller found this part non-empty; its constituent exists, so `hd/1` is
%% total.
holding(Part, T) ->
    hd([C || C <- bs_types:constituents(T), maps:get(Part, C) =/= []]).

%% The open member itself, since an exact map beside it encodes.
open_member(T) ->
    hd([C || C = #{maps := Ms} <- bs_types:constituents(T), is_list(Ms),
             lists:any(fun({open, _}) -> true; (_) -> false end, Ms)]).

%% Visit list elements first; sort map fields and visit domain keys before
%% values. Unknown member kinds must fail rather than silently count as
%% encodable.
inner_positions(#{maps := Ms} = T) ->
    Elem = bs_types:list_elem(T),
    [{"[_]", Elem} || not bs_types:is_none(Elem)]
    ++ lists:append(
         [case M of
              {dom, K, V} -> [{"[key]", K}, {"[_]", V}];
              {_, Fields} -> [{field_path_seg(F), maps:get(F, Fields)}
                              || F <- lists:sort(maps:keys(Fields))]
          end || M <- Ms]).

%% F58: `.Name` for a name key, `["key"]` for a string key, as the validator spells it.
field_path_seg(F) when is_atom(F)   -> "." ++ atom_to_list(F);
field_path_seg(F) when is_binary(F) -> "[" ++ bs_types:key_str(F) ++ "]".

first_unencodable([], _Segs, _Seen) ->
    none;
first_unencodable([{Seg, Ty} | Rest], Segs, Seen) ->
    case unencodable(Ty, [Seg | Segs], Seen) of
        none  -> first_unencodable(Rest, Segs, Seen);
        Found -> Found
    end.

type_of_all(Es, S, C) ->
    {Tys, Ds} = lists:unzip([type_of(E, S, C) || E <- Es]),
    {Tys, lists:append(Ds)}.

%%% --- The expected type ---
%%%
%%% Lambdas need an expected arrow; bare names use its arity. Declared types
%%% flow through result positions and components, not arbitrary operands. Keep
%%% the expectation outside `#ctx`, which every operand inherits.
%%% Rationale: compiler/features/F46-function-as-a-value.md.

expected(E = {e_lambda, _, _, _}, Ty, S, C) ->
    lambda_against(E, Ty, S, C);
expected({e_fname, L, Name, unknown}, Ty, S, C) ->
    Arities = case bs_types:arrows(Ty) of
                  top -> [];
                  Fs  -> lists:usort([length(Ds) || {Ds, _} <- Fs])
              end,
    case Arities of
        [N] -> fname_type(L, Name, N, S, C);
        _   -> type_of({e_fname, L, Name, unknown}, S, C)
    end;
expected({e_switch, L, Subject, Arms}, Ty, S, C) ->
    {SubjTy, D0} = type_of(Subject, S, C),
    {T, D1} = switch_over(L, SubjTy, Arms, S, C, authored, Ty),
    {T, D0 ++ D1};
expected({e_block, _, Binds, Final}, Ty, S, C) ->
    {S1, D1} = lists:foldl(fun(B, Acc) -> bind_step(B, Acc, C) end, {S, []}, Binds),
    {T, D2} = expected(Final, Ty, S1, C),
    {T, D1 ++ D2};
%% A brace's values take the field types the site expects, so a lambda there
%% has its arrow, as record construction's values have theirs.
expected({e_map, L, Fields}, Ty, S, C) ->
    brace(L, Fields,
          fun(Es) ->
              expected_all(Es, [brace_field(Ty, K) || {K, _} <- Fields], S, C)
          end, C);
expected({e_tuple, _, Es}, Ty, S, C) ->
    N = length(Es),
    {Tys, D} = expected_all(Es, [bs_types:tuple_comp(Ty, N, I) || I <- lists:seq(1, N)],
                            S, C),
    {bs_types:tuple(Tys), D};
expected({e_list, _, Items, Rest}, Ty, S, C) ->
    Elem = elem_expected(Ty),
    {Tys, D1} = expected_all(Items, [Elem || _ <- Items], S, C),
    {RestElem, D2} =
        case Rest of
            nil -> {bs_types:none(), []};
            R   -> {RT, RD} = expected(R, Ty, S, C), {elem_of(RT), RD}
        end,
    {bs_types:cons(union_of(Tys ++ [RestElem])), D1 ++ D2};
expected(E, _Ty, S, C) ->
    type_of(E, S, C).

expected_all(Es, Tys, S, C) ->
    {Out, Ds} = lists:unzip([expected(E, T, S, C) || {E, T} <- lists:zip(Es, Tys)]),
    {Out, lists:append(Ds)}.

%% Unfold recursive lists; a bare back-reference imposes no expectation.
elem_expected(Ty) ->
    case bs_types:unfold(Ty) of
        #{lists := _} = T -> bs_types:list_elem(T);
        _                 -> bs_types:term()
    end.

%% A bare back-reference imposes no expectation, as in `elem_expected/1`.
brace_field(#{recvar := _}, _K) -> bs_types:term();
brace_field(Ty, K)              -> field_type(Ty, K).

brace(L, Fields, TypeValues, C) ->
    Keys = [K || {K, _} <- Fields],
    case Keys -- lists:usort(Keys) of
        [Dup | _] ->
            {reported(), [{error, L, C#ctx.fname, {duplicate_field, Dup}}]};
        [] ->
            {Tys, D} = TypeValues([E || {_, E} <- Fields]),
            {bs_types:map_closed(maps:from_list(lists:zip(Keys, Tys))), D}
    end.

%% Unknown records and fields use synthesis; the field-set check diagnoses them
%% separately.
record_field_types(Fields, RecTy, S, C) when is_map(RecTy) ->
    case declared_fields(RecTy) of
        unknown  -> type_of_all([E || {_, E} <- Fields], S, C);
        Declared ->
            expected_all([E || {_, E} <- Fields],
                         [case lists:member(K, Declared) of
                              true  -> field_type(RecTy, K);
                              false -> bs_types:term()
                          end || {K, _} <- Fields], S, C)
    end;
record_field_types(Fields, _RecTy, S, C) ->
    type_of_all([E || {_, E} <- Fields], S, C).

%% Parameters must be irrefutable over the domain. Type the body against the
%% codomain, but retain its actual type for the site's containment check. Take
%% the first arrow of matching arity; declared functions have only one.
lambda_against({e_lambda, L, Params, Body}, Ty, S, C) ->
    N = length(Params),
    Candidates = case bs_types:arrows(Ty) of
                     top -> [];
                     Fs  -> [F || {Ds, _} = F <- Fs, length(Ds) =:= N]
                 end,
    case Candidates of
        [] ->
            {reported(), [{error, L, C#ctx.fname, lambda_without_expectation}]};
        [{Ds, Cod} | _] ->
            {Bound, D1} = lambda_params(Params, Ds, 1, L, C),
            {BodyTy, D2} = expected(Body, Cod, maps:merge(S, Bound), C),
            {bs_types:fun_ty(Ds, BodyTy), D1 ++ D2}
    end.

lambda_params([], [], _I, _L, _C) ->
    {#{}, []};
lambda_params([P | Ps], [D | Ds], I, L, C) ->
    {PTy, PBinds, Exact} = pattern_type(P, [], C#ctx.types),
    Residual = bs_types:subtract(D, PTy),
    Diag = case {Exact, bs_types:is_none(Residual)} of
               {true, true}  -> [];
               {_, false}    -> [{error, L, C#ctx.fname,
                                  {lambda_param_refuted, I, Residual}}];
               %% Inexact patterns understate the residual; use the whole
               %% domain.
               {false, true} -> [{error, L, C#ctx.fname,
                                  {lambda_param_refuted, I, D}}]
           end,
    Bound = maps:from_list([{V, at_path(D, Path)} || {V, Path} <- maps:to_list(PBinds)]),
    {Rest, Diags} = lambda_params(Ps, Ds, I + 1, L, C),
    {maps:merge(Bound, Rest), Diag ++ Diags}.

%% Resolve local names before imports. Pass the resolved key as a diagnostic
%% note so the emitter can emit the function reference without resolving again.
fname_type(L, Name, Arity, _S, C) ->
    Key = unqualified_key(Name, Arity, L, C),
    case maps:get(Key, C#ctx.callees, undefined) of
        undefined ->
            case private_callee(Key, Arity, C) of
                {yes, M} ->
                    {reported(),
                     [{error, L, C#ctx.fname, {private_function, M, Name, Arity}}]};
                no ->
                    unresolved(L, Key, Name, lists:seq(1, Arity), [], C)
            end;
        {Ps, Ret} ->
            {bs_types:fun_ty(Ps, Ret), [{fname, L, Key}]}
    end.

declared_arities(Name, C) ->
    Local = [A || {N, A} <- maps:keys(C#ctx.callees), N =:= Name],
    Imported = [A || {N, A} <- maps:keys(maps:get(funs, C#ctx.imports, #{})),
                     N =:= Name],
    lists:usort(Local ++ Imported).

codomain(Ty, N) ->
    case bs_types:arrows(Ty) of
        top -> bs_types:term();
        Fs  -> bs_types:union([Cod || {Ds, Cod} <- Fs, length(Ds) =:= N])
    end.

%% Polymorphic calls type expressions needing expectations after other
%% arguments, using their partial solution.
hungry({e_lambda, _, _, _})        -> true;
hungry({e_fname, _, _, unknown})   -> true;
hungry({e_switch, _, _, _})        -> true;
hungry({e_block, _, _, _})         -> true;
hungry({e_tuple, _, Es})           -> lists:any(fun hungry/1, Es);
hungry({e_list, _, Items, Rest})   ->
    lists:any(fun hungry/1, Items) orelse (Rest =/= nil andalso hungry(Rest));
hungry(_)                          -> false.

%% Validators accept `term` without checking its top fun part. Explicit arrows
%% require a function type that cannot be recovered at run time.
has_arrow(Ty) -> has_arrow(Ty, []).

has_arrow(#{mu := N} = T, Seen) ->
    not lists:member(N, Seen) andalso has_arrow(bs_types:unfold(T), [N | Seen]);
has_arrow(#{recvar := _}, _Seen) ->
    false;
has_arrow(T, Seen) ->
    case bs_types:arrows(T) of
        top -> false;
        []  -> lists:any(fun(Comp) -> has_arrow(Comp, Seen) end, bs_types:components(T));
        _   -> true
    end.

%% The valve must inspect the subject type before deciding to walk the arms.
switch_over(L, SubjTy, Arms, S, C, Origin) ->
    switch_over(L, SubjTy, Arms, S, C, Origin, none).

%% Pass the site's expectation to arm bodies so nested lambdas can be typed.
switch_over(L, SubjTy, Arms, S, C, Origin, Expect) ->
    %% Keep the declared subject alongside the shrinking residual so
    %% `redundancy/4` can distinguish vacuous patterns from shadowed arms.
    {Tys, Residual, D1} = arms(Arms, SubjTy, SubjTy, S, C, 1, [], [], Origin, Expect),
    D2 = case bs_types:is_none(Residual) of
             true  -> [];
             %% Render missing arms through the head channel with record names,
             %% so records use source patterns rather than erased map shapes.
             false -> [{error, L, C#ctx.fname,
                        {switch_inexhaustive, Residual,
                         record_names(C#ctx.types)}}]
         end,
    {union_of(Tys), D1 ++ D2}.

%% Check redundancy against the running residual. Pattern advice applies only
%% to authored arms; body, guard and exhaustiveness checks apply to both.
arms([], Residual, _Declared, _S, _C, _N, Tys, Diags, _Origin, _Expect) ->
    {Tys, Residual, Diags};
arms([{arm, AL, P, Guard, Body} | Rest], Residual, Declared, S, C, N, Tys, Diags, Origin,
     Expect) ->
    {PTy, Binds, Exact} = pattern_type(P, [], C#ctx.types),
    {Certain0, Possible} = apply_guard(PTy, Binds, Guard),
    %% Inexact patterns may bound Possible but cannot establish Certain.
    Certain = case Exact of true -> Certain0; false -> bs_types:none() end,
    D1 = case Origin of
             generated -> [];
             authored ->
                 %% Preserve the pre-guard pattern type to distinguish
                 %% shadowing, a vacuous pattern and an unsatisfiable guard.
                 case map_arm_deferred(P, Declared) of
                     %% Reject unsupported map patterns before redundancy: a
                     %% warning would allow a dead arm to compile.
                     true ->
                         [{error, AL, C#ctx.fname,
                           {map_pattern_deferred, arm, Declared}}];
                     false ->
                 case redundancy(PTy, Possible, Residual, Declared) of
                     vacuous    -> [{warning, AL, C#ctx.fname,
                                     {vacuous_arm, N, Declared}}];
                     dead_guard -> [{warning, AL, C#ctx.fname,
                                     {unsatisfiable_arm_guard, N}}];
                     shadowed   -> [{warning, AL, C#ctx.fname,
                                     {unreachable_arm, N}}];
                     live       -> []
                 end
                 end
                 %% Arms obey the same catch-all restrictions as clause heads.
                 ++ catch_all_diags({clause, AL, C#ctx.fname, [P], Guard, ignored},
                                    Residual, AL, C#ctx.fname,
                                    record_names(C#ctx.types))
         end,
    %% Type bodies against Possible: Certain is empty for untranslatable guards
    %% and would make every containment check pass.
    Domain = bs_types:intersect(Residual, Possible),
    %% Paths start at `[]`: a switch has one subject, not a parameter product.
    Scope = maps:merge(S, maps:from_list(
                            [{V, at_path(Domain, Path)}
                             || {V, Path} <- maps:to_list(Binds)])),
    %% Check guards before narrowing can erase mixed numeric operands. Suppress
    %% the contradictory dead-guard warning beside a mixed-pair error.
    GuardDomain = bs_types:intersect(Residual, PTy),
    GuardScope = maps:merge(S, maps:from_list(
                                 [{V, at_path(GuardDomain, Path)}
                                  || {V, Path} <- maps:to_list(Binds)])),
    D1g = mixed_guard_diags(Guard, GuardScope, C),
    D1b = case lists:any(fun mixed_pair/1, D1g) of
              true  -> [D || D <- D1,
                             D =/= {warning, AL, C#ctx.fname, {unsatisfiable_arm_guard, N}}];
              false -> D1
          end,
    {BodyTy, D2} = case Expect of
                       none -> type_of(Body, Scope, C);
                       _    -> expected(Body, Expect, Scope, C)
                   end,
    %% Unreachable generated arms contribute no type; otherwise stop arms widen
    %% the valve with impossible values. Authored arms retain their type. Check
    %% every body regardless of whether its type contributes.
    Tys1 = case Origin =:= generated andalso bs_types:is_none(Domain) of
               true  -> Tys;
               false -> Tys ++ [BodyTy]
           end,
    arms(Rest, bs_types:subtract(Residual, Certain), Declared, S, C, N + 1,
         Tys1, Diags ++ D1b ++ D1g ++ guard_diags(Guard, C) ++ D2, Origin, Expect).

%%% --- Pruning the valve's dead stop arms ---

%% Key dead stop arms by the error binder, unique per stage across the module
%% in `bs_lower`. Line numbers collide for nested valves on one line.
%% Rationale: compiler/features/F30-valve-short-circuit-set.md.
prune_note(Arms = [ErrArm | _], SubjTy, C) ->
    Stop = lists:droplast(Arms),
    Dead = [I || {I, {arm, _, P, _, _}} <- lists:enumerate(Stop),
                 bs_types:is_none(
                   bs_types:intersect(
                     element(1, pattern_type(P, [], C#ctx.types)), SubjTy))],
    case {Dead, binder(ErrArm)} of
        {[], _}          -> [];
        {_, undefined}   -> [];
        {_, B}           -> [{prune, B, Dead}]
    end.

binder({arm, _, {p_tuple, _, [{p_atom, _, error}, {p_var, _, V}]}, _, _}) -> V;
binder(_) -> undefined.

%% Valves can occur in any expression position. Prune the tree before `bs_emit`
%% consumes it; the emitter needs no type information.
prune_valves(T, Prunes) when map_size(Prunes) =:= 0 -> T;
prune_valves({e_valve, L, {e_switch, SL, Subj, Arms}}, Prunes) ->
    Arms1 = case binder(hd(Arms)) of
                undefined -> Arms;
                B ->
                    Dead = maps:get(B, Prunes, []),
                    Stop = lists:droplast(Arms),
                    Val  = lists:last(Arms),
                    [A || {I, A} <- lists:enumerate(Stop),
                          not lists:member(I, Dead)] ++ [Val]
            end,
    {e_valve, L, {e_switch, SL, prune_valves(Subj, Prunes),
                  prune_valves(Arms1, Prunes)}};
prune_valves(T, Prunes) when is_tuple(T) ->
    list_to_tuple(prune_valves(tuple_to_list(T), Prunes));
prune_valves([H | T], Prunes) ->
    [prune_valves(H, Prunes) | prune_valves(T, Prunes)];
prune_valves(X, _) -> X.

%% The emitter has no types; the `fdiv` note selects BEAM float division.
%% Reject mixed numeric parts instead of BEAM's implicit promotion. Both
%% operands must be inhabited to avoid cascading errors from `none`.
op_result(Op, ATy, BTy, L, C) ->
    case {part_of(ATy), part_of(BTy)} of
        {float, float} when Op =:= '/' ->
            {bs_types:float_top(), [{fdiv, L, float}]};
        {float, float} when Op =:= '+'; Op =:= '-'; Op =:= '*' ->
            {bs_types:float_top(), []};
        %% BEAM `rem` requires integers; float remainder would crash.
        {float, float} when Op =:= '%' ->
            {reported(), [{error, L, C#ctx.fname, float_remainder}]};
        {int, float} when Op =/= 'and', Op =/= 'or' ->
            {reported(), [mixed(Op, int, float, ATy, L, C)]};
        {float, int} when Op =/= 'and', Op =/= 'or' ->
            {reported(), [mixed(Op, float, int, BTy, L, C)]};
        _ ->
            union_result(Op, ATy, BTy, L, C)
    end.

%% Keep this operator set aligned with both mixed-part clauses above: every
%% operator except `and` and `or`. Both operands must be inhabited. Only wholly
%% numeric unions qualify; unions with other parts fall through.
%% Rationale: compiler/features/F53-numeric-union-dispatch.md.
union_result(Op, ATy, BTy, L, C) when Op =/= 'and', Op =/= 'or' ->
    Inhabited = fun(T) -> not bs_types:is_none(T) end,
    case {numeric_union(ATy) andalso Inhabited(BTy),
          numeric_union(BTy) andalso Inhabited(ATy)} of
        {true, _} -> {reported(), [union_operand(Op, left, ATy, L, C)]};
        {_, true} -> {reported(), [union_operand(Op, right, BTy, L, C)]};
        _         -> {op_type(Op), []}
    end;
union_result(Op, _ATy, _BTy, _L, _C) ->
    {op_type(Op), []}.

%% Inspect resolved types so aliases and refinements receive the same check.
numeric_union(Ty) ->
    Numeric = bs_types:union(bs_types:int(), bs_types:float_top()),
    not bs_types:is_none(Ty)
        andalso bs_types:is_subtype(Ty, Numeric)
        andalso not bs_types:is_subtype(Ty, bs_types:int())
        andalso not bs_types:is_subtype(Ty, bs_types:float_top()).

%% Dispatch advice must preserve the function's full parameter list and names.
%% Use the first numeric-union parameter, or `none` if none exists. A literal
%% conversion hint cannot separate a union's numeric parts.
union_operand(Op, Side, Ty, L, C) ->
    {error, L, C#ctx.fname, {numeric_union_operand, Op, Side, Ty,
                             advised_heads(C#ctx.params)}}.

%% `bs_diag` renders `{Before, Name, After}` as a typed parameter amid the
%% remaining names; `none` means no parameter can supply a head hint.
advised_heads(Params) ->
    Names = [N || {N, _} <- Params],
    case [I || {I, {_, T}} <- lists:enumerate(Params), numeric_union(T)] of
        [I | _] ->
            {lists:sublist(Names, I - 1), lists:nth(I, Names),
             lists:nthtail(I, Names)};
        [] ->
            none
    end.

%% The checker chooses the numeric parts and any literal conversion; `bs_diag`
%% only renders them.
mixed(Op, Left, Right, IntTy, L, C) ->
    Literal = case IntTy of
                  #{ints := [{N, N}]} when is_integer(N) -> integer_to_list(N) ++ ".0";
                  _                                       -> none
              end,
    {error, L, C#ctx.fname, {mixed_operands, Op, Left, Right, Literal}}.

part_of(Ty) ->
    case bs_types:is_none(Ty) of
        true  -> neither;
        false ->
            case {in_part(Ty, int), in_part(Ty, float)} of
                {true, _} -> int;
                {_, true} -> float;
                _         -> neither
            end
    end.

in_part(Ty, int)   -> bs_types:is_subtype(Ty, bs_types:int());
in_part(Ty, float) -> bs_types:is_subtype(Ty, bs_types:float_top()).

op_type('+') -> bs_types:int();
op_type('-') -> bs_types:int();
op_type('*') -> bs_types:int();
%% Arithmetic returns `int`, not an exact interval.
op_type('/') -> bs_types:int();
op_type('%') -> bs_types:int();
op_type(_)   -> bs_types:union(bs_types:atom_lit(true), bs_types:atom_lit(false)).

%% Reject provably zero divisors, including refinements and signed float zero.
%% Unknown divisors remain legal and may crash at run time. `erlc` folds only
%% literal pairs, so it does not diagnose `X div 0`.
divisor_diags(Op, BTy, L, C) when Op =:= '/'; Op =:= '%' ->
    Zero = bs_types:union([bs_types:range(0, 0),
                           bs_types:float_lit(0.0), bs_types:float_lit(-0.0)]),
    case not bs_types:is_none(BTy) andalso bs_types:is_subtype(BTy, Zero) of
        true  -> [{error, L, C#ctx.fname, {divide_by_zero, Op}}];
        false -> []
    end;
divisor_diags(_, _, _, _) -> [].

%% Bindings declare no expected type; their values require synthesis.
bind_step({bind, _, V, E}, {S, D}, C) ->
    {T, D1} = type_of(E, S, C),
    {S#{V => T}, D ++ D1};
%% Destructuring binds must be provably irrefutable.
bind_step({dbind, L, P, E}, {S, D}, C) ->
    %% Reject relational binds even when irrefutable: the emitter has no guard
    %% position for their test.
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
             %% Inexact patterns understate the residual; use the whole RHS.
             {false, true} -> [{error, L, C#ctx.fname, {bind_may_fail, T}}]
         end,
    Bound = maps:from_list([{V, at_path(T, Path)} || {V, Path} <- maps:to_list(PBinds)]),
    {maps:merge(S, Bound), D ++ D1 ++ D2 ++ RelDiags}.

%% Relational patterns can be nested in combinators and structural patterns.
has_rel({p_rel, _, _, _})        -> true;
has_rel({p_and, _, A, B})        -> has_rel(A) orelse has_rel(B);
has_rel({p_or,  _, A, B})        -> has_rel(A) orelse has_rel(B);
has_rel({p_tuple, _, Ps})        -> lists:any(fun has_rel/1, Ps);
has_rel({p_map, _, Fs})          -> lists:any(fun({_, P}) -> has_rel(P) end, Fs);
has_rel({p_rec, _, _, Fs})       -> lists:any(fun({_, P}) -> has_rel(P) end, Fs);
has_rel({p_bind, _, _, P})       -> has_rel(P);
has_rel({p_list, _, Items, Rest}) ->
    lists:any(fun has_rel/1, Items)
        orelse (Rest =/= nil andalso has_rel(Rest));
has_rel(_)                       -> false.

call(L, Key, Shown, Args, S, C) ->
    case maps:get(Key, C#ctx.callees, undefined) of
        undefined ->
            {_ATys, D} = type_of_all(Args, S, C),
            case private_callee(Key, length(Args), C) of
                {yes, M} ->
                    {reported(),
                     [{error, L, C#ctx.fname,
                       {private_function, M, Shown, length(Args)}} | D]};
                no -> unresolved(L, Key, Shown, Args, D, C)
            end;
        {Ps, Ret} when length(Ps) =/= length(Args) ->
            {_ATys, D} = type_of_all(Args, S, C),
            {Ret, [{error, L, C#ctx.fname,
                    {arity_mismatch, Shown, length(Args), length(Ps)}} | D]};
        {Ps, Ret} ->
            case maps:get(Key, C#ctx.polys, undefined) of
                undefined ->
                    {ATys, D} = expected_all(Args, Ps, S, C),
                    {Ret, arg_diags(L, Shown, Args, ATys, Ps, 1, C) ++ D};
                Template = {poly, _, PsT, RetT, _} ->
                    {ATys, D} = poly_args(Template, Args, S, C),
                    {Sub, Conflicts} = solution(Template, ATys),
                    case Conflicts of
                        [] ->
                            Inst = [subst_tpl(PT, Sub) || PT <- PsT],
                            {subst_tpl(RetT, Sub),
                             poly_arg_diags(L, Shown, Args, ATys, Ps, Inst, C) ++ D};
                        _ ->
                            {reported(),
                             arg_diags(L, Shown, Args, ATys, Ps, 1, C) ++
                             [{error, L, C#ctx.fname,
                               {instantiation_conflict, Shown, V, LI, Lo, UI, Up}}
                              || {V, {LI, Lo, UI, Up}} <- Conflicts] ++ D}
                    end
            end
    end.

%% Type arguments needing no expectation first, at the template's extent. Use
%% their partial solution for lambdas, bare names and containing forms.
poly_args({poly, Vars, PsT, _RetT, Erased}, Args, S, C) ->
    Indexed = lists:zip(lists:seq(1, length(Args)), lists:zip(Args, PsT)),
    Extent = maps:from_list([{V, bs_types:term()} || V <- Vars]),
    Fixed = maps:from_list([{I, expected(A, subst_tpl(PT, Extent), S, C)}
                            || {I, {A, PT}} <- Indexed, not hungry(A)]),
    Hungry = [{I, A, PT} || {I, {A, PT}} <- Indexed, hungry(A)],
    Typed = retype(Hungry, Fixed, #{}, none, {Vars, PsT, Erased}, S, C, 1),
    {Tys, Ds} = lists:unzip([maps:get(I, Typed) || I <- lists:seq(1, length(Args))]),
    {Tys, lists:append(Ds)}.

%% Partial solutions prefer lower bounds regardless of variance; unbounded
%% variables use `term`. Retype dependent arguments as expectations widen.
%% After three changing rounds, use the extent. Keep only final diagnostics.
retype(Hungry, Fixed, Prev, LastExpect, T = {Vars, PsT, Erased}, S, C, Round) ->
    Typed = maps:merge(Fixed, Prev),
    Bounds = bounds(PsT, [{I, Ty} || {I, {Ty, _}} <- maps:to_list(Typed)]),
    Partial = maps:from_list([{V, case lists:member(V, Erased) of
                                      true  -> bs_types:term();
                                      false -> known(bounds_of(V, Bounds))
                                  end} || V <- Vars]),
    Expect = [{I, A, subst_tpl(PT, Partial)} || {I, A, PT} <- Hungry],
    if
        Expect =:= LastExpect ->
            Typed;
        Round > 3 ->
            Extent = maps:from_list([{V, bs_types:term()} || V <- Vars]),
            maps:merge(Fixed, maps:from_list([{I, expected(A, subst_tpl(PT, Extent), S, C)}
                                              || {I, A, PT} <- Hungry]));
        true ->
            Next = maps:from_list([{I, expected(A, Ty, S, C)} || {I, A, Ty} <- Expect]),
            retype(Hungry, Fixed, Next, Expect, T, S, C, Round + 1)
    end.

%% Check privacy before arity so a private F/2 beside a public F/1 is not
%% reported as an arity error. Private names cannot enter the import table;
%% search imported modules for unresolved unqualified calls.
private_callee({q, M, N, A}, _Arity, C) ->
    case maps:is_key({q, M, N, A}, maps:get(privates, C#ctx.imports, #{})) of
        true  -> {yes, M};
        false -> no
    end;
private_callee({N, A}, _Arity, C) ->
    Privates = maps:get(privates, C#ctx.imports, #{}),
    case [M || M <- maps:get(imported, C#ctx.imports, []),
               maps:is_key({q, M, N, A}, Privates)] of
        [M | _] -> {yes, M};
        []      -> no
    end;
private_callee(_Key, _Arity, _C) -> no.

%% Report available arities when the name exists at another arity.
unresolved(L, Key, Shown, Args, D, C) ->
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
    end.

other_arities({N, _}, Callees) ->
    lists:sort([A || {Nm, A} <- maps:keys(Callees), Nm =:= N]);
other_arities({f, M, N, _}, Callees) ->
    lists:sort([A || {f, Mm, Nm, A} <- maps:keys(Callees), Mm =:= M, Nm =:= N]);
other_arities({q, M, N, _}, Callees) ->
    lists:sort([A || {q, Mm, Nm, A} <- maps:keys(Callees), Mm =:= M, Nm =:= N]).

arg_diags(_L, _Callee, [], [], [], _I, _C) -> [];
arg_diags(L, Callee, [A | As], [T | Ts], [P | Ps], I, C) ->
    arg_diag(L, Callee, A, T, P, I, C) ++ arg_diags(L, Callee, As, Ts, Ps, I + 1, C).

arg_diag(L, Callee, A, T, P, I, C) ->
    R = bs_types:subtract(T, P),
    case bs_types:is_none(R) of
        true  -> [];
        %% The residual proposes a clause in the caller, never the callee.
        false -> [{error, L, C#ctx.fname,
                   {arg_not_accepted, Callee, I, R, head_hint(A, C)}}]
    end.

%% Check the extent first, then the instantiated parameter: an arrow's extent
%% can be the top arrow and miss an instantiation mismatch. Report at most one
%% diagnostic per argument.
poly_arg_diags(L, Callee, Args, ATys, Ps, Inst, C) ->
    Rows = lists:zip3(lists:seq(1, length(Args)), Args, lists:zip3(ATys, Ps, Inst)),
    lists:append([case arg_diag(L, Callee, A, T, P, I, C) of
                      []   -> arg_diag(L, Callee, A, T, Q, I, C);
                      Diag -> Diag
                  end || {I, A, {T, P, Q}} <- Rows]).

%% Only whole-parameter arguments have a caller-head position to refine. Carry
%% record names in the hint so `caller_head` can render source patterns.
head_hint({e_var, _, V}, #ctx{binds = B, arity = N, types = Env}) ->
    case maps:get(V, B, undefined) of
        [I] when is_integer(I) -> {I, N, record_names(Env)};
        _                      -> none
    end;
head_hint(_, _) -> none.

foreign_name(Mod, Fun) ->
    list_to_atom(":" ++ atom_to_list(Mod) ++ "." ++ atom_to_list(Fun)).

%% Locals take precedence over imports; only competing imports are ambiguous.
unqualified_key(Name, Arity, L, C) ->
    Key = {Name, Arity},
    case maps:is_key(Key, C#ctx.callees) of
        true  -> Key;
        false ->
            case maps:get(Key, maps:get(funs, C#ctx.imports, #{}), []) of
                []    -> Key;          %% unknown: `call/6` reports it
                [M]   -> {q, M, Name, Arity};
                %% Qualify ambiguous candidates so the diagnostic offers a fix.
                Many  -> erlang:error({ambiguous_call, Name, Arity,
                                       lists:sort(Many), L})
            end
    end.

%% Qualified calls still require a `using` entry: those entries declare the
%% file's dependencies.
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

%% Field-set residuals use names; type subtraction only identifies the record.
field_delta(Supplied, Declared) ->
    {lists:sort(Declared -- Supplied), lists:sort(Supplied -- Declared)}.

%% Read resolved fields; the emitter's `record_fields/1` reads surface types.
%% `Kind` is generated, never assigned. Unfold recursive records before the
%% catch-all or their known fields become `unknown`. A `mu` body is a
%% partition, so unfolding terminates.
declared_fields(#{mu := _} = T) -> declared_fields(bs_types:unfold(T));
declared_fields(#{maps := [{closed, Fs}]}) -> maps:keys(Fs) -- ['Kind'];
declared_fields(_)                         -> unknown.

field_type(#{mu := _} = T, Field) -> field_type(bs_types:unfold(T), Field);
field_type(#{maps := top}, _Field) -> bs_types:term();
field_type(#{maps := Members}, Field) ->
    union_of([maps:get(Field, Fs) || {_, Fs} <- Members, maps:is_key(Field, Fs)]).

%% Construction and `with` check each value against its declared field type.
%% `reported()` is `none()`, so subtraction suppresses cascading errors.
%% Rationale: compiler/features/F21-field-value-obligations.md.
field_value_diags(Keys, Tys, RecTy, Name, L, C) ->
    [{error, L, C#ctx.fname, {field_value_not_accepted, Name, K, R}}
     || {K, VTy} <- lists:zip(Keys, Tys),
        R <- [bs_types:subtract(VTy, field_type(RecTy, K))],
        not bs_types:is_none(R)].

%% Every member of a `with` subject must carry every updated key. Check keys
%% separately so each residual identifies the members lacking that field. A key
%% absent from all named records is an undeclared-name error per member. Failed
%% synthesis skips value checks; a refused subject returns `reported()`.
with_subject(T, Keys, Tys, L, C) ->
    case bs_types:is_none(T) of
        true ->
            {T, []};
        false ->
            Verdicts = [{K, subject_verdict(T, K)} || K <- Keys],
            Absent   = [{K, Lacking} || {K, {absent, Lacking}} <- Verdicts],
            Invented = [K || {K, invented} <- Verdicts],
            case {Absent, Invented} of
                {[], []} ->
                    {T, member_value_diags(T, Keys, Tys, L, C)};
                _ ->
                    {reported(),
                     [{error, L, C#ctx.fname, {field_absent, update, K, Lacking}}
                      || {K, Lacking} <- Absent]
                     ++ invented_diags(T, Invented, L, C)}
            end
    end.

%% `invented` requires only named closed records, none carrying the key. Other
%% subjects lacking the key return the lacking residual as `absent`.
subject_verdict(T, K) ->
    Lacking = lacking(T, K),
    case bs_types:is_none(Lacking) of
        true ->
            carried;
        false ->
            case bs_types:is_none(bs_types:subtract(T, Lacking))
                 andalso all_named_records(T) of
                true  -> invented;
                false -> {absent, Lacking}
            end
    end.

%% Unrecognised shapes return false so missing keys are refused as `absent`.
all_named_records(#{mu := _} = T) ->
    all_named_records(bs_types:unfold(T));
all_named_records(#{maps := Members} = T) when is_list(Members), Members =/= [] ->
    bs_types:is_none(bs_types:subtract(T, bs_types:map_open(#{})))
        andalso lists:all(fun(M) -> record_name(M) =/= unknown end,
                          member_types(Members));
all_named_records(_) ->
    false.

%% With no invented keys, do not read members: the subject may be `term` or
%% `int`, with no member list.
invented_diags(_T, [], _L, _C) ->
    [];
invented_diags(T, Ks, L, C) ->
    [{error, L, C#ctx.fname,
      {field_set_mismatch, record_name(M), update, [], lists:sort(Ks)}}
     || M <- member_types(members_of(T))].

%% Shared by projection and update: the residual may lack `Field`.
lacking(Ty, Field) ->
    bs_types:subtract(Ty, bs_types:map_open(#{Field => bs_types:term()})).

%% Check values against every member's declaration: the runtime subject may be
%% any member. Reached only when every member carries every updated key. Open
%% maps narrowed by record patterns also use this path.
member_value_diags(T, Keys, Tys, L, C) ->
    lists:append(
      [field_value_diags(Keys, Tys, MTy, member_label(MTy), L, C)
       || MTy <- member_types(members_of(T))]).

%% No catch-all: `maps := top` cannot pass the key-presence check. Other shapes
%% require an explicit contract with `bs_types`.
members_of(#{mu := _} = T)                          -> members_of(bs_types:unfold(T));
members_of(#{maps := Members}) when is_list(Members) -> Members.

%% `Openness` is `closed | open`; the minted `Kind` field lives inside `Fs`.
member_types(Members) ->
    [(bs_types:none())#{maps => [{Openness, Fs}]} || {Openness, Fs} <- Members].

%% Untagged members use their printed shape so value errors remain reportable.
member_label(MTy) ->
    case record_name(MTy) of
        unknown -> lists:flatten(bs_types:to_pattern(MTy));
        Name    -> Name
    end.

%% Head hints use only names resolvable in this environment, keyed by tag.
%% Deriving a name from a tag could suggest a type outside the file's scope.
%% Missing names retain the discriminator; multi-tag aliases are excluded.
record_names(Env) ->
    %% Bare and qualified imports share a tag. Prefer the shortest visible name.
    lists:foldl(
      fun({Tag, Name}, Acc) ->
              case maps:find(Tag, Acc) of
                  {ok, Held} when length(Held) =< length(Name) -> Acc;
                  _ -> Acc#{Tag => Name}
              end
      end, #{},
      [{Tag, atom_to_list(Name)}
       || Name <- maps:keys(Env),
          Tag <- [minted_tag(Name, Env)],
          Tag =/= undefined]).

%% Parametric, cyclic or unknown entries may raise during resolution.
%% Unresolvable names cannot be offered as heads.
minted_tag(Name, Env) ->
    try resolve({t_ref, Name}, Env) of
        Ty ->
            case field_type(Ty, 'Kind') of
                #{atoms := {finite, [Tag]}, ints := [], floats := {finite, []},
                  tuples := [], lists := [], maps := [], bins := [],
                  opaques := [], funs := []} -> Tag;
                _ -> undefined
            end
    catch
        _:_ -> undefined
    end.

%% Minted tags end in the record's declared name after the last dot. `with`
%% needs this name for diagnostics because it has only the base type. Multiple
%% tags have no single record name.
record_name(Ty) ->
    case field_type(Ty, 'Kind') of
        #{atoms := {finite, [Tag]}} ->
            list_to_atom(lists:last(string:split(atom_to_list(Tag), ".", all)));
        _ ->
            unknown
    end.

%% Pair domain-map parameters with patterns by position: destructuring a record
%% in another position must not trigger this refusal.
%% Rationale: compiler/features/F33-map-type.md.
map_pattern_diags(Clauses, Params, Env, Name) ->
    Doms = [I || {I, {param, T, _}} <- lists:enumerate(Params),
                 bs_types:is_dom(resolve(T, Env))],
    [{error, CLine, Name, {map_pattern_deferred, head, resolve(ParamT, Env)}}
     || {clause, CLine, _, Patterns, _, _} <- Clauses,
        I <- Doms,
        length(Patterns) >= I,
        destructures_map(lists:nth(I, Patterns)),
        {param, ParamT, _} <- [lists:nth(I, Params)]].

%% Record patterns are deliberately excluded: their minted `Kind` makes
%% ordinary non-membership diagnostics valid against a domain map.
destructures_map({p_map, _, _})       -> true;
destructures_map({p_bind, _, _, Ptn}) -> destructures_map(Ptn);
destructures_map(_)                   -> false.

%% Switch arms need this refusal too; clause-head checks do not reach them, and
%% a vacuous-arm warning alone still permits compilation.
map_arm_deferred(P, Subject) ->
    bs_types:is_dom(Subject) andalso destructures_map(P).

walk([], Residual, _Declared, _Ctx, Diags, _N) ->
    {Residual, lists:reverse(Diags)};
walk([C = {clause, CLine, Name, _, _, _} | Rest], Residual, Declared, Ctx, Diags, N) ->
    Env = Ctx#ctx.types,
    %% Only `Certain` may be subtracted for coverage. Redundancy uses
    %% `Possible`. An untranslatable guard separates these lower and upper
    %% bounds.
    {Certain, Possible, Bindings, Base} = clause_type(C, Env),
    %% Redundancy uses the running residual. Keep `Declared` separately to
    %% distinguish out-of-domain patterns from shadowing and impossible guards.
    Diags1 =
        case redundancy(Base, Possible, Residual, Declared) of
            vacuous    -> [{warning, CLine, Name, {vacuous_clause, N, Declared}} | Diags];
            dead_guard -> [{warning, CLine, Name, {unsatisfiable_guard, N}} | Diags];
            shadowed   -> [{warning, CLine, Name, {unreachable_clause, N}} | Diags];
            live       -> Diags
        end,
    Diags2 = catch_all_diags(C, Residual, CLine, Name, record_names(Env)) ++ Diags1,
    %% Body checks use `Possible`: an unread guard makes `Certain` empty, which
    %% would make every containment check pass.
    Domain = bs_types:intersect(Residual, Possible),
    %% Type the guard before narrowing, or an int comparison over a float could
    %% erase the mixed pair that needs a diagnostic.
    GuardDomain = bs_types:intersect(Residual, Base),
    ClauseDiags = clause_diags(C, Domain, GuardDomain, Bindings, Ctx),
    %% A mixed-pair error suppresses the dead-guard warning produced by integer
    %% narrowing: widening that guard is not the required correction.
    Diags2b = case lists:any(fun mixed_pair/1, ClauseDiags) of
                  true  -> [D || D <- Diags2,
                                 D =/= {warning, CLine, Name, {unsatisfiable_guard, N}}];
                  false -> Diags2
              end,
    Diags3 = ClauseDiags ++ Diags2b,
    walk(Rest, bs_types:subtract(Residual, Certain), Declared, Ctx, Diags3, N + 1).

%% Diagnostic precedence is deliberate: out-of-domain pattern, impossible
%% guard, then shadowing. `Base` must precede guard narrowing to distinguish
%% the first two. Clause heads and switch arms share this classification.
%% Unread guards retain `Possible` and are not classified as impossible.
redundancy(Base, Possible, Residual, Declared) ->
    InDomain    = not bs_types:is_none(bs_types:intersect(Base, Declared)),
    GuardAdmits = not bs_types:is_none(bs_types:intersect(Possible, Declared)),
    Adds        = not bs_types:is_none(bs_types:intersect(Possible, Residual)),
    if
        not InDomain    -> vacuous;
        not GuardAdmits -> dead_guard;
        not Adds        -> shadowed;
        true            -> live
    end.

%% Only unguarded all-wildcard clauses are catch-alls; binders retain values
%% and guards constrain them even when untranslatable. A catch-all is refused
%% over a closed, inhabited residual.
catch_all_diags({clause, _, _, Patterns, none, _}, Residual, Line, Name, Names) ->
    case all_wild(Patterns) andalso closed_and_inhabited(Residual) of
        true  -> [{error, Line, Name, {catch_all_over_closed, Residual, Names}}];
        false -> []
    end;
catch_all_diags(_C, _Residual, _Line, _Name, _Names) ->
    [].

all_wild([])       -> false;      % a nullary function has nothing to catch
all_wild(Patterns) -> lists:all(fun({p_wild, _}) -> true; (_) -> false end, Patterns).

closed_and_inhabited(Residual) ->
    not bs_types:is_none(Residual) andalso not bs_types:is_open(Residual).

%%% --- What a clause matches ---

%% Bindings record paths so body checks read variable types from the domain,
%% not the pattern: a bare variable's pattern type is only `term`.
clause_type({clause, _, _, Patterns, Guard, _}, Env) ->
    {Components, Bindings, Exact} = pattern_row(Patterns, Env),
    Base = bs_types:tuple(Components),
    {Certain, Possible} = apply_guard(Base, Bindings, Guard),
    %% `redundancy/4` needs the unguarded `Base`, independent of exactness.
    case Exact of
        true  -> {Certain, Possible, Bindings, Base};
        %% Inexact patterns bound `Possible` but cannot credit `Certain`.
        false -> {bs_types:none(), Possible, Bindings, Base}
    end.

%% Boundary guards subtract declared refinements from per-parameter upper
%% bounds. Use `Possible`; `positions/2` must widen empty products to `term` so
%% an uninhabited type cannot suppress required boundary comparisons.
%% Rationale: compiler/features/F37-boundary-range.md.
clause_accepts({clause, _, _, Patterns, _, _} = Clause, Env) ->
    {_Certain, Possible, _Bindings, _Base} = clause_type(Clause, Env),
    positions(Possible, length(Patterns)).

%% Unioning each position across products loses correlation but only widens
%% acceptance, so it can add boundary comparisons, never remove them. No
%% product of the right arity must yield `term` at every position so the
%% emitter retains every required bound.
positions(Ty, N) ->
    Products = try
                   #{tuples := Ps} = bs_types:unfold(Ty),
                   [P || P <- Ps, is_list(P), length(P) =:= N]
               catch _:_ -> []
               end,
    case Products of
        []   -> lists:duplicate(N, bs_types:term());
        Ps2  -> [bs_types:union([lists:nth(I, P) || P <- Ps2])
                 || I <- lists:seq(1, N)]
    end.

pattern_row(Patterns, Env) ->
    Triples = [pattern_type(P, [I], Env)
               || {P, I} <- lists:zip(Patterns, lists:seq(1, length(Patterns)))],
    Tys   = [T || {T, _, _} <- Triples],
    Binds = [B || {_, B, _} <- Triples],
    Exact = lists:all(fun({_, _, E}) -> E end, Triples),
    {Tys, lists:foldl(fun maps:merge/2, #{}, Binds), Exact}.

%% Returns {Type, Bindings, Exact}. Bindings locate variables for refinement;
%% `Exact` distinguishes the matched set from an upper bound.
pattern_type({p_int, _, N}, _Path, _Env)  -> {bs_types:range(N, N), #{}, true};
%% A float literal matches one value under `=:=`, so it is exact.
pattern_type({p_float, _, F}, _Path, _Env) -> {bs_types:float_lit(F), #{}, true};
pattern_type({p_atom, _, A}, _Path, _Env) -> {bs_types:atom_lit(A), #{}, true};
pattern_type({p_wild, _}, _Path, _Env)    -> {bs_types:term(), #{}, true};
pattern_type({p_var, _, V}, Path, _Env)   -> {bs_types:term(), #{V => Path}, true};
%% A matched name has an unknown value, so it credits no `Certain` coverage.
%% Its `term` upper bound is intersected with the residual for body checking.
pattern_type({p_eqvar, _, _V}, _Path, _Env) -> {bs_types:term(), #{}, false};
%% Relational patterns represent exact integer intervals and credit coverage.
pattern_type({p_rel, Line, Op, K}, Path, _Env) ->
    argument_position(Line, Path),
    {rel_type(Op, K), #{}, true};
%% Both operands use the same path: they constrain one value twice.
pattern_type({p_and, _, A, B}, Path, Env) ->
    rel_combine(fun bs_types:intersect/2, A, B, Path, Env);
pattern_type({p_or, _, A, B}, Path, Env) ->
    rel_combine(fun bs_types:union/2, A, B, Path, Env);
pattern_type({p_tuple, _, Ps}, Path, Env) ->
    Indexed = lists:zip(Ps, lists:seq(1, length(Ps))),
    Triples = [child_type(P, Path ++ [I], Env) || {P, I} <- Indexed],
    {bs_types:tuple([T || {T, _, _} <- Triples]),
     lists:foldl(fun maps:merge/2, #{}, [B || {_, B, _} <- Triples]),
     lists:all(fun({_, _, E}) -> E end, Triples)};
%% Property patterns constrain only named fields. Exactness follows their
%% children. Real field paths let guards refine them; `no_path` would erase
%% coverage for guarded record patterns.
pattern_type({p_map, _, Fields}, Path, Env) ->
    Triples = [{K, child_type(P, Path ++ [{field, K}], Env)} || {K, P} <- Fields],
    {bs_types:map_open(maps:from_list([{K, T} || {K, {T, _, _}} <- Triples])),
     lists:foldl(fun maps:merge/2, #{}, [B || {_, {_, B, _}} <- Triples]),
     lists:all(fun({_, {_, _, E}}) -> E end, Triples)};
%% Named record patterns must match the same open map as an explicit `Kind`
%% pattern. `record_of/3` resolves through the shared tag-minting point.
%% Rationale: compiler/features/F22-record-pattern-and-binder.md.
pattern_type({p_rec, Line, Name, Fields} = P, Path, Env) ->
    case view_pattern(Line, Name, Fields) of
        {ok, Tuple} -> pattern_type(Tuple, Path, Env);
        none        -> record_pattern_type(P, Path, Env)
    end;
%% A type prefix is exact only when `part_test/1` decides membership. Raise
%% refusal here so both clause heads and switch arms reject it. The emitter
%% lowers only whole-argument prefixes to variables plus guards; `child_type/3`
%% must reject nested prefixes structurally, not by path.
%% Rationale: compiler/features/F53-numeric-union-dispatch.md.
pattern_type({p_type, Line, TypeExpr, V}, Path, Env) ->
    Ty = resolve(TypeExpr, Env),
    case bs_types:part_test(Ty) of
        {ok, _Bif} -> {Ty, #{V => Path}, true};
        {no, Why}  -> erlang:error({type_prefix_undecidable, Line,
                                    bs_types:to_string(Ty), Why})
    end;
%% A trailing binder shares the wrapped pattern's path and exactness, so guards
%% and bodies read the same position.
pattern_type({p_bind, _, V, P}, Path, Env) ->
    {T, B, E} = pattern_type(P, Path, Env),
    {T, B#{V => Path}, E};
%% Binary patterns have no structure in the type algebra. Their `binary` upper
%% bound credits no coverage: truncated binaries may not match. A catch-all
%% remains required and legal over the open binary residual.
pattern_type({p_bin, _, Segs}, Path, _Env) ->
    {bs_types:binary_top(), seg_bindings(Segs, Path), false};
%% String literals are lexer-validated UTF-8 but have no binary singleton type.
%% Literal-only matches need a catch-all over the open residual.
pattern_type({p_str, _, _Bytes}, _Path, _Env) -> {bs_types:string(), #{}, false};
pattern_type({p_nil, _}, _Path, _Env) -> {bs_types:nil(), #{}, true};
%% List patterns preserve each prefix position and the open or closed tail.
%% Exactness follows the children; widening the prefix to any non-empty list
%% would falsely prove short lists covered.
pattern_type({p_list, _, Items, Rest}, Path, Env) ->
    %% Every element uses opaque `{elem}`: guards credit no refinement through
    %% list positions, preventing constraints from leaking between them.
    Triples = [child_type(P, Path ++ [{elem}], Env) || P <- Items],
    Prefix = [T || {T, _, _} <- Triples],
    Openness = case Rest of nil -> closed; _ -> open end,
    Binds0 = lists:foldl(fun maps:merge/2, #{}, [B || {_, B, _} <- Triples]),
    Binds = case Rest of
                nil -> Binds0;
                R   -> maps:merge(Binds0, binding(R, Path ++ [{tail}]))
            end,
    Exact = lists:all(fun({_, _, E}) -> E end, Triples),
    {bs_types:spine(Prefix, Openness), Binds, Exact}.

%% A named record pattern must match the same open map as an explicit `Kind`
%% pattern. `record_of/3` resolves through the shared tag-minting point.
record_pattern_type({p_rec, Line, Name, Fields}, Path, Env) ->
    {Tag, Declared} = record_of(Name, Line, Env),
    %% Reject undeclared fields before typing them so typos report directly,
    %% rather than collapsing the pattern and reporting non-exhaustiveness.
    [case lists:member(K, Declared) of
         true  -> ok;
         false -> erlang:error({pattern_field_unknown, Line, Name, K, Declared})
     end || {K, _} <- Fields],
    Triples = [{K, child_type(P, Path ++ [{field, K}], Env)} || {K, P} <- Fields],
    Named = maps:from_list([{K, T} || {K, {T, _, _}} <- Triples]),
    {bs_types:map_open(Named#{'Kind' => bs_types:atom_lit(Tag)}),
     lists:foldl(fun maps:merge/2, #{}, [B || {_, {_, B, _}} <- Triples]),
     lists:all(fun({_, {_, _, E}}) -> E end, Triples)}.

record_projection(L, Recv, Field, C) ->
    Lacking = lacking(Recv, Field),
    case bs_types:is_none(Lacking) of
        true  -> {field_type(Recv, Field), []};
        false -> {reported(),
                  [{error, L, C#ctx.fname,
                    {field_absent, projection, Field, Lacking}}]}
    end.

%% F60: `d.Reason` on a view reads a tuple position. The receiver must be
%% tuples only, each of them the same view, or it is not a view projection.
view_projection(Recv0, Field) ->
    Recv = case bs_types:is_rec(Recv0) of
               true  -> bs_types:unfold(Recv0);
               false -> Recv0
           end,
    case maps:get(tuples, Recv, []) of
        Products when is_list(Products), Products =/= [] ->
            TuplesOnly = (bs_types:none())#{tuples => Products},
            Views = [bs_types:view_of_tuple(P) || P <- Products],
            case {bs_types:is_subtype(Recv, TuplesOnly),
                  lists:usort([N || {ok, N, _} <- Views]),
                  lists:all(fun({ok, _, _}) -> true; (_) -> false end, Views)} of
                {true, [Name], true} ->
                    {_, Declared} = maps:get(Name, bs_types:views()),
                    case index_of(Field, Declared, 1) of
                        none -> none;
                        I    -> {ok, I + 1,
                                 bs_types:union([lists:nth(I + 1, P) || P <- Products])}
                    end;
                _ -> none
            end;
        _ -> none
    end.

index_of(_X, [], _I)      -> none;
index_of(X, [X | _], I)   -> I;
index_of(X, [_ | T], I)   -> index_of(X, T, I + 1).

%%% --- Binary segment bindings ---

%% Segment paths carry the width-derived type: binaries have no addressable
%% components in the algebra. BEAM defaults to unsigned, big-endian segments,
%% so a width of N binds an integer in 0..2^N - 1.
%% Rationale: compiler/features/F13-binary-patterns.md.
%%
%% F56: an unsized tail after string literals only is read from the subject at
%% `Path`, because a literal is whole UTF-8 characters and the rest of a valid
%% string is then valid too. Any other segment before it can split a character.
seg_bindings(Segs, Path) -> seg_bindings(Segs, Path, true, #{}).

seg_bindings([], _Path, _Literals, Acc) ->
    Acc;
seg_bindings([{seg_bind, _, V, rest} | Segs], Path, true, Acc) ->
    seg_bindings(Segs, Path, false, Acc#{V => Path ++ [{str_tail}]});
seg_bindings([{seg_bind, _, V, Size} | Segs], Path, _Literals, Acc) ->
    seg_bindings(Segs, Path, false, Acc#{V => [{seg, seg_type(Size)}]});
seg_bindings([{seg_str, _, _} | Segs], Path, Literals, Acc) ->
    seg_bindings(Segs, Path, Literals, Acc);
seg_bindings([_ | Segs], Path, _Literals, Acc) ->
    seg_bindings(Segs, Path, false, Acc).

seg_type({width, N}) when is_integer(N), N > 0 -> bs_types:range(0, (1 bsl N) - 1);
%% Invalid widths return `int` so `segment_width_not_positive` can report
%% instead of an internal `function_clause`.
seg_type({width, _})    -> bs_types:int();
%% Dependent-sized segments and remainders erase length to `binary`.
seg_type({sized_by, _}) -> bs_types:binary_top();
seg_type(rest)          -> bs_types:binary_top().

rel_combine(Op, A, B, Path, Env) ->
    {TA, BA, EA} = pattern_type(A, Path, Env),
    {TB, BB, EB} = pattern_type(B, Path, Env),
    {Op(TA, TB), maps:merge(BA, BB), EA andalso EB}.

%% Intervals must agree with `int_cmp/3`: relational patterns and guards have
%% the same meaning. Pattern `==` instead matches a bound value.
rel_type('>=', K) -> bs_types:range(K, pos_inf);
rel_type('>',  K) -> bs_types:range(K + 1, pos_inf);
rel_type('<=', K) -> bs_types:range(neg_inf, K);
rel_type('<',  K) -> bs_types:range(neg_inf, K - 1).

%% Relational patterns allow only a whole head parameter or switch subject.
%% Head paths are `[I]`; switch subject paths are `[]`.
%% Rationale: compiler/features/F2-interval-refinements.md.
argument_position(_Line, [])                     -> ok;
argument_position(_Line, [I]) when is_integer(I) -> ok;
argument_position(Line, _Path) ->
    erlang:error({relational_pattern_nested, Line}).

%% Composite children must pass here to reject nested type prefixes before
%% emission, for both heads and arms. Paths alone cannot distinguish a head
%% parameter from a tuple element of a switch subject: both can be `[I]`.
child_type({p_type, Line, _TypeExpr, _V}, _Path, _Env) ->
    erlang:error({type_prefix_nested, Line});
child_type(P, Path, Env) ->
    pattern_type(P, Path, Env).

%% List paths let bodies read component types, but guards cannot refine them:
%% the list algebra supports component reads, not component refinement.
binding({p_var, _, V}, Path) -> #{V => Path};
binding(_, _)                -> #{}.

%% `at_path/2` can read these steps; guards cannot refine them. Binary segments
%% have no addressable structure in the type algebra.
opaque_step({elem})    -> true;
opaque_step({tail})    -> true;
opaque_step({seg, _})  -> true;
opaque_step({str_tail}) -> true;
opaque_step(_)         -> false.

%%% --- Guards as type operations ---

apply_guard(Ty, _Bindings, none) ->
    {Ty, Ty};
apply_guard(Ty, Bindings, {guard, Expr}) ->
    %% Alternatives union; each conjunction intersects per-variable constraints.
    case alternatives(Expr) of
        unknown ->
            %% An unread guard may always fail, so it credits no coverage.
            {bs_types:none(), Ty};
        Alts ->
            Results = [refine_all(Ty, Bindings, A) || A <- Alts],
            case lists:member(none_marker, Results) of
                true  -> {bs_types:none(), Ty};
                false -> Refined = bs_types:union(Results), {Refined, Refined}
            end
    end.

%% An empty constraint list means unconstrained; `unknown` is untranslatable.
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
                  %% Unbound or unaddressable variables prevent coverage
                  %% credit. Returning `Acc` would incorrectly credit an unread
                  %% guard.
                  undefined -> none_marker;
                  no_path   -> none_marker;
                  Path      ->
                      case lists:any(fun opaque_step/1, Path) of
                          true  -> none_marker;
                          false -> refine_at(Acc, Path, C)
                      end
              end;
         (unknown, Acc) -> Acc
      end, Ty, Constraints).

%% An empty path refines a switch subject; head paths start with an index.
refine_at(Ty, [], C) ->
    apply_constraint(Ty, C);
%% Patterns supply a map member list here. Unexpected `top` must under-credit
%% coverage rather than silently over-credit it.
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
