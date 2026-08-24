%%% bs_api — `bsc --api <Module>`: what operations exist, with no build.
%%%
%%% F17, ticket 23 §10. The two answers that exist without this one are both
%%% inadequate and the ticket says why: a directory listing gives names without
%%% types, and the built artefact — `module_info(exports)` plus the `-spec` from
%%% the `abstract_code` chunk — requires a build and answers in ERLANG, handing
%%% back `{ok, integer()}` where the language said `(:ok, int)`.
%%%
%%% TWO MEASURED FACTS DECIDED THE WHOLE DESIGN, and neither was a preference.
%%%
%%% 1. A SIGNATURE'S TYPES RESOLVE WITHOUT A WORLD. `bs_check:exports_of/1`
%%%    builds the type environment from this module's own declarations and
%%%    resolves each signature against it. `bs_check:check_dir/3` needs a world,
%%%    and `add_import/7` RAISES `{unknown_module, M, L}` for a `using` line
%%%    whose target has not been checked yet — so the obvious implementation
%%%    ("check the module and report what the checker produced") answers for a
%%%    leaf module and fails for exactly the modules worth querying. The
%%%    declaration pass has no such coupling, which is what makes §10's "with no
%%%    build" true rather than aspirational: nothing is compiled, nothing is
%%%    emitted, and no dependency is even read.
%%%
%%% 2. A TYPE NAME DOES NOT CROSS THE MODULE BOUNDARY. `import_env/3` builds
%%%    `funs`, `mods`, `qual` and `privates` and no table of types, and
%%%    `exports_of/1` hands a dependent the RESOLVED type rather than the name
%%%    the author wrote. So `Reply HandleCall(Request, term, int)` answers in a
%%%    vocabulary the caller cannot use — `Request` and `Reply` are the callee's
%%%    private words. The resolved form is the only thing that travels, so the
%%%    resolved form is what this prints.
%%%
%%% WHERE THE REFUSAL LINE FALLS, and it is NOT "does the module compile". A
%%% module with an inexhaustive function still answers, and so does one with a
%%% function that has no clauses at all: exhaustiveness is a property of the
%%% BODIES, and the API is what the SIGNATURES declare. That argument stands on
%%% its own and is the whole reason. It used to cite 23 §7 as well; §7 was
%%% OVERTURNED on 2026-08-23 (ticket 22 — a clause-less signature stays a hard
%%% error and there is no incomplete marker), so the citation is gone and the
%%% behaviour is unchanged. Answering here is not compiling: nothing is emitted,
%%% and refusing to print a signature the author wrote would withhold the one
%%% answer the caller can act on. What is refused is anything
%%% that makes a declaration untrue: a signature naming an unknown type, a file
%%% that will not parse, and 41 §5's `module_path_mismatch` — that last one
%%% because the MODULE ATOM is part of the answer, and reporting an atom the
%%% module cannot be built under hands back a `using` line that never resolves.
%%%
%%% NOTHING HERE TRUNCATES. `bsc.erl` and `F2-interval-refinements.md` both
%%% already describe `--api` as the full-fidelity channel against ticket 43's cap
%%% on printed residuals, so `?RESIDUAL_CASES` and `bs_diag`'s capped joiner
%%% appear nowhere in this module. A record expanding into a long field list is
%%% the correct answer, not a defect to cap.
-module(bs_api).

-export([answer/3]).

%%% ---------------------------------------------------------------------------
%%% The entry point
%%%
%%% Reached from `bsc:main/1` and from nowhere else. It halts, like every other
%%% CLI mode, which is why every test for this feature drives the built escript.
%%% ---------------------------------------------------------------------------

%% A NAMESPACE NAMED HERE LANDS IN THE ARGV RATHER THAN IN THE PATHS, and
%% answering it with the run refusal below would answer a precise mistake with a
%% general message. `bsc:is_path_arg/1` counts a directory as a path only if it
%% is a module, so `bsc --api examples/Shop` on a directory holding no `.bs`
%% files of its own arrives with empty paths — the same shape `compile_or_run/3`
%% already handles, for the same reason.
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
    halt(2);
answer([], [], _Root) ->
    io:format(standard_error,
              "bsc: --api needs a module~n"
              "      bsc --api examples/Counter~n"
              "      bsc --src-root examples --api examples/Shop/Reports~n", []),
    halt(2);
answer(Paths, [], Root) ->
    %% A PATH THAT DOES NOT EXIST IS CAUGHT HERE, AND IT HAS TO BE. `.bs` on the
    %% end makes an argument a path whether or not the file is there, so
    %% `module_dir_of/1` hands back its DIRECTORY — and that directory may be a
    %% perfectly good module. Measured: `bsc --api /tmp/nope.bs` answered about
    %% `/tmp`, which is a module the moment anything has left a `.bs` file in it.
    %% An answer about a module nobody named is worse than a refusal.
    case [P || P <- Paths, not filelib:is_file(P)] of
        [Missing | _] -> refuse_not_a_module(Missing);
        [] ->
            %% Through `bsc:module_dir_of/1` rather than a second `is_dir` test
            %% here: naming a file names its module (F15), and that rule has one
            %% implementation on purpose.
            Dirs = lists:usort([bsc:module_dir_of(P) || P <- Paths]),
            lists:foreach(fun(D) -> module(D, Root) end, Dirs),
            halt(0)
    end.

module(Dir, Root) ->
    Sources = sources(Dir),
    Decls = lists:append([D || {_, D} <- Sources]),
    Module = declared_module(Decls),
    ok = check_path(Dir, Root, Module, Decls, Sources),
    Exports = resolved(Decls, Sources),
    publish(bs_diag:channel(), Dir, Module,
            [B || {behaviour, _, B} <- Decls],
            operations(Sources, Exports, Module)).

%%% ---------------------------------------------------------------------------
%%% Reading the module
%%% ---------------------------------------------------------------------------

%% `bsc:dir_kind/1` and `bsc:parse_path/1`, not a wildcard and a lexer call of
%% this module's own. Both are exported for exactly this reason and the comment
%% on them says so: a classification rule with two implementations has two
%% answers. `parse_path/1` also publishes its own lex and parse diagnostics on
%% the channel, so a file that will not parse is already reported by the time
%% this sees the error.
%% THE `namespace` ARM HERE IS DEFENSIVE AND SAYS SO, which is the precedent
%% `bs_types:b_str/1` set for a representable-but-currently-unreachable case. A
%% namespace named on the command line is caught by `answer/3`'s first clause,
%% and by the time a path reaches this function it has been through
%% `module_dir_of/1` — a directory that got there is a module because
%% `is_path_arg/1` required it, and a file's own directory holds at least that
%% file. Naming the set beats crashing if either of those ever stops being true.
sources(Dir) ->
    case bsc:dir_kind(Dir) of
        namespace       -> refuse_namespace(Dir);
        {module, Files} -> [{F, parse(F)} || F <- Files]
    end.

parse(File) ->
    case bsc:parse_path(File) of
        {ok, Decls} -> Decls;
        {error, _}  -> halt(1)
    end.

%% The same default `bs_check:module_name/1` applies, and it is a field read
%% rather than a rule: a module with no `module` line is `Main`.
declared_module(Decls) ->
    case [N || {module, _, N} <- Decls] of
        [N | _] -> N;
        []      -> 'Main'
    end.

%%% ---------------------------------------------------------------------------
%%% 41 §5's check, and why `--api` runs it
%%%
%%% The answer NAMES A MODULE ATOM, and that atom is what a caller writes on a
%%% `using` line. A declaration that does not match its path is refused by the
%%% compiler, so reporting it here without the same refusal would hand back a
%%% name that can never resolve — an answer that reads as actionable and is not,
%%% which is 23 §2's own warning one construct along.
%%%
%%% It is also what makes `--src-root` load-bearing here. F16 recorded that a
%%% flag accepted and not honoured costs the flag its credibility everywhere
%%% else; signature resolution genuinely does not need a root, and this does.
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
        %% `src_root_mismatch` and `src_root_is_the_module` are both raised by
        %% `expected_module/2` and both already have a descriptor and a message
        %% in `bs_diag`. Uncaught they reach the author as an escript stack
        %% trace, which this project calls the worst diagnostic it produces.
        error:Reason when is_tuple(Reason) -> fail(primary(Sources), Reason)
    end.

module_line(Decls) ->
    case [L || {module, L, _} <- Decls] of
        [L | _] -> L;
        []      -> 1
    end.

%% Which file a condition found over the whole directory is reported against —
%% `bsc:primary/2`'s rule: the module's declaration file, which is `index.bs`
%% when there is one, since `dir_kind/1` sorts it first.
primary([{P, _} | _]) -> P;
%% Defensive, per `sources/1`: `dir_kind/1` returns `{module, Files}` only for a
%% non-empty list, so a module always has a first file.
primary([])           -> "".

%%% ---------------------------------------------------------------------------
%%% What the checker already computed
%%% ---------------------------------------------------------------------------

%% REPORTING, NOT RE-DERIVING. `exports_of/1` builds the type environment and
%% resolves every public signature against it; this module never resolves a type
%% of its own. What it adds is what the export table cannot carry: which file
%% and line declares each operation, and the parameter names.
resolved(Decls, Sources) ->
    try bs_check:exports_of(Decls)
    catch
        error:Reason when is_tuple(Reason) -> fail(primary(Sources), Reason)
    end.

%% SORTED BY NAME THEN ARITY, not in source order. A module is a directory
%% (F15), so source order is an artefact of how the author split the files, and
%% the answer should be a function of the module rather than of its layout.
operations(Sources, Exports, Module) ->
    lists:sort(
      fun(#{name := N1, arity := A1}, #{name := N2, arity := A2}) ->
              {N1, A1} =< {N2, A2}
      end,
      [operation(File, Sig, Exports, Module)
       || {File, Decls} <- Sources,
          %% `=:= public` rather than `=/= private`, which is F12's rule and not
          %% a style choice: an unmarked signature carries `none`, and the
          %% inverted spelling would put every unmarked function in the API.
          {signature, _, _, _, _, public} = Sig <- Decls]).

operation(File, {signature, Line, Name, _Ret, Params, public}, Exports, Module) ->
    {ParamTypes, Result} = maps:get({Name, length(Params)}, Exports),
    #{tag => operation, module => Module, name => Name,
      arity => length(Params), file => File, line => Line,
      params => [#{name => PName, type => type_string(T)}
                 || {{param, _, PName}, T} <- lists:zip(Params, ParamTypes)],
      result => type_string(Result)}.

%% `term` IS THE LANGUAGE'S WORD FOR THE TOP TYPE. This channel used to strip
%% the six-way expansion locally; ticket 61 found the same expansion reaching
%% authors through `ValidationError` and the valve's diagnostics, and moved the
%% rule into `bs_types:to_string/1` itself — the exact top now prints as `term`
%% on every channel, and a partial residual is still enumerated.
type_string(T) -> bs_types:to_string(T).

%%% ---------------------------------------------------------------------------
%%% Publishing
%%%
%%% 23 §10 says the answer arrives "on this channel", and the channel is F16's:
%%% `bs_diag:channel()` already holds which encoding the CLI was asked for, so no
%%% second selector is minted. The internal name of that setting is `channel`
%%% rather than `diagnostics` precisely because it governs more than diagnostics.
%%%
%%% THE ANSWER IS PRINTED ONCE, NOT TWICE. A diagnostic goes to both streams
%%% because a human watches a build while a tool reads the term; an `--api`
%%% invocation has exactly one consumer, so duplicating its answer onto stderr
%%% would be noise. Prose to stdout is therefore right here and wrong there.
%%% ---------------------------------------------------------------------------

publish(prose, _Dir, Module, Behaviours, Ops) ->
    io:format("module ~s~n", [Module]),
    [io:format("behaviour ~s~n", [B]) || B <- Behaviours],
    %% NO `public` MARKER ON THE LINE. Every line is public by construction —
    %% F12 makes a private function not part of the module's API — so the word
    %% carries no information, and 23 §12 is explicit that a generator's ability
    %% to emit something is not a reason to require it.
    %%
    %% AND NO PARAMETER NAMES. A caller supplies a value, not a name. They are
    %% real information about intent, so they are not discarded: they travel in
    %% the term. That is F16's split exactly — the term is full fidelity and the
    %% prose is the lossy function of it.
    [io:format("~s ~s(~s)~n",
               [Result, Name, lists:join(", ", [T || #{type := T} <- Ps])])
     || #{name := Name, params := Ps, result := Result} <- Ops],
    nothing_public(Module, Ops);
publish(term, Dir, Module, Behaviours, Ops) ->
    %% ONE MAP PER LINE, `~0p`, framed by the newline — F16's rule, which it
    %% learned by shipping the unframed version first: under plain `~p` two maps
    %% wrap across several lines each with nothing between them, so the only way
    %% to find the boundary is to match brackets, which is the screen-scraping
    %% ticket 23 exists to abolish.
    io:format("~0p~n", [#{tag => module, module => Module, path => Dir,
                          behaviours => Behaviours, operations => length(Ops)}]),
    [io:format("~0p~n", [Op]) || Op <- Ops],
    nothing_public(Module, Ops).

%% ZERO OPERATIONS IS AN ANSWER, NOT AN INVOCATION ERROR — so exit 0, which is
%% where this parts company with `bsc`'s `{ambiguous, []}` at exit 2. There the
%% user asked to RUN something and there was nothing to run; here they asked
%% what exists and the honest answer is "nothing does".
%%
%% The teaching sentence goes to stderr in both channels, so a consumer reading
%% stdout gets an answer of zero operations and nothing else to parse. F12 found
%% this exact moment on the run path: private is the default, so a module nobody
%% has marked is the first thing a newcomer meets, and it is the moment the
%% language is least able to explain itself.
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
%%% The two below are about what you TYPED and neither can name a source line,
%%% which is `bin/check-diagnostics.sh`'s own test for what is a diagnostic and
%%% what is not. Everything that IS about the source goes through `fail/2`.
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
    halt(2).

refuse_not_a_module(A) ->
    io:format(standard_error,
              "bsc: ~s is not a module~n"
              "  --api takes a `.bs` file or a directory holding one.~n", [A]),
    halt(2).

%% A condition about the SOURCE. It is published through `bs_diag` with its
%% existing descriptor and its existing prose — this feature mints no tag of its
%% own — and then the run stops without printing an answer, because a refusal
%% means there is no true answer to print.
%% The `unhandled` arm is `bsc:publish/2`'s, kept for its reason rather than
%% copied for symmetry: a shape `bs_diag` does not know still gets reported,
%% because the alternative is an escript stack trace at the one moment the
%% compiler is already confused.
fail(Path, Reason) ->
    Desc = case bs_diag:descriptor(Path, Reason) of
               unhandled -> #{tag => unclassified, severity => error,
                              file => Path, detail => Reason};
               Found     -> Found
           end,
    bs_diag:emit(bs_diag:channel(), Desc),
    halt(1).
