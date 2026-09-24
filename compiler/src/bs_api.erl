%%% bs_api — `bsc --api <Module>`: what operations a module offers, in
%%% beam-sharp's own types, with nothing built.
%%%
%%% Types resolve from declarations alone (`bsc:type_world/2`, then
%%% `bs_check:exports_of/2`); nothing is compiled. The answer prints resolved
%%% types, never a type's name. A module is refused when a declaration is
%%% untrue, not when a body is inexhaustive.
%%% Rationale: compiler/features/F17-compiler-query-mode.md.
-module(bs_api).

-export([answer/3]).

%%% ---------------------------------------------------------------------------
%%% The entry point
%%%
%%% Reached from `bsc:main/1` only. It ends in `exit_with/1` like every other
%%% CLI mode, so every test for this feature drives the built escript.
%%% ---------------------------------------------------------------------------

%% A namespace named on the command line arrives with empty paths, because
%% `bsc:is_path_arg/1` counts a directory as a path only if it is a module. It
%% gets the precise refusal rather than the general one below.
answer([], [A | _], _Root) ->
    case filelib:is_dir(A) andalso bsc:dir_kind(A) =:= namespace of
        true  -> refuse_namespace(A);
        false -> refuse_not_a_module(A)
    end;
answer(_Paths, [A | _], _Root) ->
    io:format(standard_error,
              "bsc: --api answers about a module, it does not run one~n"
              "  drop `~s`. The query reads source and reports what the module~n"
              "  offers, with nothing built and nothing called.~n", [A]),
    bsc:exit_with(2);
answer([], [], _Root) ->
    io:format(standard_error,
              "bsc: --api needs a module~n"
              "      bsc --api examples/Counter~n"
              "      bsc --src-root examples --api examples/Shop/Reports~n", []),
    bsc:exit_with(2);
answer(Paths, [], Root) ->
    %% A path that does not exist is refused here. A `.bs` suffix makes an
    %% argument a path whether or not the file exists, and `module_dir_of/1`
    %% would then answer about its directory, which may be a real module nobody
    %% named.
    case [P || P <- Paths, not filelib:is_file(P)] of
        [Missing | _] -> refuse_not_a_module(Missing);
        [] ->
            %% Naming a file names its module, and `bsc:module_dir_of/1` is
            %% that rule's one implementation.
            Dirs = lists:usort([bsc:module_dir_of(P) || P <- Paths]),
            lists:foreach(fun(D) -> module(D, Root) end, Dirs),
            bsc:exit_with(0)
    end.

module(Dir, Root) ->
    Sources = sources(Dir),
    Decls = lists:append([D || {_, D} <- Sources]),
    Module = declared_module(Decls),
    Expect = expected(Dir, Root, Sources),
    %% What the module's `using` lines reach, read and never built.
    World = bsc:type_world(Dir, Root),
    Exports = resolved(Sources, World, Expect),
    publish(bs_diag:channel(), Dir, Module,
            [B || {behaviour, _, B} <- Decls],
            operations(Sources, Exports, Module)).

%%% ---------------------------------------------------------------------------
%%% Reading the module
%%% ---------------------------------------------------------------------------

%% Classifying and parsing go through `bsc:dir_kind/1` and `bsc:parse_path/1`,
%% so this mode cannot disagree with the compiler about what a directory is.
%% `parse_path/1` publishes its own lex and parse diagnostics, so a file that
%% will not parse is already reported when the error arrives here. The
%% `namespace` arm is defensive: `answer/3` refuses a namespace first.
sources(Dir) ->
    case bsc:dir_kind(Dir) of
        namespace       -> refuse_namespace(Dir);
        {module, Files} -> [{F, parse(F)} || F <- Files]
    end.

parse(File) ->
    case bsc:parse_path(File) of
        {ok, Decls} -> Decls;
        {error, _}  -> bsc:exit_with(1)
    end.

%% `Main` when there is no `module` line, as in `bs_check:module_name/1`; the
%% declaration pass refuses that module before an answer is published.
declared_module(Decls) ->
    case [N || {module, _, N} <- Decls] of
        [N | _] -> N;
        []      -> 'Main'
    end.

%%% ---------------------------------------------------------------------------
%%% The module atom the path expects
%%%
%%% The answer names the module atom a caller writes on a `using` line. The
%%% compiler refuses a declaration that does not match its path, so
%%% reporting one here would hand back a name that never resolves. This
%%% module computes the expected atom, the one thing in this mode that
%%% `--src-root` governs; the declaration pass compares it.
%%% ---------------------------------------------------------------------------

expected(Dir, Root, Sources) ->
    try bsc:expected_module(Dir, Root)
    catch
        %% Both raises from `expected_module/2` already have a descriptor in
        %% `bs_diag`; uncaught they would reach the author as a stack trace.
        error:Reason when is_tuple(Reason) -> fail(primary(Sources), Reason)
    end.

%% A condition found over the whole directory is reported against the module's
%% declaration file: `index.bs` when there is one, which `dir_kind/1` sorts
%% first. Same rule as `bsc:primary/2`.
primary([{P, _} | _]) -> P;
%% Defensive: `dir_kind/1` returns `{module, Files}` only for a non-empty list.
primary([])           -> "".

%%% ---------------------------------------------------------------------------
%%% What the checker already computed
%%% ---------------------------------------------------------------------------

%% This module reports and never re-derives: `exports_of/3` runs the
%% compile's declaration refusals and resolves every public signature, and
%% this adds only what the export table cannot carry, the declaring file and
%% line and the parameter names. A refusal goes through `hinted/2` as a
%% compile's does, so an unknown type that a reachable module declares is
%% refused in the same words here.
resolved(Sources, World, Expect) ->
    try bs_check:exports_of(Sources, World, Expect)
    catch
        error:Reason when is_tuple(Reason) ->
            fail(primary(Sources), bs_check:hinted(Reason, World))
    end.

%% Sorted by name then arity, not source order: a module is a directory,
%% so source order is an artefact of how the author split the files.
operations(Sources, Exports, Module) ->
    lists:sort(
      fun(#{name := N1, arity := A1}, #{name := N2, arity := A2}) ->
              {N1, A1} =< {N2, A2}
      end,
      [operation(File, Sig, Exports, Module)
       || {File, Decls} <- Sources,
          %% `=:= public`, not `=/= private`: an unmarked signature carries
          %% `none` and is private, so the inverted test would publish every
          %% unmarked function.
          {signature, _, _, _, _, public, _} = Sig <- Decls]).

%% A position is both halves. The parser hands the signature a
%% `{Line, Column}` pair, and it is split into two keys here as `bs_diag`
%% splits every descriptor's. `json:encode` has no rendering for a tuple,
%% so the pair must not go out whole under `line`.
operation(File, {signature, {Line, Column}, Name, Ret, Params, public, TVars},
          Exports, Module) ->
    {ParamTypes, Result} = maps:get({Name, length(Params)}, Exports),
    Op = #{tag => operation, module => Module, name => Name,
           arity => length(Params), file => File, line => Line, column => Column,
           params => [#{name => PName, type => type_string(T)}
                      || {{param, _, PName}, T} <- lists:zip(Params, ParamTypes)],
           result => type_string(Result)},
    case TVars of
        [] -> Op;
        _  -> written(Op, TVars, Ret, Params, ParamTypes, Result)
    end.

%% A polymorphic signature has no ground resolution to publish: its resolved
%% form is the extent, `term Pick(term, term)`, which is true of the function
%% and says nothing a caller can rely on. So it is published as written — the
%% declaration a call instantiates — with its variables listed beside it. A
%% written form the source printer cannot render falls back to the resolved one
%% for that position alone.
%% Rationale: compiler/features/F45-polymorphic-signatures.md.
written(Op, TVars, Ret, Params, ParamTypes, Result) ->
    Op#{type_variables => TVars,
        params => [#{name => PName, type => source_or(T, R)}
                   || {{param, T, PName}, R} <- lists:zip(Params, ParamTypes)],
        result => source_or(Ret, Result)}.

source_or(Surface, Resolved) ->
    case bs_check:type_source(Surface) of
        none -> type_string(Resolved);
        S    -> lists:flatten(S)
    end.

%% The exact top type prints as `term` on every channel; that rule lives in
%% `bs_types:to_string/1`, not here.
type_string(T) -> bs_types:to_string(T).

%%% ---------------------------------------------------------------------------
%%% Publishing
%%%
%%% The encoding is `bs_diag:channel()`, set by `--diagnostics`. The answer
%%% is printed once, on stdout.
%%% ---------------------------------------------------------------------------

publish(prose, _Dir, Module, Behaviours, Ops) ->
    io:format("module ~s~n", [Module]),
    [io:format("behaviour ~s~n", [B]) || B <- Behaviours],
    %% No `public` marker, because every line here is public by construction,
    %% and no parameter names, because a caller supplies a value, not a name.
    %% The names travel in the term, which is the full-fidelity form.
    [io:format("~s ~s~s(~s)~n",
               [Result, Name, variables(Op),
                lists:join(", ", [T || #{type := T} <- Ps])])
     || #{name := Name, params := Ps, result := Result} = Op <- Ops],
    nothing_public(Module, Ops);
publish(term, Dir, Module, Behaviours, Ops) ->
    %% One map per line under `~0p`, so a consumer splits on newlines rather
    %% than matching brackets.
    io:format("~0p~n", [#{tag => module, module => Module, path => Dir,
                          behaviours => Behaviours, operations => length(Ops)}]),
    [io:format("~0p~n", [Op]) || Op <- Ops],
    nothing_public(Module, Ops);
publish(json, Dir, Module, Behaviours, Ops) ->
    %% The same maps, one object per line, in the wire form `bs_diag`
    %% owns: the encoding and the framing are the channel's, not this
    %% module's.
    [bs_diag:put_json(M)
     || M <- [#{tag => module, module => Module, path => Dir,
                behaviours => Behaviours, operations => length(Ops)} | Ops]],
    nothing_public(Module, Ops).

%% `<T, E>` after the name, as the author wrote it; nothing for a ground
%% signature.
variables(#{type_variables := Vs}) ->
    "<" ++ lists:join(", ", [atom_to_list(V) || V <- Vs]) ++ ">";
variables(_) -> "".

%% Zero operations is an answer: exit 0, with the explanation on stderr so
%% stdout stays parseable.
nothing_public(_Module, [_ | _]) -> ok;
nothing_public(Module, []) ->
    io:format(standard_error,
              "bsc: ~s exports nothing, so it offers no operations~n"
              "  a signature with no `public` in front of it is private, and a~n"
              "  private function is not part of a module's API. Mark the ones~n"
              "  callers need `public`.~n", [Module]).

%%% ---------------------------------------------------------------------------
%%% Refusals
%%%
%%% These two are about what was typed and name no source line, so they are
%%% not diagnostics. Everything about the source goes through `fail/2`.
%%% ---------------------------------------------------------------------------

refuse_namespace(Dir) ->
    io:format(standard_error,
              "bsc: ~s is a namespace, not a module~n"
              "  it holds no `.bs` files of its own, so it declares no~n"
              "  operations — a namespace is erased entirely (41 §5). Name one~n"
              "  of the modules under it:~n"
              "~s",
              [Dir, [io_lib:format("      ~s~n", [D])
                     || D <- bsc:module_dirs(Dir)]]),
    bsc:exit_with(2).

refuse_not_a_module(A) ->
    io:format(standard_error,
              "bsc: ~s is not a module~n"
              "  --api takes a `.bs` file or a directory holding one.~n", [A]),
    bsc:exit_with(2).

%% A condition about the source is published through `bs_diag` under its
%% existing descriptor, and the run stops without an answer. A shape `bs_diag`
%% does not know is still reported, as in `bsc:publish/2`, because the
%% alternative is a stack trace.
fail(Path, Reason) ->
    Desc = case bs_diag:descriptor(Path, Reason) of
               unhandled -> #{tag => unclassified, severity => error,
                              file => Path, detail => Reason};
               Found     -> Found
           end,
    bs_diag:emit(bs_diag:channel(), Desc),
    bsc:exit_with(1).
