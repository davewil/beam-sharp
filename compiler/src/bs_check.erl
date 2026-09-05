%%% The checker: the declaration pass, name scope, exhaustiveness and the
%%% body check, over the parsed declarations of one module.
%%%
%%% Exhaustiveness is a subtraction (ticket 04):
%%%
%%%   residual := the declared input type
%%%   for each clause: residual := residual \ (what that clause matches)
%%%   exhaustive iff residual is empty
%%%
%%% A signature is mandatory because the residual starts from the declared
%%% input type; without one there is nothing to subtract from (ticket 04).
%%% A guard the checker can translate into a type operation narrows what its
%%% clause subtracts; one it cannot translate credits nothing, so the clause
%%% subtracts only what its pattern alone matches (tickets 08, 20).
%%%
%%% In file order: the directory-shaped module and its declaration refusals;
%%% imports and the callee tables; surface types resolved into `bs_types`'
%%% algebra, with the prelude and the reserved qualifiers; the corrected
%%% signature; scope; the body check at the five sites where a type is
%%% declared; patterns as types; guards as type operations. `bs_emit` reads
%%% the resolver and the tables from here rather than keeping copies.

-module(bs_check).

-export([check/1, check/2]).
%% `check_dir/3` is the one implementation of the declaration pass; `check/2`
%% is its single-source case (F15).
-export([check_dir/2, check_dir/3]).
%% What a checked module offers and withholds from its dependents. `bsc`
%% builds a dependent's import environment from these, out of modules it has
%% already checked in the same invocation (ticket 41 §3).
-export([exports_of/1, private_of/1]).
%% The emitter resolves surface types and mints record tags through these,
%% so the qualified-name rule has one site (ticket 26 §1).
-export([resolve/2, qualified/2, record_fields/1]).
%% The emitter asks which qualifiers are reserved, to emit a local form
%% rather than a remote call, and which operations exist under them, to
%% generate exactly the functions the checker admitted (ticket 67).
-export([reserved_qualifiers/0, reserved_table/0]).

%% `vis` stays last: `bs_emit` reads this record positionally through
%% `element/2`, so every earlier field keeps its index. The default is
%% `private`, matching the language's (ticket 40 §3).
-record(fn, {name, line, ret, params, clauses = [], vis = private}).

%% One clause's checking context. `types` is the only field `resolve/2`
%% reads, because the emitter calls `resolve/2` with that map directly.
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
%% `bsc` threads it from modules checked in this invocation; nothing is read
%% from disk, so nothing can go stale (ticket 41 §3).
check(Decls, World) ->
    case check_dir([{undefined, Decls}], World, undefined) of
        {ok, Module, Tagged} -> {ok, Module, [D || {_, D} <- Tagged]};
        {error, Tagged}      -> {error, [D || {_, D} <- Tagged]}
    end.

%%% ---------------------------------------------------------------------------
%%% Checking an aggregate: several files, one module (F15)
%%%
%%% The directory is the unit of compilation (ticket 13 §3). The declaration
%%% pass runs over the whole directory as one scope, and the function pass
%%% runs per file, so every diagnostic arrives beside the path it belongs to.
%%% A lookup by function name could not do that: a diagnostic carries a name
%%% and no arity, a name may carry two arities (ticket 40 §2), and one
%%% function per file puts them in two files.
%%%
%%% `Expect` is the module atom the directory path implies, or `undefined`
%%% for callers with no path (`check/2`, the REPL, `compile_string/2`). The
%%% path arithmetic lives in `bsc`, where `--src-root` is parsed; only the
%%% comparison and the refusal live here (ticket 41 §5).
%%% ---------------------------------------------------------------------------

check_dir(Sources, World) -> check_dir(Sources, World, undefined).

check_dir(Sources, World, Expect) ->
    Decls = lists:append([D || {_, D} <- Sources]),
    one_module_per_directory(Sources, Expect),
    [no_function_in_index(P, D) || {P, D} <- Sources],
    compiler_known_redeclared(Decls),
    Env = type_env(Decls),
    %% A declared type whose failure channel collapses is refused here, by
    %% the same env every other declaration refusal uses, before any later
    %% diagnostic can describe the collapsed type (F31, ticket 15 §1).
    collapse_refused(Decls, Env),
    Module = module_name(Decls),
    %% The reserved-name refusal runs before the path check, so `module List`
    %% gets the same answer in any directory rather than a path-mismatch
    %% refusal that looks like a reserved-name one (ticket 67 clause 2).
    reserved_module_name(Module, Sources),
    module_matches_path(Module, Sources, Expect),
    name_redeclared(Decls),
    private_callback(Decls),
    PerFile = [{P, collect(D)} || {P, D} <- Sources],
    Fns = lists:append([F || {_, F} <- PerFile]),
    Imports = import_env(Decls, Module, World),
    %% A foreign declaration belongs to the directory's declaration pass, the
    %% stage `admissible_foreign_ret/5` refuses at (F19).
    Foreigns = foreign_wrappers(Decls, Env),
    Ctx = #ctx{types = Env, callees = callees(Decls, Env, Imports),
               imports = Imports},
    Tagged = lists:append([check_file(P, Fs, Ctx) || {P, Fs} <- PerFile]),
    case [D || {_, D} <- Tagged, element(1, D) =:= error] of
        []     -> {ok, #{module => Module, functions => Fns, env => Env,
                         %% Per-file functions, so the emitter can put a
                         %% file attribute in front of each file's (F15).
                         files => PerFile,
                         behaviours => behaviours(Decls),
                         %% Imports resolve at check time; the emitter reads
                         %% this table rather than resolving again (41 §2).
                         imports => resolved_funs(Imports, local_keys(Decls)),
                         %% A short name resolves to its full module here,
                         %% and the emitter writes that full atom into the
                         %% remote call, never the short spelling.
                         qmods => resolved_mods(Imports),
                         %% Whether a remote `HandleCall/3` lowers to
                         %% `handle_call/3` depends on the callee's declared
                         %% behaviours, so the emitter is told per
                         %% callee (F10).
                         remote_names => remote_names(World),
                         %% Which foreign calls owe a `try`, keyed by the
                         %% triple `e_foreign_call` carries: decided here,
                         %% looked up by the emitter (F19, ticket 15 §4).
                         foreigns => Foreigns}, Tagged};
        _Fatal -> {error, Tagged}
    end.

%% One file's functions, with anything raised out of them tagged with that
%% file, so a raised condition is reported against the file it came from and
%% not the module's first file. Not wrapped when there is no path:
%% `check/2`'s callers get the bare tuple.
check_file(undefined, Fns, Ctx) ->
    [{undefined, D} || F <- Fns, {_, Ds} <- [check_fn(F, Ctx)], D <- Ds];
check_file(Path, Fns, Ctx) ->
    try [{Path, D} || F <- Fns, {_, Ds} <- [check_fn(F, Ctx)], D <- Ds]
    catch
        error:Reason when is_tuple(Reason), element(1, Reason) =/= in_file ->
            erlang:error({in_file, Path, Reason})
    end.

%%% ---------------------------------------------------------------------------
%%% The refusals a directory-shaped module adds (F15)
%%% ---------------------------------------------------------------------------

%% One directory is one module: two files declaring different modules is an
%% error. A file with no `module` line inherits the directory's, which is
%% the common case under one function per file (ticket 41 §4).
one_module_per_directory(_Sources, undefined) -> ok;
one_module_per_directory(Sources, _Expect) ->
    Declared = [{P, N, L} || {P, D} <- Sources, {module, L, N} <- D],
    case lists:usort([N || {_, N, _} <- Declared]) of
        []  -> erlang:error({no_module_declaration,
                             [P || {P, _} <- Sources, is_list(P)]});
        [_] -> ok;
        _   -> erlang:error({module_disagreement, lists:sort(Declared)})
    end.

%% `index.bs` holds everything except functions, as an error rather than a
%% convention; a `foreign` declaration is a function signature and is caught
%% too (ticket 41 §4).
no_function_in_index(Path, Decls) when is_list(Path) ->
    case filename:basename(Path) of
        "index.bs" ->
            case [{N, L} || {signature, L, N, _, _, _} <- Decls] of
                %% Wrapped with the path because this raise site knows its
                %% file; `resolve_error/2` unwraps and re-dispatches.
                [{N, L} | _] ->
                    erlang:error({in_file, Path, {function_in_index, N, L}});
                []           -> ok
            end;
        _ -> ok
    end;
no_function_in_index(_Path, _Decls) -> ok.

%% A file's `module` declaration must match its directory path (ticket 41
%% §5). `Expect` arrives computed, since the path arithmetic is a CLI concern.
module_matches_path(_Module, _Sources, undefined) -> ok;
module_matches_path(Module, _Sources, Module) -> ok;
module_matches_path(Module, Sources, Expect) ->
    Line = case [L || {_, D} <- Sources, {module, L, N} <- D, N =:= Module] of
               [L | _] -> L;
               []      -> 1
           end,
    erlang:error({module_path_mismatch, Module, Expect, Line}).

%% A reserved qualifier is not a module name, for the reason a compiler-known
%% type may not be redeclared: the name would mean two things (ticket 67
%% clause 2). Only the whole name is compared, so `Shop.Collections.List`
%% stays legal; the path segment is not burned (67 Q6).
reserved_module_name(Module, Sources) ->
    case lists:member(Module, reserved_qualifiers()) of
        false -> ok;
        true  ->
            Line = case [L || {_, D} <- Sources, {module, L, N} <- D,
                              N =:= Module] of
                       [L | _] -> L;
                       []      -> 1
                   end,
            erlang:error({reserved_module_name, Module, Line})
    end.

%% The behaviours this module implements, each checked for completeness: a
%% missing callback is an error at the declaration, not an attribute quietly
%% dropped or an undefined-callback report from `erlc` against the emitted
%% file (ticket 35 §3). Presence only: Dialyzer already checks callback
%% types at the boundary against OTP's own `-callback` declarations.
behaviours(Decls) ->
    Defined = [{N, length(Ps)} || {signature, _, N, _, Ps, _} <- Decls],
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
%%% The module system (F11)
%%% ---------------------------------------------------------------------------

%% A name may carry more than one arity (ticket 40 §2), so the duplicate is
%% {Name, Arity}, never Name. It fires before the exhaustiveness walk, which
%% would otherwise merge two same-arity signatures into one function and
%% report the later clauses as unreachable.
name_redeclared(Decls) ->
    Sigs = [{{N, length(Ps)}, L} || {signature, L, N, _, Ps, _} <- Decls],
    Grouped = lists:foldl(fun({K, L}, Acc) ->
                                  maps:update_with(K, fun(Ls) -> [L | Ls] end, [L], Acc)
                          end, #{}, Sigs),
    case [{N, A, lists:min(Ls)} || {{N, A}, Ls} <- maps:to_list(Grouped), length(Ls) > 1] of
        []                  -> ok;
        [{N, A, L} | _]     -> erlang:error({name_redeclared, N, A, L})
    end.

%%% ---------------------------------------------------------------------------
%%% Visibility: `public` and `private` (F12)
%%% ---------------------------------------------------------------------------

%% An unmarked signature is private (ticket 40 §3). The parser yields `none`
%% for it, and every reader here tests `=:= public` rather than `=/=
%% private`, so `none` can never be mis-sorted as exported. `private` stays
%% legal and says what the absence already says.

%% A private callback is an error: `-behaviour` has no runtime effect and
%% only exports matter, so `gen_server` calling a private `HandleCall/3`
%% would fail at run time (tickets 06, 40 §3). Contract-scoped as F10's
%% table is: a row fires only for a name and arity that is a callback of a
%% behaviour this module declares.
private_callback(Decls) ->
    Behaviours = [B || {behaviour, _, B} <- Decls],
    Private = [{N, length(Ps), L} || {signature, L, N, _, Ps, V} <- Decls, V =/= public],
    case [{N, A, L, Otp} || {N, A, L} <- Private,
                            Otp <- [bs_otp:callback_name(N, A, Behaviours)],
                            Otp =/= none] of
        []                    -> ok;
        [{N, A, L, Otp} | _]  -> erlang:error({private_callback, N, A, Otp, L})
    end.

%% What a checked module offers its dependents: every public function it
%% declares, keyed by name and arity. `private_of/1` carries the rest, so a
%% qualified call to a private function is refused as private rather than
%% reported as unknown (F12).
exports_of(Decls) ->
    Env = type_env(Decls),
    %% `bsc --api` runs the declaration pass on its own and must surface the
    %% refusals a compile does, a collapsed failure channel included, or it
    %% would print `atom Go(int)` for a function declared over
    %% `option<atom>` (F31). For `bsc:build/4` this cannot fire: the module
    %% was already checked clean.
    collapse_refused(Decls, Env),
    maps:from_list([{{N, length(Ps)}, sig(Ps, R, Env)}
                    || {signature, _, N, R, Ps, V} <- Decls, V =:= public]).

%% The names a dependent may not call, carried so the refusal can say why.
%% No signature: nothing outside the module may use one.
private_of(Decls) ->
    maps:from_keys([{N, length(Ps)} || {signature, _, N, _, Ps, V} <- Decls,
                                       V =/= public],
                   true).

%% The import tables, from this module's `using` lines and the modules
%% already checked in this invocation (ticket 41 §5):
%%
%%   funs : {Name, Arity} -> Module      module tier   — `using Shop.Orders`
%%   mods : Short         -> Module      namespace tier — `using Shop`
%%   qual : {q, Mod, Name, Arity} -> Sig  every reachable qualified callee
%%
%% Which table an import populates is decided by what the path resolves to,
%% not by its spelling, so one grammar rule covers both tiers.
import_env(Decls, Self, World) ->
    Imports = [{L, M} || {import, L, M} <- Decls],
    Known = maps:keys(World),
    lists:foldl(fun({L, M}, Acc) -> add_import(L, M, Self, World, Known, Acc) end,
                #{funs => #{}, mods => #{}, qual => qual_table(World),
                  privates => private_table(World), imported => []},
                Imports).

add_import(L, M, Self, World, Known, Acc) ->
    case maps:is_key(M, World) of
        true  -> add_module_import(M, World, Acc);
        false ->
            %% A path that is not a module but is a prefix of modules is a
            %% namespace: compile-time name resolution only, nothing
            %% emitted (ticket 41 §5). Self is excluded because a module
            %% inside the namespace it imports is not its own dependency.
            case children(M, Known) -- [Self] of
                []       -> erlang:error({unknown_module, M, L});
                Children -> add_namespace_import(M, Children, Acc)
            end
    end.

%% An import that brings in a name the module also declares is accepted: the
%% local wins at the call site (`unqualified_key/4`), so the bare name never
%% has two meanings (ticket 47 Q2). Refusing it at the `using` line left a
%% top-level module unable to reach one of its own exported names by any
%% route (ENG-270).
add_module_import(M, World, Acc) ->
    Exports = maps:get(exports, maps:get(M, World)),
    Funs0 = maps:get(funs, Acc),
    Funs = maps:fold(fun(K, _Sig, F) ->
                             %% A collision is recorded, not raised: it is an
                             %% error at the call site, so an unused one is
                             %% no error at all (ticket 41 §2).
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

%% Every module reachable by a qualified call, keyed so `call/6` can look one
%% up without a second code path.
qual_table(World) ->
    maps:fold(fun(M, #{exports := Ex}, Acc) ->
                      maps:fold(fun({N, A}, Sig, In) ->
                                        In#{{q, M, N, A} => Sig}
                                end, Acc, Ex)
              end, #{}, World).

%% The same keyspace for the names a dependent may not call, kept apart from
%% `qual_table/1` so that everything in that table is callable and nothing
%% in this one is (F12).
private_table(World) ->
    maps:fold(fun(M, Entry, Acc) ->
                      maps:fold(fun({N, A}, _, In) -> In#{{q, M, N, A} => true} end,
                                Acc, maps:get(private, Entry, #{}))
              end, #{}, World).

%% Only names with exactly one source reach the emitter; an ambiguous one is
%% an error at its call site. A name the module declares itself is dropped,
%% because `unqualified_key/4` answers a bare call with the local (ticket 41
%% §2); if this table still carried the import, the emitter would write a
%% remote call for a name the checker typed against the local.
resolved_funs(Imports, Local) ->
    maps:fold(fun(K, [M], Acc) ->
                      case lists:member(K, Local) of
                          true  -> Acc;
                          false -> Acc#{K => M}
                      end;
                 (_, _, Acc) -> Acc
              end, #{}, maps:get(funs, Imports, #{})).

%% The `{Name, Arity}` keys this module declares; a bare name resolves to
%% these before any import (ticket 41 §2).
local_keys(Decls) ->
    [{N, length(Ps)} || {signature, _, N, _, Ps, _} <- Decls].

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
    %% A foreign declaration is a signature that will never have clauses, so
    %% it is not collected here or it would report `no_clauses`.
    Sigs = [#fn{name = N, line = L, ret = R, params = P, vis = V}
            || {signature, L, N, R, P, V} <- Decls],
    %% Clauses are matched by name and arity (ticket 40 §2); keyed by name
    %% alone, `Length/1` would collect `Length/2`'s clauses too.
    [F#fn{clauses = [C || C = {clause, _, Name, Ps, _, _} <- Decls,
                          Name =:= F#fn.name,
                          length(Ps) =:= length(F#fn.params)]}
     || F <- Sigs].

%% The callee environment (ticket 33 §6). Foreign declarations are included
%% although `collect/1` excludes them: a foreign signature declares its
%% callee like any other (ticket 32). Local names key on `{Name, Arity}` and
%% foreign ones on `{f, Module, Function, Arity}`, the pair `e_foreign_call`
%% carries. The arity is in the key because overloading is
%% permitted (ticket 40 §2) and a name-only map would keep whichever arity
%% was written last.
callees(Decls, Env, Imports) ->
    Local = [{{N, length(Ps)}, sig(Ps, R, Env)} || {signature, _, N, R, Ps, _} <- Decls],
    Foreign = [begin
                   admissible_foreign_ret(L, Mod, N, R, Env),
                   {{f, Mod, N, length(Ps)}, sig(Ps, R, Env)}
               end
               || {foreign, _, Mod, Sigs} <- Decls,
                  {foreign_sig, L, N, R, Ps} <- Sigs],
    maps:merge(maps:get(qual, Imports, #{}),
               maps:from_list(Local ++ Foreign)).

%% A foreign return type must be decidable by one BEAM guard in O(1), so
%% `string`, which needs an O(n) UTF-8 check, is refused in return
%% position (ticket 18 §2, ticket 20 §5, F9). Parameters are not checked: a
%% value handed out to Erlang is already known to be a string. `binary` is
%% admissible because `byte_size/1` and `bit_size/1` are O(1) guard
%% BIFs (ticket 20 §3).
admissible_foreign_ret(Line, Mod, Fun, Ret, Env) ->
    case opaque_refinement(resolve(Ret, Env)) of
        true  -> erlang:error({opaque_ret_at_boundary, Line, Mod, Fun});
        false -> ok
    end.

%% A proper non-empty subset of the binary part is a refinement of it, and
%% `string` is the only one today. Recursive, because anything deeper is a
%% compile error at the declaration too (ticket 18 §2): `list<string>` hides
%% the same unbounded check one bracket down.
opaque_refinement(#{bins := Bs}) when Bs =/= [], Bs =/= [other, utf8] -> true;
opaque_refinement(#{tuples := top}) -> false;
opaque_refinement(Ty = #{tuples := Ps, maps := Ms}) ->
    lists:any(fun opaque_refinement/1, lists:append(Ps))
        %% The list part is a union of spines, so ask for the element type;
        %% `has_lists/1` guards the recursion, since `list_elem/1` of a type
        %% with no list is `none()`, whose element is `none()` again (F20).
        orelse (bs_types:has_lists(Ty)
                andalso opaque_refinement(bs_types:list_elem(Ty)))
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
%%% The foreign `try` wrapper, decided at the declaration (F19, ticket 15 §4)
%%%
%%% Declaring a foreign function's return type with `foreign_error` as an
%%% error payload makes the compiler emit the wrapper; there is no `try` in
%%% the surface. The trigger is the resolved type, not the spelling: a user
%%% alias naming that union behaves identically to
%%% `result<T, foreign_error>` (ticket 09 §4). Every position in a foreign
%%% signature is a single type and never an inline `a | b`, so the union is
%%% reached through a `type` alias.
%%% ---------------------------------------------------------------------------

foreign_wrappers(Decls, Env) ->
    maps:from_list(
      [{{Mod, N, length(Ps)}, wrapped}
       || {foreign, _, Mod, Sigs} <- Decls,
          {foreign_sig, _L, N, R, Ps} <- Sigs,
          wraps(resolve(R, Env), Env)]).

%% The trigger is the payload `foreign_error`, not the tag `:error` (ticket
%% 56). Most of OTP returns `{error, Reason}` as an ordinary value and never
%% throws, and the compiler cannot know which foreign functions throw, so
%% the author declares the channel by naming the type the wrapper produces.
%% `(:error, atom)` and `(:error, foreign_error)` stay separate products, so
%% a function that returns an error value and can throw declares both.
%%
%% Equality, not containment: `result<int, term>` gets no wrapper although
%% `foreign_error` is a subtype of `term`. A mis-declared channel is
%% therefore not refused; catching one is the boundary guard's job (ticket
%% 18, LANGUAGE.md §11).
wraps(Ret, Env) ->
    Fe = maps:get(foreign_error, Env),
    lists:any(fun(P) -> same_type(P, Fe) end, error_members(Ret)).

%% `term` contains every tuple, so its tuple part is `top` and no member can
%% be named: a foreign function declared `term` promises nothing and gets no
%% wrapper (ticket 11).
error_members(#{tuples := top}) -> [];
error_members(#{tuples := Products}) ->
    Err = bs_types:atom_lit(error),
    [Payload || [Tag, Payload] <- Products, same_type(Tag, Err)].

%% The algebra publishes containment, and mutual containment is equality in
%% it.
same_type(A, B) -> bs_types:is_subtype(A, B) andalso bs_types:is_subtype(B, A).

%%% ---------------------------------------------------------------------------
%%% The failure channel must survive normalisation, checked at the
%%% declaration (F31, ticket 15 §1)
%%%
%%% A declared type is refused when a member the prelude calls a failure,
%%% `:nothing` or `(:error, E)`, is absorbed by what it sits beside, so the
%%% diagnostic lands where the fix is (ticket 09 §4). `ValidateAs<T>` asks
%%% the same question at its instantiation (F18).
%%%
%%% It is a pass over `Decls` rather than a clause in `resolve/3` because no
%%% type expression node carries a line; lines live on the declaration.
%%% Only the two failure members are checked: `binary | string` also has an
%%% absorbed member, but the sentence this raises would be false about it.
%%% ---------------------------------------------------------------------------

collapse_refused(Decls, Env) ->
    lists:foreach(fun(D) -> collapse_decl(D, Env) end, Decls).

%% The five declaration forms that carry a type an author wrote. A
%% parametric alias is skipped: its body has free variables, and nothing can
%% be normalised until it is instantiated.
collapse_decl({signature, L, _N, Ret, Params, _}, Env) ->
    collapse_ty(Ret, Env, L),
    lists:foreach(fun({param, T, _}) -> collapse_ty(T, Env, L) end, Params);
collapse_decl({foreign, _, _Mod, Sigs}, Env) ->
    lists:foreach(
      fun({foreign_sig, L, _N, Ret, Ps}) ->
              collapse_ty(Ret, Env, L),
              lists:foreach(fun({param, T, _}) -> collapse_ty(T, Env, L) end, Ps)
      end, Sigs);
collapse_decl({type_alias, L, _N, [], Body}, Env)  -> collapse_ty(Body, Env, L);
collapse_decl({type_refined, L, _N, Base, _}, Env) -> collapse_ty(Base, Env, L);
collapse_decl({record_decl, L, _N, Fields}, Env) ->
    lists:foreach(fun({field, _, T}) -> collapse_ty(T, Env, L) end, Fields);
collapse_decl(_, _Env) -> ok.

%% A type this pass cannot resolve is not its error to report: `callees/3`
%% and `check_fn/2` resolve the same expressions next and raise
%% `unknown_type` and its neighbours with their own wording. Only the
%% collapse is re-raised, with its stack intact.
collapse_ty(T, Env, L) ->
    try scan_ty(T, Env, L, [])
    catch
        error:{collapsed_failure_channel, _, _, _, _} = E:S ->
            erlang:raise(error, E, S);
        error:_ ->
            ok
    end.

%% `Seen` is the cycle guard, and it is not optional: without it a
%% contractive alias expands forever. A recursive alias is handled by
%% `resolve/3`; here it only has to terminate.
scan_ty({t_union, Ms}, Env, L, Seen) ->
    collapse_members(Ms, Env, L),
    lists:foreach(fun(M) -> scan_ty(M, Env, L, Seen) end, Ms);
%% An instantiation is expanded here rather than left to `resolve/3`,
%% because `bs_types:union/1` erases the member boundary and the members are
%% what has to be examined. Arguments resolve in the caller's chain, then
%% `subst/2` puts them into the template.
scan_ty({t_generic, N, Args}, Env, L, Seen) ->
    lists:foreach(fun(A) -> scan_ty(A, Env, L, Seen) end, Args),
    case maps:get(N, Env, undefined) of
        {parametric, Params, Body} when length(Params) =:= length(Args) ->
            case lists:member(N, Seen) of
                true ->
                    ok;
                false ->
                    Sub = maps:from_list(
                            lists:zip(Params, [resolve(A, Env) || A <- Args])),
                    scan_ty(subst(Body, Sub), Env, L, [N | Seen])
            end;
        _ ->
            ok
    end;
%% Nested positions, because a failure channel is equally dead one level down:
%% `(option<atom>, int)` normalises to `(atom, int)`.
scan_ty({t_tuple, Cs}, Env, L, Seen) ->
    lists:foreach(fun(C) -> scan_ty(C, Env, L, Seen) end, Cs);
scan_ty({t_map, Fields}, Env, L, Seen) ->
    lists:foreach(fun({field, _, T}) -> scan_ty(T, Env, L, Seen) end, Fields);
scan_ty({t_refined, _, Base, _}, Env, L, Seen) ->
    scan_ty(Base, Env, L, Seen);
%% A `t_ref` is NOT followed. The alias it names is checked at its own
%% declaration, and following it would report one defect once per mention.
scan_ty(_, _Env, _L, _Seen) ->
    ok.

collapse_members(Ms, _Env, _L) when length(Ms) < 2 -> ok;
collapse_members(Ms, Env, L) ->
    each_member(Ms, [resolve(M, Env) || M <- Ms], [], L).

%% One member at a time against the union of all the others, which is what
%% `T | F ≡ T` asks. Surface members identify the channel by shape; resolved
%% ones do the algebra. `Before` accumulates reversed, which is harmless
%% because union is commutative.
each_member([], [], _Before, _L) ->
    ok;
each_member([M | Ms], [R | Rs], Before, L) ->
    case failure_channel(M) of
        no ->
            ok;
        {yes, Channel} ->
            Others = bs_types:union(Before ++ Rs),
            case absorbed(R, Others) of
                true  -> erlang:error({collapsed_failure_channel, L,
                                       Channel, R, Others});
                false -> ok
            end
    end,
    each_member(Ms, Rs, [R | Before], L).

%% The prelude's two failure members: `option<T>` is `T | :nothing` and
%% `result<T, E>` is `T | (:error, E)`. Matched on the surface node, which
%% `subst/2` leaves untouched, since substitution only replaces a `t_ref`.
failure_channel({t_atom, nothing})                 -> {yes, nothing};
failure_channel({t_tuple, [{t_atom, error}, _]})   -> {yes, error};
failure_channel(_)                                 -> no.

%%% ---------------------------------------------------------------------------
%%% Resolving surface types into the algebra
%%% ---------------------------------------------------------------------------

type_env(Decls) ->
    Mod = module_name(Decls),
    Aliases = [{N, alias(Params, T)} || {type_alias, _, N, Params, T} <- Decls],
    %% A refinement enters the environment as a surface node, as an alias
    %% body does, so it inherits `resolve/3`'s cycle guard: `type A = A where
    %% value > 0` is refused by name rather than spinning (ticket 20 §5).
    Refined = [{N, {t_refined, L, Base, Pred}}
               || {type_refined, L, N, Base, Pred} <- Decls],
    Records = [{N, record_surface(Mod, L, N, Fs)}
               || {record_decl, L, N, Fs} <- Decls],
    Env = maps:merge(prelude(), maps:from_list(Aliases ++ Refined ++ Records)),
    %% The environment is heterogeneous: a ground entry is resolved once,
    %% here; a parametric one has free variables and stays a surface
    %% template, resolved per use site after substitution (F6).
    %%
    %% Each entry is resolved under its own name, so a name that reaches back
    %% to itself ties at the top of the entry (F28). The keys are sorted
    %% because a non-contractive cycle is reported by whichever entry is
    %% reached first and `maps:map/2` has no defined order: sorting makes the
    %% reported name a property of the program rather than of a hash.
    lists:foldl(
      fun(N, Acc) ->
              case maps:get(N, Env) of
                  {parametric, _, _} = P -> Acc#{N => P};
                  T -> Acc#{N => bs_types:mu(N, resolve(T, Env, [N]))}
              end
      end, #{}, lists:sort(maps:keys(Env))).

alias([], Body)     -> Body;
alias(Params, Body) -> {parametric, Params, Body}.

%% The prelude is held here, spelled in the language's own alias mechanism,
%% because there is no import system for a prelude file to arrive
%% through (ticket 10 §5, LANGUAGE.md §7). It is two maps, following
%% `PRELUDE.md`'s strata: what a user could have written, and what only the
%% compiler constructs. Nothing here lets a user add to it.
prelude() -> maps:merge(stratum_one(), stratum_two()).

%% Stratum 1: ordinary aliases a user could have written (tickets 10 §5, 15
%% §2). Lowercase because the prelude owns that namespace as `list` does; a
%% user's parametric alias is PascalCase, so the two cannot collide.
stratum_one() ->
    #{option => {parametric, ['T'],
                 {t_union, [{t_ref, 'T'}, {t_atom, nothing}]}},
      result => {parametric, ['T', 'E'],
                 {t_union, [{t_ref, 'T'},
                            {t_tuple, [{t_atom, error}, {t_ref, 'E'}]}]}},
      %% The class a foreign wrapper catches (F19, ticket 15 §5). Only the
      %% generated wrapper produces one of these values, but naming the type
      %% is ordinary: the declaration is how an author asks for the wrapper.
      %% The three members are discriminable by tag, so the collapse check
      %% never fires on them.
      foreign_error =>
          {t_union, [{t_tuple, [{t_atom, error}, {t_builtin, term}]},
                     {t_tuple, [{t_atom, throw}, {t_builtin, term}]},
                     {t_tuple, [{t_atom, exit},  {t_builtin, term}]}]}}.

%% Stratum 2: compiler-known types a user could not have written.
%% `ValidationError` is `ValidateAs<T>`'s payload, a path into the term plus
%% the type expected there, spelled as a tuple (ticket 15 §2); the segment
%% spelling (`".Total"`, `"[2]"`, `"(1)"`) is F18's. PascalCase because a
%% signature names it.
%%
%% It is not made unshadowable by merge order: `type_env/1` merges user
%% declarations over the prelude, so a user's `type ValidationError = int`
%% would silently take effect. The rule that a user may not add to this
%% stratum is enforced as a refusal at the declaration instead
%% (`compiler_known_redeclared/1`), so the diagnostic lands where the fix is.
stratum_two() ->
    #{'ValidationError' =>
          {t_tuple, [{t_generic, list, [{t_builtin, string}]},
                     {t_builtin, string}]}}.

%% `<` opens an instantiation bracket after one of these three names and is
%% a comparison everywhere else; the set is closed (ticket 28). Enforced here
%% rather than in the lexer, because here the three cases can be told apart:
%% built, decided-and-unbuilt, and not an obligation at all.
codegen_obligations() -> ['ValidateAs', 'ParseAtom', 'ToExistingAtom'].

%%% ---------------------------------------------------------------------------
%%% Reserved qualifiers (ticket 67, F32)
%%%
%%% A codegen obligation and a reserved-qualifier operation are the same kind
%%% of entry, compiler-known and existing only as a rule in this file. An
%%% obligation is named unqualified and an operation under a qualifier, and
%%% nothing unqualified is a function, so the two lists cannot merge.
%%% ---------------------------------------------------------------------------

%% `Map` is reserved with no operations under it yet: `map<K, V>` resolves
%% as a type (F33) and `Map.Get` is ENG-324. Reserving the name first is
%% what stops a user module called `Map` being taken away later (ticket 48).
reserved_qualifiers() -> ['List', 'Map', 'Term'].

%% The lowering table's keys, `{Qualifier, Name, Arity}`. Keyed by arity
%% because the BEAM's identity rule is, and because `List.Sum(xs, 0)` must be
%% refused rather than have its second argument silently ignored. These four
%% are the operations the corpus writes plus ticket 16's universal-order
%% escape; `Fold`, `Map` and `Filter` wait on the lambda (ENG-295).
reserved_table() ->
    [{'List', 'Sum', 1}, {'List', 'Length', 1}, {'List', 'Reverse', 1},
     {'Term', 'Compare', 2}].

%% The signature an operation is checked against, at the site. `Reverse`
%% returns the list it was handed, so its result is inlined with that site's
%% element type; the others are monomorphic.
reserved_sig('List', 'Sum', 1, _ATys) ->
    {ok, {[bs_types:list(bs_types:int())], bs_types:int()}};
reserved_sig('List', 'Length', 1, _ATys) ->
    {ok, {[bs_types:list(bs_types:term())], bs_types:int()}};
reserved_sig('List', 'Reverse', 1, [ATy]) ->
    {ok, {[bs_types:list(bs_types:term())],
          bs_types:list(bs_types:list_elem(ATy))}};
reserved_sig('Term', 'Compare', 2, _ATys) ->
    %% A three-atom union rather than `atom`, so a `switch` over it is
    %% exhaustive with three arms and a missing one leaves a named residual
    %% (tickets 16, 67).
    {ok, {[bs_types:term(), bs_types:term()], order_type()}};
reserved_sig(_Q, _Fun, _Arity, _ATys) -> error.

order_type() ->
    bs_types:union([bs_types:atom_lit(lt),
                    bs_types:atom_lit(eq),
                    bs_types:atom_lit(gt)]).

%% The arities this qualifier has for this name. Empty means the name is
%% unknown; non-empty means the wrong arity of a real operation, which
%% `unresolved/6` reports as a different sentence.
reserved_arities(Q, Fun) ->
    [A || {Q1, F1, A} <- reserved_table(), Q1 =:= Q, F1 =:= Fun].

%% A user may not redeclare a stratum-2 type. Every form that introduces a
%% type name is checked, because the hazard is the name being taken.
compiler_known_redeclared(Decls) ->
    Known = maps:keys(stratum_two()),
    Declared = [{N, L} || {type_alias,   L, N, _, _} <- Decls]
            ++ [{N, L} || {type_refined, L, N, _, _} <- Decls]
            ++ [{N, L} || {record_decl,  L, N, _}    <- Decls],
    case [{N, L} || {N, L} <- Declared, lists:member(N, Known)] of
        []             -> ok;
        [{N, L} | _]   -> erlang:error({compiler_known_type, N, L})
    end.

%% A record is a map type carrying a minted tag (ticket 26 §1); there is no
%% record node in the algebra, so the declaration desugars to the anonymous
%% map type a user could have written (F3).
record_surface(Mod, Line, Name, Fields) ->
    %% A declared `Kind` field is refused at the declaration, since the mint
    %% would otherwise silently overwrite it.
    case [F || F = {field, 'Kind', _} <- Fields] of
        [] -> ok;
        _  -> erlang:error({kind_field_is_minted, Line, Name})
    end,
    {t_map, [{field, 'Kind', {t_atom, qualified(Mod, Name)}} | Fields]}.

%% The single minting point. The tag mints from the qualified name, so
%% `Shop.Orders.Order` and `Billing.Invoices.Order` never unify (ticket 26
%% §1).
qualified(Mod, Name) ->
    list_to_atom(atom_to_list(Mod) ++ "." ++ atom_to_list(Name)).

%% The declared field order, for the emitter. `Kind` is dropped: it is minted,
%% never assigned.
record_fields({t_map, Fields}) -> [N || {field, N, _} <- Fields, N =/= 'Kind'].

%% The minted tag and the declared field names of a record named in a
%% pattern (F22, ticket 55). The tag is read back out of the resolved type
%% rather than re-minted, so patterns cannot disagree with `qualified/2`.
%% Only a single closed map member carrying a singleton `Kind` is a record;
%% a union, an untagged map or an alias to `int` gets `not_a_record`. An
%% unknown prefix raises `resolve/2`'s `{unknown_type, Name}`. Mirrors
%% `bs_emit:record_tag/2`.
record_of(Name, Line, Env) ->
    case resolve({t_ref, Name}, Env) of
        #{maps := [{closed, Fs}], atoms := {finite, []}, ints := [],
          tuples := [], lists := [], bins := []} ->
            case maps:find('Kind', Fs) of
                {ok, #{atoms := {finite, [Tag]}, ints := [], tuples := [],
                       lists := [], maps := [], bins := []}} ->
                    %% `Kind` is dropped, so `Frame { Kind: ... }` is refused
                    %% as it is at construction: it is minted, never written.
                    {Tag, maps:keys(Fs) -- ['Kind']};
                _ -> erlang:error({not_a_record, Line, Name})
            end;
        _ -> erlang:error({not_a_record, Line, Name})
    end.

%% An already-resolved type passes through, so the emitter can hand this
%% either a surface type or one the environment has already reduced.
%%
%% `Seen` is the chain of alias names this resolution has entered; without
%% it a cyclic alias hangs rather than errors. The chain also records
%% constructor crossings, which tells the two refusals apart: recursion must
%% pass through a type constructor (ticket 09 §3). A definition that does is
%% contractive and denotes a regular tree; one that does not is meaningless:
%%
%%   type X = X | int                         not contractive: permanent error
%%   type Tree = :leaf | (:node, Tree, Tree)  contractive: a type
%%
%% `'$ctor'` is pushed when the walk descends through a constructor, and
%% `revisit/2` asks whether one lies between the head of the chain and the
%% name met again. A union is a Boolean connective and does not count; nor
%% does a refinement, which is a subset of its base. `$` keeps the marker out
%% of the PascalCase type-name grammar.
resolve(T, Env) -> resolve(T, Env, []).

resolve(T, _Env, _Seen) when is_map(T) -> T;
resolve({t_atom, A}, _Env, _Seen)    -> bs_types:atom_lit(A);
%% A lowercase name is a builtin or a prelude entry. `option` alone is a
%% known type written without its bracket, not an unknown one, and only the
%% environment knows what the prelude holds, so the check is here rather
%% than in `builtin/1`. A ground prelude entry such as `foreign_error`
%% resolves like any other alias, in both forms: still a surface tuple while
%% `type_env/1` is resolving, and a reduced map afterwards (F19). It owes
%% the same cycle guard as `{t_ref, N}`.
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
%% A revisit of a contractive alias is a back-reference, and the resolution
%% that entered the name wraps its result in the matching `mu` (F28);
%% `revisit/2` still refuses the non-contractive case. `bs_types:mu/2` drops
%% the binder when the body never mentions it, so a non-recursive alias
%% resolves as before.
resolve({t_ref, N}, Env, Seen) ->
    case revisit(N, Seen) of
        knot -> bs_types:recvar(N);
        new ->
            case maps:get(N, Env, undefined) of
                undefined -> erlang:error({unknown_type, N});
                {parametric, Params, _} ->
                    erlang:error({needs_type_args, N, length(Params)});
                T when is_map(T) -> T;
                Surface -> bs_types:mu(N, resolve(Surface, Env, [N | Seen]))
            end
    end;
resolve({t_tuple, Cs}, Env, Seen) ->
    bs_types:tuple([resolve(C, Env, ctor(Seen)) || C <- Cs]);
%% A declared map type is closed: it fixes its domain (ticket 26 §4), and a
%% wider record is simply a different type (§5).
resolve({t_map, Fields}, Env, Seen) ->
    bs_types:map_closed(
      maps:from_list([{N, resolve(T, Env, ctor(Seen))} || {field, N, T} <- Fields]));
%% `list<T>` is algebra-primitive — the list part is a pair of flags, not an
%% alias body — so it is the one bracket that cannot be written as a prelude
%% alias and is resolved here.
resolve({t_generic, list, [T]}, Env, Seen) ->
    bs_types:list(resolve(T, Env, ctor(Seen)));
resolve({t_generic, list, Args}, _Env, _Seen) ->
    erlang:error({generic_arity, list, 1, length(Args)});
%% `map<K, V>` is algebra-primitive for `list<T>`'s reason: a domain member
%% is a pair of types, not an alias body, so no alias could express
%% it (ticket 48, F33). The `Kind` exclusion lives in the member's own
%% meaning (`bs_types:map_dom/2`), not here.
resolve({t_generic, map, [K, V]}, Env, Seen) ->
    bs_types:map_dom(resolve(K, Env, ctor(Seen)), resolve(V, Env, ctor(Seen)));
resolve({t_generic, map, Args}, _Env, _Seen) ->
    erlang:error({generic_arity, map, 2, length(Args)});
%% An instantiation substitutes the ground arguments into the alias body and
%% resolves that (ticket 27 §(b)); the variable is gone before `bs_types`
%% sees anything, so `option<int>` and `int | :nothing` are the same
%% type (F6).
%%
%% A parametric alias knots on the instantiation, not on the name (F28):
%% `T<int>` meeting `T<int>` is a cycle and ties, while `T<int>` meeting
%% `T<list<int>>` is not. A name that recurs under different arguments is
%% not a regular tree and is refused by name rather than expanded, because
%% expanding is the hang.
resolve({t_generic, N, Args}, Env, Seen) ->
    case maps:get(N, Env, undefined) of
        undefined -> erlang:error({unknown_generic, N});
        {parametric, Params, Body} when length(Params) =:= length(Args) ->
            %% Arguments are resolved in the CALLER's chain, not the callee's:
            %% they are siblings of this application, not steps below it.
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
        _Ground ->
            erlang:error({not_parametric, N})
    end;
resolve({t_union, Ms}, Env, Seen) ->
    bs_types:union([resolve(M, Env, Seen) || M <- Ms]);
%% A refinement adds no node to the algebra: it is a subset of its base, so
%% it resolves to an ordinary type and `is_subtype(Octet, int)` falls
%% out (ticket 20 §5).
resolve({t_refined, Line, Base, Pred}, Env, Seen) ->
    refine(resolve(Base, Env, Seen), Pred, Line).

%% The refinement and the guard go through one translator, `alternatives/1`,
%% so a parameter declared `Octet` and a clause guarded `when n > 128` cannot
%% disagree about what `>= 0 and <= 255` means (F2). `value` is bound to the
%% empty path, the whole type, which is the address a switch arm's guard
%% refines too.
%%
%% An untranslatable predicate is an error, not a widening. A guard the
%% checker cannot read credits nothing, which is sound; a refinement it
%% cannot read would resolve to its bare base and silently admit the opaque
%% tier ticket 20 §5 bars, and this surface has no other site to check it.
refine(Base, Pred, Line) ->
    case alternatives(Pred) of
        unknown -> erlang:error({opaque_refinement, Line});
        Alts ->
            Results = [refine_all(Base, #{value => []}, A) || A <- Alts],
            case lists:member(none_marker, Results) of
                %% `none_marker` means the predicate named something other
                %% than `value`: unreadable, so refused rather than guessed.
                true  -> erlang:error({opaque_refinement, Line});
                false ->
                    Refined = bs_types:union(Results),
                    case bs_types:is_none(Refined) of
                        %% An empty refinement is a typo: a signature over
                        %% it declares a function nothing can call.
                        true  -> erlang:error({empty_refinement, Line});
                        false -> Refined
                    end
            end
    end.

%% Descending through a constructor. One marker per descent, not per component:
%% the question is whether the recursion passed through a shape, and a tuple's
%% three fields are three siblings below ONE crossing.
ctor(Seen) -> ['$ctor' | Seen].

%% A contractive revisit is a knot the caller ties off with a binder; a
%% non-contractive one is an error, because `type X = X | int` describes no
%% set of values (F28). `Key` is an atom for a ground alias and
%% `{Name, ResolvedArgs}` for a parametric one.
revisit(Key, Seen) ->
    case lists:member(Key, Seen) of
        false -> new;
        true  ->
            %% Everything entered since this key was, most recent first. A
            %% marker in there means the recursion crossed a constructor and
            %% the definition is contractive.
            Since = lists:takewhile(fun(E) -> E =/= Key end, Seen),
            case lists:member('$ctor', Since) of
                true  -> knot;
                false -> erlang:error({cyclic_type, key_name(Key)})
            end
    end.

key_name({N, _}) -> N;
key_name(N)      -> N.

%% One binder name per instantiation. `T<int>` and `T<string>` are two types
%% and get two names; the hash is over the resolved arguments, so the same
%% instantiation always lands on the same name and ties to itself.
gen_name({N, RArgs}) ->
    list_to_atom(atom_to_list(N) ++ "$" ++ integer_to_list(erlang:phash2(RArgs))).

%% The same name already open at DIFFERENT arguments: the expansion is not a
%% regular tree, so no binder can hold it and unfolding would not terminate.
%% Refused rather than expanded, because expanding is the hang.
non_regular_check(N, RArgs, Seen) ->
    case [K || {M, A} = K <- Seen, M =:= N, A =/= RArgs] of
        []      -> ok;
        [_ | _] -> erlang:error({non_regular_recursion, N})
    end.

%% Substitution is over the surface type, and what it substitutes in is an
%% already-resolved algebra type, which `resolve/3`'s first clause then passes
%% straight through. So a parameter is replaced exactly once and never
%% re-walked.
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
%% `string` is `binary` refined by valid UTF-8, so it resolves to a subset
%% and `string <: binary` falls out of the algebra (ticket 20 §4).
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
            {Residual, Diags0} =
                case map_pattern_diags(Clauses, Params, Env, Name) of
                    %% A clause that destructures a domain-map parameter is
                    %% refused before the walk, not left to fall out of the
                    %% meet (ticket 48 Q2). `#{Status => 1}` is a member of
                    %% `map<atom, term>`, so "this clause's pattern is not a
                    %% member of it" would be a false sentence about the
                    %% language rather than a true one about the compiler, and
                    %% every downstream number would be computed from a
                    %% pattern the compiler cannot honour. The residual is
                    %% emptied so this is one error and not two: handing back
                    %% `Declared` would add an inexhaustive report that is a
                    %% consequence of the first error, and the author would fix
                    %% the wrong one.
                    [_ | _] = Ds -> {bs_types:none(), Ds};
                    []           -> walk(Clauses, Declared, Declared, Ctx, [], 1)
                end,
            Diags = with_corrected_signature(F, Diags0),
            Final =
                case bs_types:is_none(Residual) of
                    true  -> Diags;
                    %% The residual is carried as a type, not a string: it is
                    %% the missing case, so the caller formats it as a clause
                    %% head rather than as a type expression (ticket 04).
                    false -> Diags ++ [{error, Line, Name,
                                       {inexhaustive, Residual,
                                        record_names(Env)}}]
                end,
            {F, Final}
    end.

%%% ---------------------------------------------------------------------------
%%% The corrected signature (F25, ticket 23 §8)
%%%
%%% When a clause returns outside its signature, the diagnostic carries a
%%% corrected signature the author can paste. The compiler synthesises heads
%%% and never bodies, and a signature is a head (ticket 23 §2).
%%%
%%% The correction is a property of the function, not of the clause that
%%% tripped it. Two offending clauses corrected separately print two
%%% contradictory lines, `int | :zero` and `int | (:error, string)`, and
%%% pasting either leaves the other clause wrong; so every residual is
%%% unioned first and the one answer is attached to all of them.
%%% ---------------------------------------------------------------------------

with_corrected_signature(F, Diags) ->
    case [R || {error, _, _, {return_not_declared, R}} <- Diags] of
        []  -> Diags;
        Rs  -> C = corrected_signature(F, bs_types:union(Rs)),
               [attach_correction(D, C) || D <- Diags]
    end.

attach_correction({error, L, N, {return_not_declared, R}}, C) ->
    {error, L, N, {return_not_declared, R, C}};
attach_correction(D, _C) ->
    D.

%% A signature that cannot be rendered as pasteable source is `none`, never a
%% guess: a line that looks pasteable and is not is worse than no
%% line (ticket 23 §2).
corrected_signature(#fn{name = Name, ret = Ret, params = Params, vis = Vis}, Union) ->
    Rendered = bs_types:to_string(Union),
    case writable(Rendered) of
        false -> none;
        true  ->
            case {type_source(Ret), params_source(Params)} of
                {none, _} -> none;
                {_, none} -> none;
                {RetSrc, Ps} ->
                    lists:flatten([vis_source(Vis), RetSrc, " | ", Rendered,
                                   " ", atom_to_list(Name), "(", Ps, ")"])
            end
    end.

%% A rendered type is pasteable unless it contains a spelling B# source cannot
%% write. The test is on the rendered string because that is what gets
%% printed. `bs_types`' printer produces each unwritable spelling in exactly
%% one place: `{` from `m_str/1`, the record field set carrying the minted
%% tag (ticket 26 §1), and `\` from `b_str([other])`. Both survive nesting
%% inside a tuple or a list, because nesting renders through the same
%% printers.
writable(S) ->
    string:find(S, "{") =:= nomatch andalso string:find(S, "\\") =:= nomatch.

%% `public` is written only where the original signature carried it; an
%% unmarked signature is private (F12), and a pasted line that silently
%% exported a private function would be a worse defect than the one fixed.
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

%% The declared half of the correction is rendered from the type AST, what
%% the author wrote, not from the algebra. A function declared to return the
%% record `Order` renders through `bs_types:to_string/1` as
%% `{ Kind: :'Shop.Order', … }` and through the AST as `Order`, and only the
%% latter makes `Order | :oops` expressible.
%%
%% An unrecognised form answers `none` and the whole line is dropped, so a
%% type construct added later cannot leak a half-rendered signature.
type_source({t_atom, A})        -> ":" ++ atom_to_list(A);
type_source({t_builtin, B})     -> atom_to_list(B);
type_source({t_ref, N})         -> atom_to_list(N);
type_source({t_tuple, Cs})      -> bracket("(", Cs, ", ", ")");
type_source({t_union, Ms})      -> join_source(Ms, " | ");
type_source({t_generic, N, As}) ->
    case bracket("<", As, ", ", ">") of
        none -> none;
        S    -> atom_to_list(N) ++ S
    end;
%% An inline structural map is refused rather than rendered. It is the one
%% written form that can carry a `Kind:` field, and a signature is not where
%% this feature wants to reason about whether the author's tag is theirs to
%% paste. A record named in a signature arrives as `t_ref` and is unaffected.
type_source({t_map, _Fields})   -> none;
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

%%% ---------------------------------------------------------------------------
%%% Scope: bindings and the names a body may read (ticket 34)
%%%
%%% Every name a body reads must be bound, and the checker reports it rather
%%% than letting `erlc` report it against the emitted `.abstr`, a file the
%%% author did not write. These are name questions, decidable syntactically;
%%% nothing here asks what type an expression has, so the body stays
%%% untyped (ticket 33).
%%%
%%% Bindings do not shadow. A name means one thing in a clause, so rebinding
%%% is an error rather than a new scope: a second `x =` reads as an
%%% assignment in a language with no mutation to assign with (ticket 08).
%%% ---------------------------------------------------------------------------

scope_diags({clause, Line, Name, Patterns, Guard, Body}) ->
    {Bound, HeadDiags} = head_scope(Patterns, Line, Name),
    HeadDiags ++
    %% A guard is read in the scope of the clause head alone; bindings come
    %% after it. An unbound name in a guard is a `bsc` error like any
    %% other (F4), not an `erlc` error against the emitted file.
    guard_scope(Guard, Bound, Line, Name) ++ check_scope(Body, Bound, Name, Line, []).

%% A bare name repeated in a clause head is an error: a bare name introduces,
%% and `== name` is how a pattern asks for a match (ticket 45, F8.10).
%% Accepting `F(acc, acc)` as a plain double binding would be a soundness
%% hole: `pattern_type/3` reads the second `acc` as a fresh variable covering
%% the whole domain, while the emitted Erlang repeats `_Acc` and so makes it
%% an equality test, and `F(1, 2)` crashed with `function_clause` on a
%% function proved total. `pattern_row/2` merges binding maps with
%% `maps:merge/2`, which keeps the rightmost duplicate silently, so the
%% refusal lives here rather than there.
%%
%% A head is one simultaneous match, so `== acc` may name a parameter to its
%% left or its right. That is what the emitted Erlang does, and a
%% left-to-right rule the target lacks would be one more rule to teach.
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
    %% `== acc` reads a name rather than introducing one, so it must resolve,
    %% and in a head the only scope is the head itself.
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
    %% The final expression carries no line of its own, since the parser keeps
    %% one per binding and one per clause, so an unbound name in it is reported
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

%% An expression may neither read an unbound name nor rebind a bound one.
%% The two are checked together because they are asked at the same points
%% against the same running scope; a switch arm is the one thing besides a
%% binding that introduces a name mid-expression (F7).
name_diags(Expr, Bound, Line, Name, Acc) ->
    [{error, Line, Name, {unbound_variable, V}}
     || V <- lists:usort(expr_vars(Expr)), not lists:member(V, Bound)]
        ++ rebinds(Expr, Bound, Name) ++ Acc.

%% A switch arm may not rebind a name already in scope (ticket 34). In Erlang
%% a `case` arm pattern naming an already-bound variable is an equality test
%% against the existing value, not a binding, so accepting it would emit a
%% silently different program from the one that reads like a fresh binding.
%%
%% Generic below the switch case: a switch can sit anywhere an expression
%% can, and enumerating the grammar again to find one node would be another
%% copy of the same walk.
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
    %% `== name` in an arm must name something in scope: it matches a bound
    %% value rather than introducing one, so an unknown name is the mirror of
    %% the rebinding error and is reported here, not by `erlc` (F8, F4).
        ++ [{error, Line, Name, {unbound_variable, V}}
            || V <- lists:usort(pattern_matched_vars(P)),
               not lists:member(V, Bound ++ Vars)]
        ++ rebinds(Body, Inner, Name)
        ++ case Guard of none -> []; {guard, G} -> rebinds(G, Inner, Name) end.

pattern_vars({p_var, _, V})            -> [V];
%% A segment binder is an ordinary name (F13). `seg_wild` and the literal
%% forms introduce nothing, and a segment's size is a name being read rather
%% than bound, so it belongs to `pattern_matched_vars/1` and not here.
pattern_vars({p_bin, _, Segs})         ->
    [V || {seg_bind, _, V, _} <- Segs];
pattern_vars({p_tuple, _, Ps})         -> lists:append([pattern_vars(P) || P <- Ps]);
pattern_vars({p_map, _, Fs})           -> lists:append([pattern_vars(P) || {_, P} <- Fs]);
%% A type-prefixed record pattern carries the same field list a property
%% pattern does; the type name binds nothing (F22).
pattern_vars({p_rec, _, _, Fs})        -> lists:append([pattern_vars(P) || {_, P} <- Fs]);
%% A binder introduces its name and the pattern under it still binds:
%% `Frame { Payload: p } f` introduces both (F22). Answering `[V]` alone
%% would make the sub-pattern's names unreadable in the body with no
%% diagnostic.
pattern_vars({p_bind, _, V, P})        -> [V | pattern_vars(P)];
pattern_vars({p_list, _, Items, Rest}) ->
    lists:append([pattern_vars(P) || P <- Items])
        ++ case Rest of nil -> []; R -> pattern_vars(R) end;
%% `p_eqvar` is deliberately absent: `== acc` matches the value `acc` holds
%% and introduces nothing, which is the distinction the token exists to
%% mark (ticket 45).
pattern_vars(_)                        -> [].

%% Every name a pattern reads, which today is exactly `== name`. Separate from
%% `pattern_vars/1` because the two answer opposite questions about the same
%% tree, and a pattern may do both: `F(k, { Kind: == k })` binds `k` and
%% reads it.
pattern_matched_vars({p_eqvar, _, V})          -> [V];
pattern_matched_vars({p_tuple, _, Ps})         ->
    lists:append([pattern_matched_vars(P) || P <- Ps]);
pattern_matched_vars({p_map, _, Fs})           ->
    lists:append([pattern_matched_vars(P) || {_, P} <- Fs]);
pattern_matched_vars({p_rec, _, _, Fs})        ->
    lists:append([pattern_matched_vars(P) || {_, P} <- Fs]);
%% The binder introduces, so it reads nothing itself, but the pattern under
%% it may: `Frame { Kind: == k } f` must still report reading `k`.
pattern_matched_vars({p_bind, _, _, P})        -> pattern_matched_vars(P);
pattern_matched_vars({p_list, _, Items, Rest}) ->
    lists:append([pattern_matched_vars(P) || P <- Items])
        ++ case Rest of nil -> []; R -> pattern_matched_vars(R) end;
pattern_matched_vars(_)                        -> [].

%% Every variable an expression reads. Not shared with the emitter's
%% `used_vars/2`, which answers a different question, whether to underscore
%% a name it is about to emit, and would drag a lowering concern into the
%% checker to save ten lines.
expr_vars({e_var, _, V})               -> [V];
expr_vars({e_proj, _, V, _})           -> [V];
expr_vars({e_tuple, _, Es})            -> lists:append([expr_vars(E) || E <- Es]);
expr_vars({e_call, _, _, As})          -> lists:append([expr_vars(A) || A <- As]);
%% The type arguments of an instantiation hold no variables, so only the
%% value arguments are walked (F18).
expr_vars({e_inst, _, _, _, As})       -> lists:append([expr_vars(A) || A <- As]);
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
%% An arm's pattern names are readable in that arm and nowhere else, so the
%% subtraction is per arm, not per switch. Either mistake is silent: subtract
%% nothing and a name the arm bound is reported unbound; subtract the whole
%% switch's names and a typo in one arm is covered by a sibling arm that
%% binds the same name.
expr_vars({e_switch, _, Subject, Arms}) ->
    expr_vars(Subject) ++ lists:append([arm_free_vars(A) || A <- Arms]);
%% A valve is walked as the switch it lowers to (F14). This walk enumerates
%% the grammar and falls through to `[]`, so without this clause a misspelled
%% name inside a valve stage would be accepted in silence.
expr_vars({e_valve, _, Switch})        -> expr_vars(Switch);
expr_vars(_)                           -> [].

arm_free_vars({arm, _, P, Guard, Body}) ->
    Bound = pattern_vars(P),
    Read = case Guard of none -> []; {guard, G} -> expr_vars(G) end ++ expr_vars(Body),
    [V || V <- Read, not lists:member(V, Bound)].

%%% ---------------------------------------------------------------------------
%%% The body check (ticket 33, F5)
%%%
%%% Two halves. Synthesis: every expression gets a type, and nothing in it is
%%% inferred, because every non-structural form reads a type some declaration
%%% already wrote down (ticket 04's mandatory signature). Obligation:
%%% containment is checked at exactly the five sites where a type was
%%% declared: call argument, construction, projection, clause return and
%%% destructuring bind. `e_op`, `e_tuple`, `e_list` and `e_block` declare
%%% nothing, so they synthesise and never check.
%%%
%%% Four of the five hand back a residual the printer renders as a clause
%%% head. Construction is the exception: two closed maps over different key
%%% sets are simply disjoint, so its residual is field names instead
%%% (see field_delta/2).
%%% ---------------------------------------------------------------------------

clause_diags(C = {clause, Line, _, Patterns, Guard, Body}, Domain, Bindings, Ctx0) ->
    case segment_diags(Patterns, Ctx0#ctx.fname) of
        %% A malformed segment is reported alone: the bindings a broken
        %% pattern produces are wrong, so every type error downstream of it
        %% would be about the compiler's guess rather than the author's
        %% program.
        [_ | _] = SegErrors -> SegErrors;
        [] -> clause_diags_1(C, Line, Patterns, Guard, Body, Domain, Bindings, Ctx0)
    end.

clause_diags_1(C, Line, Patterns, Guard, Body, Domain, Bindings, Ctx0) ->
    guard_diags(Guard, Ctx0) ++
    case scope_diags(C) of
        [] ->
            Ctx = Ctx0#ctx{binds = Bindings},
            Scope = clause_scope(Patterns, Bindings, Domain),
            {Ty, Diags} = type_of(Body, Scope, Ctx),
            Diags ++ return_diags(Ty, Line, Ctx);
        Errors ->
            %% A clause whose names do not resolve is not typed. Every unbound
            %% name would answer `term`, which fails most containments, so the
            %% author would meet a pile of type errors about a typo.
            Errors
    end.

%%% --- Binary patterns: four known-shape refusals (F13) ----------------------
%%%
%%% A malformed binary segment is a diagnostic naming the mistake and the fix,
%%% as the record's `Id:int` and `Notes?: int` productions are, not a parse
%%% error naming a token. The least obvious of the four: a size naming
%%% something not bound earlier in the same pattern is legal Erlang and simply
%%% never matches, so left to the emitter it would be a silent match failure
%%% at run time against a file the author did not write (F4).

segment_diags(Patterns, Name) ->
    lists:append([bin_diags(P, Name) || P <- Patterns]).

%% Structural, because a binary pattern can sit inside a tuple or a record
%% field the same as any other pattern, and a fault there is the same fault.
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

%% An unsized segment is the remainder, so it can only be last (F13 §2).
%% Anywhere else it would consume everything and starve the segments after
%% it, which Erlang also refuses, with a message about its own syntax.
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

%% A literal segment must fit its width. The diagnostic carries both numbers,
%% because the author's mistake is usually the width and not the value:
%% `0xCE:4` is a typo in the 4, not in the 0xCE.
literal_diags({seg_int, Line, K, N}, Name) when is_integer(N), N > 0 ->
    Max = (1 bsl N) - 1,
    case K >= 0 andalso K =< Max of
        true  -> [];
        false -> [{error, Line, Name, {segment_literal_too_wide, K, N, Line}}]
    end;
literal_diags({seg_int, Line, _K, N}, Name) ->
    [{error, Line, Name, {segment_width_not_positive, N, Line}}];
literal_diags(_, _) -> [].

%% A guard is not typed, but `_` as a value and a `switch` in a guard are
%% refused here, syntactically. A guard shares the whole expression grammar,
%% so both parse; left alone, `_` reaches `bs_emit:expr/2` as a crash and the
%% switch reaches the author as `illegal guard expression` from `erlc`
%% against a file they did not write (F5, F7, F4.7).
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

%% The same walk, stopping at a switch rather than descending through it:
%% one error per guard is what the author needs, and a switch nested inside a
%% refused switch is not a second mistake.
switches({e_switch, L, _, _})    -> [L];
switches(T) when is_tuple(T)     -> switches(tuple_to_list(T));
switches(L) when is_list(L)      -> lists:append([switches(E) || E <- L]);
switches(_)                      -> [].

%% Site 4, the clause return: a body's type must be contained in the declared
%% return type. Every function is emitted with a `-spec` (ticket 13), so an
%% unchecked return would publish an unverified claim, the fault ticket 18
%% measured in Gleam's handling of `@external`.
return_diags(Ty, Line, #ctx{ret = Ret, fname = Name}) ->
    case bs_types:subtract(Ty, Ret) of
        R ->
            case bs_types:is_none(R) of
                true  -> [];
                false -> [{error, Line, Name, {return_not_declared, R}}]
            end
    end.

%% A body variable's type is read off the clause's refined domain at the path
%% the pattern recorded, never off the pattern itself, which answers `term`
%% for a bare variable and would fail every call site in the corpus.
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

%% The read-only twin of refine_at/3. It unions across the alternatives at
%% each step rather than indexing one, because the domain's tuple part is a
%% list of products and its map part a list of members; an earlier clause
%% narrowing to a union is the ordinary case.
at_path(Ty, []) -> Ty;
at_path(#{tuples := top}, [I | _]) when is_integer(I) -> bs_types:term();
at_path(#{tuples := Products}, [I | Rest]) when is_integer(I) ->
    at_path(union_of([lists:nth(I, P) || P <- Products, length(P) >= I]), Rest);
at_path(#{maps := top}, [{field, _} | _]) -> bs_types:term();
at_path(#{maps := Members}, [{field, K} | Rest]) ->
    at_path(union_of([maps:get(K, Fs) || {_, Fs} <- Members, maps:is_key(K, Fs)]), Rest);
%% A binary segment carries its own type rather than addressing one (F13).
%% The declared type at this position is `binary`, which has no components,
%% so the width the pattern wrote is the answer and `Ty` is discarded; that is
%% sound because a segment's value is not a part of the binary's type in any
%% sense the algebra knows.
at_path(_Ty, [{seg, SegTy} | Rest]) ->
    at_path(SegTy, Rest);
at_path(Ty, [{elem} | Rest]) ->
    at_path(elem_of(Ty), Rest);
%% The tail of a non-empty list is a list over the same elements, the empty
%% list included, since `[x, ..t]` says nothing about how long the tail is.
at_path(Ty, [{tail} | Rest]) ->
    at_path(bs_types:list(elem_of(Ty)), Rest).

%% What a list holds, whatever spines it is made of (F20).
elem_of(Ty) -> bs_types:list_elem(Ty).

union_of([]) -> bs_types:none();
union_of(Ts) -> bs_types:union(Ts).

%%% --- synthesis, and the checks that hang off it ----------------------------

%% Returns {Type, Diags}. Checking happens during synthesis rather than in a
%% pass after it, because an argument's type is only known by synthesising it
%% and a nested call is the ordinary case.
type_of({e_int, _, N}, _S, _C)  -> {bs_types:range(N, N), []};
type_of({e_atom, _, A}, _S, _C) -> {bs_types:atom_lit(A), []};
%% A string literal is a `string` by construction, not a `binary`: the lexer
%% has already established the UTF-8 property over the bytes, and nothing
%% downstream re-checks it (ticket 20 §4).
type_of({e_str, _, _}, _S, _C) -> {bs_types:string(), []};
type_of({e_var, _, V}, S, _C)   -> {maps:get(V, S, bs_types:term()), []};
%% `_` is an expression only so that `(a, _) = pair` parses. Used as a value
%% it is rejected here, so the author does not meet `variable '_' is unbound`
%% from `erlc` against a file they did not write.
type_of({e_wild, L}, _S, C) ->
    {reported(), [{error, L, C#ctx.fname, wildcard_as_value}]};
type_of({e_tuple, _, Es}, S, C) ->
    {Tys, D} = type_of_all(Es, S, C),
    {bs_types:tuple(Tys), D};
%% `e_op` declares nothing, so it synthesises and never checks; `1 + 2` is
%% `int`, not `range(3,3)`, because exact interval arithmetic is not
%% built (ticket 16 §2, F2).
type_of({e_op, L, Op, A, B}, S, C) ->
    {_, D1} = type_of(A, S, C),
    {BTy, D2} = type_of(B, S, C),
    {op_type(Op), D1 ++ D2 ++ divisor_diags(Op, BTy, L, C)};
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
%% Site 3, projection: legal exactly where every member of the receiver's
%% type carries the field, and the residual is the member that lacks it, the
%% tag to discriminate on (F3.8).
type_of({e_proj, L, V, Field}, S, C) ->
    Recv = maps:get(V, S, bs_types:term()),
    Lacking = lacking(Recv, Field),
    case bs_types:is_none(Lacking) of
        true  -> {field_type(Recv, Field), []};
        false -> {reported(),
                  [{error, L, C#ctx.fname,
                    {field_absent, projection, Field, Lacking}}]}
    end;
%% Site 2, construction: a record literal must carry exactly the declared
%% field set, with each value contained in its declared type. Without this a
%% body could build a map wearing an `Order` tag without `Order`'s fields (F3).
type_of({e_record, L, Name, Fields}, S, C) ->
    {Tys, D} = type_of_all([E || {_, E} <- Fields], S, C),
    case maps:get(Name, C#ctx.types, undefined) of
        undefined ->
            {reported(), [{error, L, C#ctx.fname, {unknown_record, Name}} | D]};
        Ty ->
            case declared_fields(Ty) of
                unknown -> {Ty, D};
                Declared ->
                    Keys = [K || {K, _} <- Fields],
                    case field_delta(Keys, Declared) of
                        %% Names first, and the value half runs only when they
                        %% agree. An undeclared key has no declared type, so
                        %% checking its value would report on the compiler's
                        %% guess rather than the author's program, as with a
                        %% malformed segment in `clause_diags`.
                        {[], []} ->
                            {Ty, field_value_diags(Keys, Tys, Ty, Name, L, C) ++ D};
                        {Missing, Extra} ->
                            {Ty, [{error, L, C#ctx.fname,
                                   {field_set_mismatch, Name, construction,
                                    Missing, Extra}} | D]}
                    end
            end
    end;
%% `with` is site 2 again, not a sixth site (ticket 36). The result has the
%% base's type, because width preservation is a fact about names (ticket 26
%% §2); each updated value is checked against the field's declared type, so
%% `Total: int` governs `o with { Total = … }` as it governs
%% `Order{ Total = … }`. The updated keys must be a subset of the declared
%% ones, so `with` can never report a missing field; without the name half,
%% `o with { Nope = 1 }` compiled clean and raised `{badkey,'Nope'}`.
%%
%% The subject itself is checked too (ENG-249). One closed record takes the
%% branch above. Anything else is asked site 3's question: the subject minus
%% an open map carrying the field is the member that may lack it, and a
%% non-empty residual refuses. An `int`, a `term`, a list of pairs and a
%% union one member short all fall to that subtraction; a union whose every
%% member carries the field is legal and is value-checked per member. Before
%% this, `n with { Total = 1 }` on an `int` raised `{badmap, N}` at run time.
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
%% A switch is checked as `walk/5` over one column (ticket 17 §6): a clause
%% row's domain is a product of declared parameter types and a switch's is a
%% single synthesised type, with the same `pattern_type/3`, `apply_guard/3`,
%% `Certain`/`Possible` split and residual. A switch declares nothing, so it
%% opens no sixth site; it synthesises the union of its arms (F7).
type_of({e_switch, L, Subject, Arms}, S, C) ->
    {SubjTy, D0} = type_of(Subject, S, C),
    {Ty, D1} = switch_over(L, SubjTy, Arms, S, C, authored),
    {Ty, D0 ++ D1};
%% A valve is checked as the two-armed switch `bs_lower` turned it into, so
%% the value arm's variable already has the residual after `(:error, E)` is
%% removed (F14, ticket 17 §4). This clause exists because that switch is
%% generated, not authored. A valve over a value that cannot fail is an error
%% naming `|>` as the fix, rather than `unreachable arm 1`, a remark about
%% code the author never wrote (F14 §4); reachability is asked of the error
%% arm's own pattern, so the question is the one `bs_lower` wrote down. And
%% the arm walk runs as `generated`, because the value arm is a catch-all by
%% construction and the rule against catch-alls is about what an author may
%% discard (ticket 12 §2).
type_of({e_valve, L, {e_switch, _, Subject, Arms}}, S, C) ->
    {SubjTy, D0} = type_of(Subject, S, C),
    [{arm, _, ErrPat, _, _} | _] = Arms,
    {ErrTy, _, _} = pattern_type(ErrPat, [], C#ctx.types),
    case bs_types:is_none(bs_types:intersect(ErrTy, SubjTy)) of
        true ->
            {reported(),
             D0 ++ [{error, L, C#ctx.fname, {valve_on_infallible, SubjTy}}]};
        false ->
            {Ty, D1} = switch_over(L, SubjTy, Arms, S, C, generated),
            {Ty, D0 ++ D1}
    end;
%% `ValidateAs<T>(x)` is a codegen obligation, not a call (F18). `<T>` is a
%% compile-time argument driving generation, monomorphic at every use, with
%% no type variable surviving into the runtime or the algebra (ticket 27 §8),
%% so there is no callee to look up and the type synthesised here is one the
%% compiler computed rather than one anybody declared.
%%
%% The argument is synthesised and its type discarded: a nested call inside
%% it must still be checked (`ValidateAs<int>(F(x))`), and there is no rule
%% to check the argument's type against. The value arrives as a
%% `term` (ticket 11 §2), but nothing forbids validating something narrower.
type_of({e_inst, L, 'ValidateAs', TypeArgs, Args}, S, C) ->
    {_, D0} = type_of_all(Args, S, C),
    case {TypeArgs, Args} of
        {[TypeExpr], [_]} ->
            %% `resolve/2` raises for an unknown, cyclic or recursive type, and
            %% all three already have their diagnostics. An unknown `T` here is
            %% the same mistake as an unknown `T` in a signature and reads the
            %% same way.
            Ty = resolve(TypeExpr, C#ctx.types),
            case validate_collapses(Ty, C#ctx.types) of
                true  -> {reported(),
                          D0 ++ [{error, L, C#ctx.fname, {validate_collapses, Ty}}]};
                false ->
                    %% A domain-keyed map is refused as a `ValidateAs`
                    %% target (ticket 48 Q2, ENG-323). `map_cases/1` in
                    %% `bs_emit` builds its worklist from `{closed,_}` and
                    %% `{open,_}` members only, so a domain member would be
                    %% dropped rather than crash, and the generated validator
                    %% would walk nothing and answer `ok` for a value of any
                    %% shape.
                    %% The walk is deferred with the pattern form: both need a
                    %% decomposition over an unbounded key set.
                    case bs_types:is_dom(Ty) of
                        true  -> {reported(),
                                  D0 ++ [{error, L, C#ctx.fname,
                                          {validate_domain_map, Ty}}]};
                        false -> {validate_result(Ty, C#ctx.types), D0}
                    end
            end;
        _ ->
            {reported(),
             D0 ++ [{error, L, C#ctx.fname,
                     {obligation_arity, 'ValidateAs', length(TypeArgs),
                      length(Args)}}]}
    end;
%% Any other instantiation is refused, and the two cases are told apart: a
%% name in the closed set is a feature not yet built, a name outside it was
%% never going to work (ticket 28).
type_of({e_inst, L, Name, _TypeArgs, Args}, S, C) ->
    {_, D0} = type_of_all(Args, S, C),
    Reason = case lists:member(Name, codegen_obligations()) of
                 true  -> {obligation_unbuilt, Name};
                 false -> {not_an_obligation, Name}
             end,
    {reported(), D0 ++ [{error, L, C#ctx.fname, Reason}]};
type_of({e_call, L, Name, Args}, S, C) ->
    call(L, unqualified_key(Name, length(Args), L, C), Name, Args, S, C);
%% A foreign call is checked as site 1 verbatim: a foreign declaration is a
%% signature attached to the name Erlang already has (ticket 32).
type_of({e_foreign_call, L, Mod, Fun, Args}, S, C) ->
    call(L, {f, Mod, Fun, length(Args)}, foreign_name(Mod, Fun), Args, S, C);
%% A qualified call resolves its module through the namespace table first, so
%% `using Shop` + `Orders.Sum(o)` and `using Shop.Orders` +
%% `Shop.Orders.Sum(o)` reach the same callee by different
%% spellings (ticket 41 §1).
type_of({e_qcall, L, Mod0, Fun, Args}, S, C) ->
    %% The reserved fork comes before `qualified_module/3`, whose job is to
    %% resolve a name through the import tables, and a reserved qualifier is
    %% in none of them by construction. Falling through produced "List is
    %% called but never imported", advice no author can act on (ticket 67).
    case lists:member(Mod0, reserved_qualifiers()) of
        true  -> reserved_call(L, Mod0, Fun, Args, S, C);
        false ->
            Mod = qualified_module(Mod0, L, C),
            call(L, {q, Mod, Fun, length(Args)}, qualified_name(Mod, Fun),
                 Args, S, C)
    end;
type_of(_, _S, _C) ->
    {bs_types:term(), []}.

%% A call through a reserved qualifier that an imported namespace also
%% supplies is refused at the call site, not at the import (ticket 67 clause
%% 3, ticket 47). The import stands; what a file may not do is short-qualify
%% to the reserved word and expect either meaning to win silently.
%%
%% Only the namespace tier can shadow, and that falls out of the tables:
%% `add_namespace_import/3` populates `mods` and nothing else does, so
%% `using Shop.List` followed by an unqualified `Sum(…)` is untouched, and so
%% is any fully qualified call.
reserved_call(L, Q, Fun, Args, S, C) ->
    case maps:get(Q, maps:get(mods, C#ctx.imports, #{}), []) of
        [] -> reserved_op(L, Q, Fun, Args, S, C);
        Claimants ->
            %% The arguments are still walked: a diagnostic about the qualifier
            %% is no reason to withhold the ones about what was passed to it.
            {_ATys, D} = type_of_all(Args, S, C),
            {reported(),
             D ++ [{error, L, C#ctx.fname,
                    {reserved_qualifier_shadowed, Q, Fun, lists:sort(Claimants)}}]}
    end.

%% A reserved operation's arguments are checked by exactly the rule every
%% other call's are, through `arg_diags/7`, and the residual it produces is
%% the clause the caller must write.
reserved_op(L, Q, Fun, Args, S, C) ->
    {ATys, D} = type_of_all(Args, S, C),
    case reserved_sig(Q, Fun, length(Args), ATys) of
        error ->
            {reported(),
             D ++ [{error, L, C#ctx.fname,
                    {unknown_reserved_operation, Q, Fun, length(Args),
                     reserved_arities(Q, Fun)}}]};
        {ok, {Ps, Ret}} ->
            {Ret, arg_diags(L, qualified_name(Q, Fun), Args, ATys, Ps, 1, C) ++ D}
    end.

%% The type of an expression that has already produced a diagnostic. `none`
%% is a subtype of everything, so every site above it passes vacuously and
%% the author gets one error rather than a cascade; a failed projection would
%% otherwise also fail the clause's return check and name a type nobody
%% wrote.
reported() -> bs_types:none().

%% `ValidateAs<T>` returns `result<T, ValidationError>`, not
%% `T | :error` (F18, ticket 15 §2). Built from the prelude's own entry
%% rather than from a literal written here, so the two cannot drift.
validate_result(Ty, Env) ->
    bs_types:union(Ty, validate_error(Env)).

%% The failure member `ValidateAs<T>` adds, on its own, so the obligation
%% site can hand it to the shared predicate `absorbed/2` (F31).
validate_error(Env) ->
    bs_types:tuple([bs_types:atom_lit(error),
                    maps:get('ValidationError', Env)]).

%% An instantiation is rejected when `T | <failure member> ≡ T`, stated as
%% the equation rather than as a case list so that it covers every collapsing
%% type with one criterion (ticket 15 §1). Measured in this algebra:
%% `atom | (:error, ValidationError)` does not collapse, the tagged member
%% survives, and `term` is the only instantiation that does, because only the
%% top absorbs a tuple. `term` is also vacuous on its own terms: the validator
%% could never fail, so the caller would have no failure clause to write.
validate_collapses(Ty, Env) ->
    absorbed(validate_error(Env), Ty).

%% `T | F ≡ T` holds exactly when `F ⊆ T`: a union is always a supertype of
%% its members, so the other direction cannot fail (ticket 15 §1). This is
%% the one implementation of that equation; `validate_collapses/2` and the
%% declaration check (F31) both ask it here so the two cannot drift.
absorbed(Failure, Success) -> bs_types:is_subtype(Failure, Success).

type_of_all(Es, S, C) ->
    {Tys, Ds} = lists:unzip([type_of(E, S, C) || E <- Es]),
    {Tys, lists:append(Ds)}.

%% Shared by the switch an author wrote and the one the valve lowers to. The
%% subject's type is passed in rather than synthesised here, because the
%% valve has to interrogate it before deciding whether to walk the arms.
switch_over(L, SubjTy, Arms, S, C, Origin) ->
    %% `SubjTy` twice: the first is the running residual, which the fold
    %% spends; the second is the declared subject, carried unchanged so that
    %% arm 1 can still be asked the one question the residual can no longer
    %% answer, in `redundancy/4` (ENG-269).
    {Tys, Residual, D1} = arms(Arms, SubjTy, SubjTy, S, C, 1, [], [], Origin),
    D2 = case bs_types:is_none(Residual) of
             true  -> [];
             %% The residual is the missing arm (ticket 04), and it needs no
             %% new printer: `to_pattern/1` already renders a tuple as
             %% `(a, b, c)` and a record union as its discriminator.
             false -> [{error, L, C#ctx.fname, {switch_inexhaustive, Residual}}]
         end,
    {union_of(Tys), D1 ++ D2}.

%% One arm at a time against a running residual, `walk/5`'s shape: redundancy
%% is relative, arm i against the arms before it, so it is judged against
%% what is left rather than against the subject.
%%
%% `Origin` gates the two diagnostics that are remarks about an arm rather
%% than about what it contains. Both are advice to an author about a pattern
%% they chose, and the valve's two arms were chosen by `bs_lower`. The body's
%% and guard's diagnostics and the exhaustiveness of the whole run either way.
arms([], Residual, _Declared, _S, _C, _N, Tys, Diags, _Origin) ->
    {Tys, Residual, Diags};
arms([{arm, AL, P, Guard, Body} | Rest], Residual, Declared, S, C, N, Tys, Diags, Origin) ->
    {PTy, Binds, Exact} = pattern_type(P, [], C#ctx.types),
    {Certain0, Possible} = apply_guard(PTy, Binds, Guard),
    %% An inexact pattern over-states what it matches, so it may bound Possible
    %% and must credit nothing to Certain, as in `clause_type/2`: crediting an
    %% over-estimate is what makes a compiler claim coverage it does not have.
    Certain = case Exact of true -> Certain0; false -> bs_types:none() end,
    D1 = case Origin of
             generated -> [];
             authored ->
                 %% An arm that adds nothing is reported by which of three
                 %% faults it has: an earlier arm already covers it, its
                 %% pattern is not a member of the subject's type at all, or
                 %% its guard admits no value (ENG-269). Only the first is
                 %% "matched by an earlier arm"; before the split the first
                 %% arm of a switch was reported that way, naming an arm that
                 %% does not exist. `redundancy/4` is `walk/6`'s, reused, and
                 %% `PTy` is the pattern's own type before `apply_guard`
                 %% reduced it, which is what tells the first two apart.
                 case map_arm_deferred(P, Declared) of
                     %% A deferred map pattern is an error ahead of
                     %% `redundancy/4`, not a vacuous-arm warning: the arm is
                     %% vacuous only because this compiler cannot honour the
                     %% pattern, and a warning let the switch compile with a
                     %% dead arm and answer from `_` instead.
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
                 %% A `_` arm over `Disposition` is the same defect as a `_`
                 %% clause over it: an arm is the clause head's pattern grammar
                 %% one level down, so a rule about what a head may discard is
                 %% a rule about what an arm may discard (ticket 12 §2, F7).
                 ++ catch_all_diags({clause, AL, C#ctx.fname, [P], Guard, ignored},
                                    Residual, AL, C#ctx.fname,
                                    record_names(C#ctx.types))
         end,
    %% The body is typed against `Possible`, never `Certain` (F5.7). `Certain`
    %% is `none` under an untranslatable guard, and every containment over
    %% `none` passes, so the arm would silently stop being checked.
    Domain = bs_types:intersect(Residual, Possible),
    %% An arm variable's type is read off the refined domain at the path the
    %% pattern recorded, exactly as a clause's is; the paths start at `[]`
    %% here because a switch has one subject where a clause head has a product.
    Scope = maps:merge(S, maps:from_list(
                            [{V, at_path(Domain, Path)}
                             || {V, Path} <- maps:to_list(Binds)])),
    {BodyTy, D2} = type_of(Body, Scope, C),
    arms(Rest, bs_types:subtract(Residual, Certain), Declared, S, C, N + 1,
         Tys ++ [BodyTy], Diags ++ D1 ++ guard_diags(Guard, C) ++ D2, Origin).

op_type('+') -> bs_types:int();
op_type('-') -> bs_types:int();
op_type('*') -> bs_types:int();
%% `7 / 2` is `int`, not an exact interval, for the same reason
%% `1 + 2` is (F26, ticket 38).
op_type('/') -> bs_types:int();
op_type('%') -> bs_types:int();
op_type(_)   -> bs_types:union(bs_types:atom_lit(true), bs_types:atom_lit(false)).

%% A divisor the checker can prove is zero is refused; a divisor needs no
%% proof it is non-zero, so `Mean(total, count) -> total / count` compiles and
%% a zero at run time crashes (F26, ticket 38 §2, ticket 12). The test is
%% `is_subtype(Divisor, range(0,0))`, subtype rather than equality so that a
%% divisor narrowed to nothing but zero by a refinement or a pinned head is
%% caught too, and `int` can never fire. `erlc` constant-folds only when both
%% operands are literals, so `variable(X) -> X div 0` warns nowhere there.
divisor_diags(Op, BTy, L, C) when Op =:= '/'; Op =:= '%' ->
    case bs_types:is_subtype(BTy, bs_types:range(0, 0)) of
        true  -> [{error, L, C#ctx.fname, {divide_by_zero, Op}}];
        false -> []
    end;
divisor_diags(_, _, _, _) -> [].

%% A binding declares no type, so it is synthesis only; there is no site here.
bind_step({bind, _, V, E}, {S, D}, C) ->
    {T, D1} = type_of(E, S, C),
    {S#{V => T}, D ++ D1};
%% Site 5, the destructuring bind: it must be provably irrefutable, which
%% holds exactly when the residual is empty (tickets 33, 34).
bind_step({dbind, L, P, E}, {S, D}, C) ->
    %% A relational pattern is refused in a bind. `var >= 4 = n` parses,
    %% since a bind takes a pattern and a relational is one, but it binds
    %% nothing and is the refutable construct par excellence. Refused here
    %% rather than left to the residual check because the degenerate
    %% irrefutable case, `var >= 0 = n` over an `Octet`, would pass that check
    %% and reach the emitter, which has no guard to hang the test on.
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
             %% An inexact pattern over-states what it matches, so its residual
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
has_rel({p_rec, _, _, Fs})       -> lists:any(fun({_, P}) -> has_rel(P) end, Fs);
has_rel({p_bind, _, _, P})       -> has_rel(P);
has_rel({p_list, _, Items, Rest}) ->
    lists:any(fun has_rel/1, Items)
        orelse (Rest =/= nil andalso has_rel(Rest));
has_rel(_)                       -> false.

%% Site 1, the call argument: each argument must be contained in the declared
%% parameter type, so `Update(Order o)` called with an `Invoice` is
%% rejected (ticket 26 §1).
call(L, Key, Shown, Args, S, C) ->
    {ATys, D} = type_of_all(Args, S, C),
    case maps:get(Key, C#ctx.callees, undefined) of
        undefined ->
            case private_callee(Key, length(Args), C) of
                {yes, M} ->
                    {reported(),
                     [{error, L, C#ctx.fname,
                       {private_function, M, Shown, length(Args)}} | D]};
                no -> unresolved(L, Key, Shown, Args, D, C)
            end;
        {Ps, Ret} when length(Ps) =/= length(ATys) ->
            {Ret, [{error, L, C#ctx.fname,
                    {arity_mismatch, Shown, length(ATys), length(Ps)}} | D]};
        {Ps, Ret} ->
            {Ret, arg_diags(L, Shown, Args, ATys, Ps, 1, C) ++ D}
    end.

%% A call to a function that exists and is private is reported as private,
%% and that is asked before the arity fork (F12): a private `F/2` beside a
%% public `F/1` would otherwise read as an arity mistake, sending the author
%% to change the call rather than the marker. A qualified call arrives keyed
%% `{q, M, N, A}`; an unqualified one never resolves at all, since a private
%% name cannot populate the import table, so the imported modules are asked
%% in turn.
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

%% A callee is unknown only when its name is unknown; when other arities of
%% the name exist, the diagnostic names them. Overloading is
%% permitted (ticket 40 §2), so `F/2` where only `F/1` exists is strictly an
%% unknown function, but reporting it that way throws away the fact that the
%% author plainly meant the `F` sitting right there (ticket 04).
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

%% Every arity declared for the callee the key names, whichever of the three
%% keyspaces it lives in: local, foreign, or another module's.
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
                %% The residual is the clause the caller must
                %% write (ticket 04). It proposes an edit to the function
                %% being checked and never to the callee (ticket 18 §4).
                false -> [{error, L, C#ctx.fname,
                           {arg_not_accepted, Callee, I, R, head_hint(A, C)}} | Rest]
            end
    end.

%% A head can only be synthesised when the argument is a whole parameter; an
%% arbitrary expression has no position in the caller's head to put a pattern
%% in. The record-name map rides along in the hint rather than as a sixth
%% element of the diagnostic, because `caller_head` is a paste site and needs
%% what every paste site needs (F29).
head_hint({e_var, _, V}, #ctx{binds = B, arity = N, types = Env}) ->
    case maps:get(V, B, undefined) of
        [I] when is_integer(I) -> {I, N, record_names(Env)};
        _                      -> none
    end;
head_hint(_, _) -> none.

foreign_name(Mod, Fun) ->
    list_to_atom(":" ++ atom_to_list(Mod) ++ "." ++ atom_to_list(Fun)).

%% An unqualified name resolves local first, then imports (ticket 41 §2). A
%% local wins outright: one of the two candidates is the author's own
%% declaration in the file they are reading, and a language whose local
%% definitions can be captured by a later import is the surprising one. A
%% local-versus-import clash used to be refused at the `using` line; that
%% check was deleted (ticket 47 Q2), so the clash reaches here and the local
%% answers it. Only two imports are ever ambiguous.
unqualified_key(Name, Arity, L, C) ->
    Key = {Name, Arity},
    case maps:is_key(Key, C#ctx.callees) of
        true  -> Key;
        false ->
            case maps:get(Key, maps:get(funs, C#ctx.imports, #{}), []) of
                []    -> Key;          %% unknown: `call/6` reports it
                [M]   -> {q, M, Name, Arity};
                %% Two imports with equal claim are an error, never a silent
                %% winner, and the candidates are printed qualified so the
                %% error hands over the fix (ticket 41 §2 requirement 1).
                Many  -> erlang:error({ambiguous_call, Name, Arity,
                                       lists:sort(Many), L})
            end
    end.

%% A qualified call names either a module or a namespace-relative short name,
%% and either way the module must appear in a `using` line: a file's `using`
%% lines are its dependency list, and a qualified call that skipped the list
%% would make that list a lie (ticket 41 §1, ticket 23 §11).
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

%% Site 2's residual is field names, not a type (ticket 33 §4). `Order{Id} \
%% Order` is `{ Kind: :'Shop.Order' }`: correct, and worthless, because it
%% names the type being built rather than the field forgotten.
field_delta(Supplied, Declared) ->
    {lists:sort(Declared -- Supplied), lists:sort(Supplied -- Declared)}.

%% The declared field set, read off the resolved type rather than the surface
%% one `record_fields/1` reads for the emitter. `Kind` is minted, never
%% assigned. A recursive record is unfolded before its parts are read, and
%% that clause comes first (F28): the catch-all answers `unknown`, which for a
%% recursive record would be a silent degrade, since its fields are known one
%% unfolding down. Unfolding terminates because a `mu` body is a partition.
declared_fields(#{mu := _} = T) -> declared_fields(bs_types:unfold(T));
declared_fields(#{maps := [{closed, Fs}]}) -> maps:keys(Fs) -- ['Kind'];
declared_fields(_)                         -> unknown.

field_type(#{mu := _} = T, Field) -> field_type(bs_types:unfold(T), Field);
field_type(#{maps := top}, _Field) -> bs_types:term();
field_type(#{maps := Members}, Field) ->
    union_of([maps:get(Field, Fs) || {_, Fs} <- Members, maps:is_key(Field, Fs)]).

%% Site 2's value half: one containment per field against the type the record
%% declaration wrote down, serving construction and `with` alike (ticket 36).
%% The residual is precise here, unlike the name half's: `:oops \ int` is
%% `:oops`, the value to remove, beside a field name already known because it
%% is the key assigned. A value whose own synthesis already failed is
%% `reported()`, which is `none()`, and `none \ T` is empty, so no cascading
%% second complaint can arise.
field_value_diags(Keys, Tys, RecTy, Name, L, C) ->
    [{error, L, C#ctx.fname, {field_value_not_accepted, Name, K, R}}
     || {K, VTy} <- lists:zip(Keys, Tys),
        R <- [bs_types:subtract(VTy, field_type(RecTy, K))],
        not bs_types:is_none(R)].

%% A `with` subject that is not one closed record must carry every updated
%% key in every member (ENG-249). Site 3's relation is asked per field:
%% `subject \ { K: term, .. }` is the part of the subject that may lack `K`,
%% handed back as the member to discriminate on. Per field rather than once
%% over all the keys, because on a union the residual is precise per field
%% (`Note` lacks `Total` and carries `Id`), and one subtraction over both
%% would name a member without saying which field it lacks.
%%
%% A base whose own synthesis already failed is `reported()`, which is
%% `none()`, and `none \ T` is empty, so it is stopped at the door rather
%% than passed into the value half against a type with no members. A refused
%% subject synthesises `reported()` too: `int with { … }` used to type as
%% `int`, so the `int` return type was satisfied and nothing else looked.
%%
%% Three verdicts per key, not two. `d with { Nope = 1 }` over
%% `Order | Invoice` is not a subject that may lack `Nope`; no member has it,
%% so it is the name defect, `not declared by Order`, reported per member as
%% the single-record path reports it (ticket 36).
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

%% One verdict per key. `carried`: every member has the key, so the value
%% half runs. `invented`: no member has it and every member is a named closed
%% record, so this is a name nobody declared rather than a member to
%% discriminate on; the record test keeps an `int` or a `term` out, since
%% neither has a declaration to be "not declared by". `absent`: some member
%% lacks it, or the subject is not a record at all, and the residual is what
%% lacks it.
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

%% A subject that is nothing but closed records, each wearing one tag. The
%% `false` arm is a classification, not a pass: it sends a key to the
%% `absent` refusal, so an unforeseen shape is refused with its residual
%% rather than accepted.
all_named_records(#{mu := _} = T) ->
    all_named_records(bs_types:unfold(T));
all_named_records(#{maps := Members} = T) when is_list(Members), Members =/= [] ->
    bs_types:is_none(bs_types:subtract(T, bs_types:map_open(#{})))
        andalso lists:all(fun(M) -> record_name(M) =/= unknown end,
                          member_types(Members));
all_named_records(_) ->
    false.

%% Nothing invented, nothing to say, and the members are not asked for, since
%% the subject may be an `int` or a `term` with no member list at all; the
%% first build lacked this clause and crashed on `term`.
invented_diags(_T, [], _L, _C) ->
    [];
invented_diags(T, Ks, L, C) ->
    [{error, L, C#ctx.fname,
      {field_set_mismatch, record_name(M), update, [], lists:sort(Ks)}}
     || M <- member_types(members_of(T))].

%% Site 3's relation, shared by projection and update (F21): the part of `Ty`
%% that may not carry `Field`. Empty when every member carries it; otherwise
%% the member to discriminate on.
lacking(Ty, Field) ->
    bs_types:subtract(Ty, bs_types:map_open(#{Field => bs_types:term()})).

%% Each member of a `with` subject is value-checked against its own
%% declaration: a value one record's `Total` accepts and another's rejects
%% would build the second record in breach of its own type, and the subject
%% may be either at run time. Reached only when every member carries every
%% key and the subject is not one closed named record: a union of records, or
%% a single member `declared_fields/1` does not read, such as the open map a
%% record pattern on a `term` parameter narrows to (F22).
member_value_diags(T, Keys, Tys, L, C) ->
    lists:append(
      [field_value_diags(Keys, Tys, MTy, member_label(MTy), L, C)
       || MTy <- member_types(members_of(T))]).

%% No catch-all. `maps := top` cannot reach here, since
%% `term \ { K: term, .. }` is never empty, and any other shape is a change in
%% `bs_types` this clause should refuse to guess about.
members_of(#{mu := _} = T)                          -> members_of(bs_types:unfold(T));
members_of(#{maps := Members}) when is_list(Members) -> Members.

%% One member of a union of maps, as a type of its own, so `record_name/1` and
%% `field_type/2` can be asked of it. `Openness` is `closed | open`, not the
%% minted `'Kind'` field, which lives inside `Fs`.
member_types(Members) ->
    [(bs_types:none())#{maps => [{Openness, Fs}]} || {Openness, Fs} <- Members].

%% The name the value diagnostic prints. A member wearing one tag is named by
%% it, as every other site names a record. A member without one, a map with
%% no `Kind`, is named by its printed shape rather than dropped: a verdict
%% with an odd name beats a value that goes unchecked for want of one.
member_label(MTy) ->
    case record_name(MTy) of
        unknown -> lists:flatten(bs_types:to_pattern(MTy));
        Name    -> Name
    end.

%% The record names a head hint may use, keyed by minted tag, built from the
%% environment this site actually has (F29.4). The head printer wants
%% `Order o` where `{ Kind: :'M.Order' }` is what it holds, and the segment
%% after the last dot is a name whether or not it is in scope; deriving one
%% from the tag could suggest a head naming a type the file cannot see. A tag
%% missing from the map keeps the discriminator (ticket 26 §1). An alias
%% drops out on its own: `type Doc = Order | Invoice` resolves to a union
%% whose `Kind` carries two atoms, so it never matches the single-tag shape,
%% and a name is recorded exactly when `Name x` is a pattern that matches it.
record_names(Env) ->
    maps:from_list(
      [{Tag, atom_to_list(Name)}
       || Name <- maps:keys(Env),
          Tag <- [minted_tag(Name, Env)],
          Tag =/= undefined]).

%% Resolution is attempted rather than assumed: an environment entry may be
%% parametric, cyclic or unknown, and every one of those raises out of
%% `resolve/2`. A name that cannot be resolved simply is not offered as a head.
minted_tag(Name, Env) ->
    try resolve({t_ref, Name}, Env) of
        Ty ->
            case field_type(Ty, 'Kind') of
                #{atoms := {finite, [Tag]}, ints := [], tuples := [],
                  lists := [], maps := [], bins := []} -> Tag;
                _ -> undefined
            end
    catch
        _:_ -> undefined
    end.

%% The record's declared name, read back off the minted tag: the tag is
%% minted from the qualified name, so the declared name is the segment after
%% the last dot (ticket 26 §1). `with` has only the base's type and needs a
%% name for the same diagnostic construction gets from the surface. A union
%% of records has no single name and answers `unknown`, as
%% `declared_fields/1` does.
record_name(Ty) ->
    case field_type(Ty, 'Kind') of
        #{atoms := {finite, [Tag]}} ->
            list_to_atom(lists:last(string:split(atom_to_list(Tag), ".", all)));
        _ ->
            unknown
    end.

%% A clause that destructures a parameter whose type is a domain map gets one
%% diagnostic (ticket 48 Q2). Paired by position rather than by scanning the
%% clause for any map pattern: a clause may destructure a record in column 1
%% while column 2 is a `map<K, V>` it only binds, and that program ships.
map_pattern_diags(Clauses, Params, Env, Name) ->
    Doms = [I || {I, {param, T, _}} <- lists:enumerate(Params),
                 bs_types:is_dom(resolve(T, Env))],
    [{error, CLine, Name, {map_pattern_deferred, head, resolve(ParamT, Env)}}
     || {clause, CLine, _, Patterns, _, _} <- Clauses,
        I <- Doms,
        length(Patterns) >= I,
        destructures_map(lists:nth(I, Patterns)),
        {param, ParamT, _} <- [lists:nth(I, Params)]].

%% Whether a pattern takes a map apart. `{ Status: s }` is a `p_map` directly
%% and `{ Status: s } whole` is one under a `p_bind`, since naming the type
%% and binding the value are independent (ticket 55). `Order o`, a `p_rec`
%% under a `p_bind`, is deliberately not here: a record carries a minted
%% `Kind`, so "not a member of it" is a true sentence about a record against
%% a `map<K, V>` (ticket 48 Q3). This refusal exists to stop the compiler
%% stating a falsehood, so it must not fire where the ordinary message is
%% true.
destructures_map({p_map, _, _})       -> true;
destructures_map({p_bind, _, _, Ptn}) -> destructures_map(Ptn);
destructures_map(_)                   -> false.

%% A switch arm that destructures a domain-map subject is refused too, at its
%% own site (ticket 48 Q2): an arm is classified in the arm walk, which the
%% clause-head check never reaches, and a vacuous arm is only a warning, so
%% `a switch { { Status: s } => s, _ => 0 }` over a `map<K, V>` compiled with
%% exit 0 and emitted a beam whose first arm is dead.
map_arm_deferred(P, Subject) ->
    bs_types:is_dom(Subject) andalso destructures_map(P).

walk([], Residual, _Declared, _Ctx, Diags, _N) ->
    {Residual, lists:reverse(Diags)};
walk([C = {clause, CLine, Name, _, _, _} | Rest], Residual, Declared, Ctx, Diags, N) ->
    Env = Ctx#ctx.types,
    %% Two bounds, and conflating them is a soundness bug. `Certain` is what
    %% the clause is guaranteed to match and is the only thing that may be
    %% subtracted from the residual; an over-estimate there makes the compiler
    %% claim coverage it does not have. `Possible` is what the clause could
    %% match and is what redundancy is judged against; an under-estimate there
    %% would call a live clause dead. They differ exactly when a guard is not
    %% translatable to a type operation.
    {Certain, Possible, Bindings, Base} = clause_type(C, Env),
    %% Redundancy is relative, clause i against the clauses before it, so it
    %% is checked against the running residual rather than the declared
    %% type (ticket 04). A clause that adds nothing is reported by which of
    %% three faults it has: an earlier clause already covers it, its pattern
    %% is not a member of the declared input at all, or its guard admits no
    %% value (ENG-259). Only the first is "matched by an earlier clause";
    %% before the split a sole clause was reported that way, naming a clause
    %% that does not exist. `Declared` is threaded because the residual is the
    %% declared type by the time clause 1 is judged and cannot tell the faults
    %% apart.
    Diags1 =
        case redundancy(Base, Possible, Residual, Declared) of
            vacuous    -> [{warning, CLine, Name, {vacuous_clause, N, Declared}} | Diags];
            dead_guard -> [{warning, CLine, Name, {unsatisfiable_guard, N}} | Diags];
            shadowed   -> [{warning, CLine, Name, {unreachable_clause, N}} | Diags];
            live       -> Diags
        end,
    %% A catch-all is legal only over an open residual (ticket 12 §2). Once
    %% `type Octet = int where value >= 0 and value <= 255` exists, a wire
    %% dispatch naming four frame types has 252 unnamed octets left and the
    %% compiler knows their names; `_` there makes the function unfalsifiable
    %% when a fifth frame type is added, and the residual is the checklist of
    %% what to write. Refinements and the span pattern land together (F2) so
    %% that a refinement never turns a working program into a rejected one
    %% with nothing to answer the compiler in.
    Diags2 = catch_all_diags(C, Residual, CLine, Name, record_names(Env)) ++ Diags1,
    %% The body is checked against the running residual intersected with
    %% `Possible`, never `Certain` (ticket 33): an untranslatable guard makes
    %% `Certain` `none`, and every containment over `none` passes, so the check
    %% would silently stop checking.
    Domain = bs_types:intersect(Residual, Possible),
    Diags3 = clause_diags(C, Domain, Bindings, Ctx) ++ Diags2,
    walk(Rest, bs_types:subtract(Residual, Certain), Declared, Ctx, Diags3, N + 1).

%% A clause or arm that adds nothing is classified by the first of three
%% faults it has, in this order, so the order is reviewable in one
%% place (ENG-259, ENG-269). The question a switch arm asks is the question
%% a clause head asks; only the arguments differ, a product of parameters
%% against the subject alone.
%%
%% `Base` is the pattern's own type before the guard reduces it. Asking the
%% second question with `Possible` would defeat the split: an unsatisfiable
%% guard collapses `Possible` to `none`, indistinguishable from a pattern
%% that was never in the domain.
%%
%% A guard the checker cannot read is not a fault and never reaches
%% `dead_guard`: `apply_guard/3` answers `{none(), Ty}` for one, so
%% `GuardAdmits` stays true and the clause is judged on its pattern alone.
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

%% A catch-all is a clause of only `_` patterns with no guard, and it is an
%% error over a closed, inhabited residual: "`_` here is an error: name the
%% case" (ticket 12 §2). `_` and not a bare name, because `_` discards the
%% value while a binder keeps it, and projecting a field off a binder is site
%% 3, refused until the value is discriminated; extending the rule to binders
%% would also make every single-clause function over a record an error. A
%% guard means the clause says something about the values, so it is not a
%% catch-all whether or not the checker can read the guard. Measured before
%% landing: the compiling corpus had zero all-wildcard clauses.
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

%%% ---------------------------------------------------------------------------
%%% What a clause matches
%%% ---------------------------------------------------------------------------

%% Returns {Certain, Possible, Bindings, Base}; see walk/5 for why both
%% bounds are needed. The bindings come back out because the body check reads
%% each variable's type off the domain at the path recorded here, rather than
%% off its pattern: a bare `p_var` is `term`, and typing a body from its
%% patterns fails every call site in the corpus (ticket 33 §5).
clause_type({clause, _, _, Patterns, Guard, _}, Env) ->
    {Components, Bindings, Exact} = pattern_row(Patterns, Env),
    Base = bs_types:tuple(Components),
    {Certain, Possible} = apply_guard(Base, Bindings, Guard),
    %% `Base` is the pattern's type before the guard touched it, which
    %% `redundancy/4` needs (ENG-259). It is the pattern alone, so `Exact`,
    %% a statement about what may be credited, does not affect it.
    case Exact of
        true  -> {Certain, Possible, Bindings, Base};
        %% An inexact pattern over-states what it matches (`[0, ..t]` is not
        %% every non-empty list), so it may bound Possible but must credit
        %% nothing to Certain, as with an untranslatable guard: crediting an
        %% over-estimate is what makes a compiler claim coverage it lacks.
        false -> {bs_types:none(), Possible, Bindings, Base}
    end.

pattern_row(Patterns, Env) ->
    Triples = [pattern_type(P, [I], Env)
               || {P, I} <- lists:zip(Patterns, lists:seq(1, length(Patterns)))],
    Tys   = [T || {T, _, _} <- Triples],
    Binds = [B || {_, B, _} <- Triples],
    Exact = lists:all(fun({_, _, E}) -> E end, Triples),
    {Tys, lists:foldl(fun maps:merge/2, #{}, Binds), Exact}.

%% A pattern yields the set of values it matches, plus where each variable
%% sits, so a guard can refine that position afterwards. Returns {Type,
%% Bindings, Exact}; `Exact` is whether the type is exactly what the pattern
%% matches rather than an upper bound (see clause_type/2).
pattern_type({p_int, _, N}, _Path, _Env)  -> {bs_types:range(N, N), #{}, true};
pattern_type({p_atom, _, A}, _Path, _Env) -> {bs_types:atom_lit(A), #{}, true};
pattern_type({p_wild, _}, _Path, _Env)    -> {bs_types:term(), #{}, true};
pattern_type({p_var, _, V}, Path, _Env)   -> {bs_types:term(), #{V => Path}, true};
%% A matched name is inexact and credits nothing to `Certain` (F8.6). `== acc`
%% is a value test whose value the compiler does not know, so it is an upper
%% bound on what the clause matches, as `[0, ..t]` is; crediting `Certain`
%% would claim coverage the clause does not have, and the wrong build gets
%% quieter, not louder. It binds nothing, which is the distinction the token
%% marks, and answers `term()` because `walk/5` intersects `Possible` with the
%% residual from the declared domain, so a body reads the declared type at
%% this position anyway (F8.7).
pattern_type({p_eqvar, _, _V}, _Path, _Env) -> {bs_types:term(), #{}, false};
%% A relational pattern is exact: `>= 4` matches precisely the integers from 4
%% up, a set the algebra holds, so it credits `Certain` in full and can close
%% a residual (ticket 42). It binds nothing; a clause needing the number
%% writes `Classify(n) when n >= 4` as it always could.
pattern_type({p_rel, Line, Op, K}, Path, _Env) ->
    argument_position(Line, Path),
    {rel_type(Op, K), #{}, true};
%% `and` is intersection and `or` is union (F2). Both sides carry the same
%% path, because a combinator constrains one value twice rather than
%% describing two positions.
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
%% A property pattern is open: it constrains the fields it names and nothing
%% else, which lets `Which({ Kind: :'Shop.Order' })` cover a whole record in
%% one clause. It is exact, matching precisely the maps whose named fields lie
%% in those types, so it credits `Certain` in full. The corpus writes that
%% clause as `Which(Order o)` (ticket 55), which `p_rec` below resolves to the
%% same open map with the tag minted rather than written.
%%
%% Field paths are real rather than `no_path`: `refine_all/3` turns an unknown
%% path into `none_marker`, so a clause with both a record pattern and a guard
%% would credit nothing and the function would report inexhaustive.
pattern_type({p_map, _, Fields}, Path, Env) ->
    Triples = [{K, pattern_type(P, Path ++ [{field, K}], Env)} || {K, P} <- Fields],
    {bs_types:map_open(maps:from_list([{K, T} || {K, {T, _, _}} <- Triples])),
     lists:foldl(fun maps:merge/2, #{}, [B || {_, {_, B, _}} <- Triples]),
     lists:all(fun({_, {_, _, E}}) -> E end, Triples)};
%% A record pattern that names its type is the property pattern with one
%% field filled in by the compiler (F22, ticket 55). `Frame { Type: :method }`
%% produces exactly the `map_open` that `{ Kind: :'Wire.Frame', Type:
%% :method }` produces, so it subtracts exactly as much. Subtracting too
%% little is loud, a covered union reports inexhaustive; subtracting too much
%% is silent, the compiler proves a program exhaustive and the BEAM crashes
%% it (ticket 54), so `check-record-pattern.sh` asserts the two spellings
%% agree. The tag comes from `record_of/3`, which resolves through
%% `resolve/2` and so through the single minting point.
pattern_type({p_rec, Line, Name, Fields}, Path, Env) ->
    {Tag, Declared} = record_of(Name, Line, Env),
    %% A field the record does not declare is refused before the fields are
    %% typed, so a typo reports as a typo. Otherwise the pattern would
    %% intersect to `none`, the clause would match nothing, and the function
    %% would report inexhaustive, a true statement that says nothing about
    %% the mistake made.
    [case lists:member(K, Declared) of
         true  -> ok;
         false -> erlang:error({pattern_field_unknown, Line, Name, K, Declared})
     end || {K, _} <- Fields],
    Triples = [{K, pattern_type(P, Path ++ [{field, K}], Env)} || {K, P} <- Fields],
    Named = maps:from_list([{K, T} || {K, {T, _, _}} <- Triples]),
    {bs_types:map_open(Named#{'Kind' => bs_types:atom_lit(Tag)}),
     lists:foldl(fun maps:merge/2, #{}, [B || {_, {_, B, _}} <- Triples]),
     lists:all(fun({_, {_, _, E}}) -> E end, Triples)};
%% A trailing binder takes the same path as the pattern it wraps (F22, ticket
%% 55): it names the position already being described, which is what lets a
%% guard refine through it and a body read `f.Channel` at the declared type
%% rather than `term`. It contributes nothing to exactness; `Frame f` is exact
%% where `Frame { … }` is and `<<t:8, r>> f` is inexact where the binary is.
pattern_type({p_bind, _, V, P}, Path, Env) ->
    {T, B, E} = pattern_type(P, Path, Env),
    {T, B#{V => Path}, E};
%% A binary pattern is `binary` and nothing narrower, held
%% inexactly (F13, ticket 30). A binary gets no structure in the type
%% language; the only new fact a segment produces lives in the integer part.
%% `<<t:8, rest>>` matches only the binaries long enough to hold it, and a
%% binary can always be truncated, so it is an upper bound and credits
%% nothing to `Certain`. Hence a `_` clause beside it is always required and
%% always legal, never `catch_all_over_closed`, because a binary's residual
%% has an unbounded top in it. That catch-all also swallows every wire value
%% the author forgot: the pattern does shape, a function head does value.
pattern_type({p_bin, _, Segs}, _Path, _Env) ->
    {bs_types:binary_top(), seg_bindings(Segs), false};
%% A string literal pattern is `string` held inexactly (ticket 30 §4): the
%% algebra has no singletons in its binary part, and the lexer has already
%% proved the literal valid UTF-8. So a set of string literals is never
%% exhaustive on its own, and a catch-all beside them is required and legal.
pattern_type({p_str, _, _Bytes}, _Path, _Env) -> {bs_types:string(), #{}, false};
pattern_type({p_nil, _}, _Path, _Env) -> {bs_types:nil(), #{}, true};
%% A list pattern is a product and is subtracted as one (F20, ticket 54).
%% Each written position contributes its own type, as `p_tuple` does, and
%% `Rest = nil` means the pattern is closed. Crediting `cons(term())` for any
%% prefix proved `[]` beside `[a, b, ..]` exhaustive and crashed on `[7]`.
%% Exactness is per position: `[a, b, ..]` is exact because both positions
%% are irrefutable, and `[0, ..]` is not, because the literal makes it an
%% upper bound.
pattern_type({p_list, _, Items, Rest}, Path, Env) ->
    %% The element path is `{elem}` for every position rather than one per
    %% index: `opaque_step({elem})` is already true, so a guard over a list
    %% element credits nothing whichever position it names, and indexing
    %% would invite a refinement to leak between positions.
    Triples = [pattern_type(P, Path ++ [{elem}], Env) || P <- Items],
    Prefix = [T || {T, _, _} <- Triples],
    Openness = case Rest of nil -> closed; _ -> open end,
    Binds0 = lists:foldl(fun maps:merge/2, #{}, [B || {_, B, _} <- Triples]),
    Binds = case Rest of
                nil -> Binds0;
                R   -> maps:merge(Binds0, binding(R, Path ++ [{tail}]))
            end,
    Exact = lists:all(fun({_, _, E}) -> E end, Triples),
    {bs_types:spine(Prefix, Openness), Binds, Exact}.

%%% --- What a binary segment binds (F13) -------------------------------------

%% A segment's width refines the value it binds: `t:8` binds an integer known
%% to be 0..255, and the interval algebra computes the residual from
%% there (ticket 30, F2). The address is `{seg, Type}` rather than an index
%% into the domain, because a binary has no components to read at the far
%% end; the width is knowledge the pattern carries, so the path step carries
%% it too.
%% Unsigned, big-endian, the BEAM's own default for a segment with no
%% qualifiers, so `range(0, 2^N - 1)` is what the emitted match produces.
seg_bindings(Segs) ->
    maps:from_list([{V, [{seg, seg_type(Size)}]} || {seg_bind, _, V, Size} <- Segs]).

seg_type({width, N}) when is_integer(N), N > 0 -> bs_types:range(0, (1 bsl N) - 1);
%% A width the checker refuses anyway (`segment_width_not_positive`). Answering
%% `int` keeps this total so the diagnostic below is what the author meets,
%% rather than a function_clause from inside the checker.
seg_type({width, _})    -> bs_types:int();
%% Sized by an earlier binding, or the remainder: a `binary` either way, with
%% the length erased. The dependent step is refused deliberately, as every
%% language in the survey refuses it; Gleam permits the segment and erases at
%% the binding, which is exactly this (ticket 30 §1).
seg_type({sized_by, _}) -> bs_types:binary_top();
seg_type(rest)          -> bs_types:binary_top().

rel_combine(Op, A, B, Path, Env) ->
    {TA, BA, EA} = pattern_type(A, Path, Env),
    {TB, BB, EB} = pattern_type(B, Path, Env),
    {Op(TA, TB), maps:merge(BA, BB), EA andalso EB}.

%% The four relational operators, and they agree with `int_cmp/3` below by
%% construction: the same four intervals, because a relational pattern and
%% the guard it replaces have to mean the same thing. `==` is absent, since
%% in a pattern it means "the value this name holds" (ticket 45).
rel_type('>=', K) -> bs_types:range(K, pos_inf);
rel_type('>',  K) -> bs_types:range(K + 1, pos_inf);
rel_type('<=', K) -> bs_types:range(neg_inf, K);
rel_type('<',  K) -> bs_types:range(neg_inf, K - 1).

%% A relational pattern is legal only as a whole clause-head parameter or a
%% whole switch subject, never nested (F2). The grammar admits one inside a
%% field or a tuple and the algebra would handle it, but shipping a capability
%% nothing tests because a production happened to compose is how a language
%% acquires behaviour nobody decided on; no exemplar needs it (ticket 42). A
%% clause-head parameter is `[I]` and a switch subject is `[]`; anything
%% longer, or carrying a field or list step, is inside something.
argument_position(_Line, [])                     -> ok;
argument_position(_Line, [I]) when is_integer(I) -> ok;
argument_position(Line, _Path) ->
    erlang:error({relational_pattern_nested, Line}).

%% A list element's address is a real path, so the body check can read `rest`
%% out of `Reverse([x, ..rest], acc)` as `list<int>` rather than `term` (F5).
%% A guard over one is still not refinable: `refine_all/3` rejects any path
%% carrying a list step, because the list part of the algebra supports
%% reading a component and not refining one.
binding({p_var, _, V}, Path) -> #{V => Path};
binding(_, _)                -> #{}.

%% A path step a guard cannot refine through, as opposed to one a body cannot
%% read; `at_path/2` reads every step here. A guard over a segment binding,
%% `Decode(<<… len:7, …>>) when len < 126`, credits nothing, which costs
%% nothing in practice because a binary pattern is already inexact (F13).
%% Refining it would mean addressing a position inside a binary, structure
%% the type language does not have (ticket 30).
opaque_step({elem})    -> true;
opaque_step({tail})    -> true;
opaque_step({seg, _})  -> true;
opaque_step(_)         -> false.

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
            %% A guard the checker cannot read credits nothing: the clause
            %% contributes nothing to the residual, not its whole pattern,
            %% because such a guard might always fail (ticket 08). Getting
            %% this backwards let `F(n) when Weird(n)` report as exhaustive.
            {bs_types:none(), Ty};
        Alts ->
            Results = [refine_all(Ty, Bindings, A) || A <- Alts],
            case lists:member(none_marker, Results) of
                true  -> {bs_types:none(), Ty};
                false -> Refined = bs_types:union(Results), {Refined, Refined}
            end
    end.

%% [] means "no constraint"; unknown means "not translatable". The operator
%% atoms are `and` and `or`, the spelling the AST carries (ticket 44, F2).
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
        %% A conjunction of two alternative-sets is their pairwise
        %% concatenation.
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
                      %% A path through an opaque step is unrefinable, as
                      %% `no_path` was: `refine_at/3` cannot address one, so
                      %% readable paths change nothing a guard credits (F5).
                      case lists:any(fun opaque_step/1, Path) of
                          true  -> none_marker;
                          false -> refine_at(Acc, Path, C)
                      end
              end;
         (unknown, Acc) -> Acc
      end, Ty, Constraints).

%% An empty path refines the whole value, which is what a switch arm does: a
%% clause-head path always begins with a parameter index, so
%% `n switch { m when m > 0 => … }` is the only thing that asks for this, and
%% without the clause it left the checker through a `function_clause`.
refine_at(Ty, [], C) ->
    apply_constraint(Ty, C);
%% Descend into a record field. The map part of a pattern's type is always a
%% list of members, since `top` only arises from `term`, which no pattern
%% produces at this position; the `top` clause is unreachable and is written
%% so that a future `top` under-credits instead of silently over-crediting.
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
