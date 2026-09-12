%%% bs_api — `bsc --api <Module>`: what operations a module offers, in
%%% beam-sharp's own types, with nothing built (F17, ticket 23 §10).
%%%
%%% Two rules shape it. A signature's types resolve from declarations alone —
%%% the module's own, and since ticket 73 (F44) those of the modules its
%%% `using` lines reach, read in dependency order by `bsc:type_world/2` and
%%% resolved by `bs_check:exports_of/2` — with nothing compiled, which is
%%% what makes "no build" true. And the answer prints RESOLVED types, never
%%% a type's name: a name is the author's spelling, a dependent may now
%%% spell the same type as `Order`, `Orders.Order` or a hand-written map
%%% with the tag, and the resolved form is the one every caller can rely on.
%%%
%%% The refusal line is "is every declaration true", not "does it compile".
%%% An inexhaustive body still answers, because the API is what the signatures
%%% declare. An unknown type, a file that will not parse, and a `module` line
%%% that does not match its path are refused: each makes a declaration untrue,
%%% and the module atom is part of the answer (ticket 41 §5).
%%%
%%% Nothing here truncates. Nor does anything here carry a residual: the API
%%% is the signatures, and the untruncated residual travels on `--diagnostics
%%% term` (F16). Ticket 43 once named `--api` as that channel; corrected
%%% 2026-09-11 (ENG-265).
-module(bs_api).

-export([answer/3]).

%%% ---------------------------------------------------------------------------
%%% The entry point
%%%
%%% Reached from `bsc:main/1` only. It ends in `exit_with/1` like every other
%%% CLI mode, so every test for this feature drives the built escript.
%%% ---------------------------------------------------------------------------

%% A namespace named on the command line arrives with EMPTY paths, because
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
    %% A path that does not exist is refused HERE. A `.bs` suffix makes an
    %% argument a path whether or not the file exists, and `module_dir_of/1`
    %% would then answer about its directory, which may be a real module
    %% nobody named.
    case [P || P <- Paths, not filelib:is_file(P)] of
        [Missing | _] -> refuse_not_a_module(Missing);
        [] ->
            %% Naming a file names its module, and `bsc:module_dir_of/1` is
            %% that rule's one implementation (F15).
            Dirs = lists:usort([bsc:module_dir_of(P) || P <- Paths]),
            lists:foreach(fun(D) -> module(D, Root) end, Dirs),
            bsc:exit_with(0)
    end.

module(Dir, Root) ->
    Sources = sources(Dir),
    Decls = lists:append([D || {_, D} <- Sources]),
    Module = declared_module(Decls),
    ok = check_path(Dir, Root, Module, Decls, Sources),
    %% What the module's `using` lines reach, read and never built (F44).
    World = bsc:type_world(Dir, Root),
    Exports = resolved(Decls, Sources, World),
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

%% A module with no `module` line is `Main`, as in `bs_check:module_name/1`.
declared_module(Decls) ->
    case [N || {module, _, N} <- Decls] of
        [N | _] -> N;
        []      -> 'Main'
    end.

%%% ---------------------------------------------------------------------------
%%% The `module` line must match the path, and `--api` checks it
%%%
%%% The answer names the module atom a caller writes on a `using` line. The
%%% compiler refuses a declaration that does not match its path, so reporting
%%% one here would hand back a name that never resolves (ticket 41 §5). This
%%% check is the one thing in this mode that `--src-root` governs.
%%% ---------------------------------------------------------------------------

check_path(Dir, Root, Module, Decls, Sources) ->
    case expected(Dir, Root, Sources) of
        Module -> ok;
        Expect -> fail(primary(Sources), {module_path_mismatch, Module, Expect,
                                          module_line(Decls)})
    end.

expected(Dir, Root, Sources) ->
    try bsc:expected_module(Dir, Root)
    catch
        %% Both raises from `expected_module/2` already have a descriptor in
        %% `bs_diag`; uncaught they would reach the author as a stack trace.
        error:Reason when is_tuple(Reason) -> fail(primary(Sources), Reason)
    end.

%% The fallback is a POSITION, not a line. A file with no `module` line has
%% nothing to point at, so the diagnostic is attributed to the top of it —
%% and since F35 the top of a file is `{1, 1}`, because every descriptor that
%% names a line names a column beside it and `message/1` has no catch-all to
%% fall through to when one is missing.
module_line(Decls) ->
    case [L || {module, L, _} <- Decls] of
        [L | _] -> L;
        []      -> {1, 1}
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

%% This module reports and never re-derives: `exports_of/2` resolves every
%% public signature, and this adds only what the export table cannot carry,
%% the declaring file and line and the parameter names. A refusal goes
%% through `hinted/2` as a compile's does, so an unknown type that a
%% reachable module declares is refused in the same words here (F44).
resolved(Decls, Sources, World) ->
    try bs_check:exports_of(Decls, World)
    catch
        error:Reason when is_tuple(Reason) ->
            fail(primary(Sources), bs_check:hinted(Reason, World))
    end.

%% Sorted by name then arity, not source order: a module is a directory (F15),
%% so source order is an artefact of how the author split the files.
operations(Sources, Exports, Module) ->
    lists:sort(
      fun(#{name := N1, arity := A1}, #{name := N2, arity := A2}) ->
              {N1, A1} =< {N2, A2}
      end,
      [operation(File, Sig, Exports, Module)
       || {File, Decls} <- Sources,
          %% `=:= public`, not `=/= private`: an unmarked signature carries
          %% `none` and is private (F12), so the inverted test would publish
          %% every unmarked function.
          {signature, _, _, _, _, public} = Sig <- Decls]).

operation(File, {signature, Line, Name, _Ret, Params, public}, Exports, Module) ->
    {ParamTypes, Result} = maps:get({Name, length(Params)}, Exports),
    #{tag => operation, module => Module, name => Name,
      arity => length(Params), file => File, line => Line,
      params => [#{name => PName, type => type_string(T)}
                 || {{param, _, PName}, T} <- lists:zip(Params, ParamTypes)],
      result => type_string(Result)}.

%% The exact top type prints as `term` on every channel; that rule lives in
%% `bs_types:to_string/1`, not here (ticket 61).
type_string(T) -> bs_types:to_string(T).

%%% ---------------------------------------------------------------------------
%%% Publishing
%%%
%%% The answer goes on the encoding `--diagnostics` selected, read from
%%% `bs_diag:channel()` rather than a second flag (F16), and it is printed
%%% once: a diagnostic goes to both streams because a human and a tool may
%%% both be watching, but a query has one consumer.
%%% ---------------------------------------------------------------------------

publish(prose, _Dir, Module, Behaviours, Ops) ->
    io:format("module ~s~n", [Module]),
    [io:format("behaviour ~s~n", [B]) || B <- Behaviours],
    %% No `public` marker, because every line here is public by construction
    %% (F12), and no parameter names, because a caller supplies a value, not a
    %% name. The names travel in the term, which is the full-fidelity
    %% form (F16).
    [io:format("~s ~s(~s)~n",
               [Result, Name, lists:join(", ", [T || #{type := T} <- Ps])])
     || #{name := Name, params := Ps, result := Result} <- Ops],
    nothing_public(Module, Ops);
publish(term, Dir, Module, Behaviours, Ops) ->
    %% One map per line under `~0p`, so a consumer splits on newlines rather
    %% than matching brackets (F16).
    io:format("~0p~n", [#{tag => module, module => Module, path => Dir,
                          behaviours => Behaviours, operations => length(Ops)}]),
    [io:format("~0p~n", [Op]) || Op <- Ops],
    nothing_public(Module, Ops).

%% Zero operations is an answer, so exit 0 — unlike `bsc`'s `{ambiguous, []}`
%% at exit 2, where the user asked to run something. The teaching sentence goes
%% to stderr in both channels so stdout stays parseable; private is the default
%% (F12), so an unmarked module is the first thing a newcomer meets.
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
