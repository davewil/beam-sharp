#!/usr/bin/env escript
%%! -noshell
%%%
%%% Ticket 28 — angle brackets versus less-than, measured rather than argued.
%%%
%%% Reads the REAL walking-skeleton grammar (compiler/src/bs_parser.yrl) and
%%% lexer, applies four variant patches, builds each into a working parser, and
%%% runs the discriminating inputs through it.
%%%
%%% Patching the real grammar rather than a frozen copy is deliberate: if the
%%% skeleton's grammar changes, this re-measures the new one instead of
%%% confirming a stale snapshot.
%%%
%%%   base — the skeleton exactly as it ships (no generics at all)
%%%   B    — parameterised types in TYPE positions only
%%%   D    — B + explicit instantiation on ANY PascalCase name (C#'s shape),
%%%          plus ticket 10 section 3's module identifier in value position
%%%   C    — B + instantiation on a CLOSED, COMPILER-KNOWN name set only
%%%          (ticket 27's stratum-2 codegen obligations), plus the same
%%%          module-identifier rule
%%%
%%% WHY BEHAVIOUR AND NOT CONFLICT COUNTS. yecc resolves shift/reduce conflicts
%%% SILENTLY using the precedence table, and reports nothing. Every variant here
%%% reports zero conflicts, including the one that gets the answer wrong. The
%%% conflict count is not evidence; which reading you actually get is.
%%%
%%% Run:  escript 28a_bracket_disambiguation.escript
%%% From: wayfinder/prototypes/   (locates ../../compiler/src itself)

-mode(compile).

main(_) ->
    Src = src_dir(),
    Dir = tmp_dir(),
    io:format("grammar under test: ~s~n", [filename:join(Src, "bs_parser.yrl")]),
    io:format("scratch:            ~s~n", [Dir]),
    {ok, Yrl} = file:read_file(filename:join(Src, "bs_parser.yrl")),
    {ok, Xrl} = file:read_file(filename:join(Src, "bs_lexer.xrl")),
    ok = build_lexer(Dir, "plain_lexer", binary_to_list(Xrl), plain),
    ok = build_lexer(Dir, "cg_lexer",    binary_to_list(Xrl), cg),
    Variants = [{"base", fun(G) -> G end,      plain_lexer},
                {"B",    fun patch_b/1,        plain_lexer},
                {"D",    fun patch_d/1,        plain_lexer},
                {"C",    fun patch_c/1,        cg_lexer}],
    [ok = build_parser(Dir, N, F(binary_to_list(Yrl))) || {N, F, _} <- Variants],
    [report(N, L) || {N, _, L} <- Variants],
    io:format("~n~s~n", [legend()]),
    ok.

%% --- locating and staging ---------------------------------------------------

src_dir() ->
    Here = filename:dirname(escript:script_name()),
    filename:join([Here, "..", "..", "compiler", "src"]).

tmp_dir() ->
    D = filename:join("/tmp", "bs28_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok = filelib:ensure_path(D),
    true = code:add_patha(D),
    D.

build_lexer(Dir, Name, Xrl, Kind) ->
    Body = case Kind of
               plain -> Xrl;
               cg    -> cg_lexer_patch(Xrl)
           end,
    File = filename:join(Dir, Name ++ ".xrl"),
    ok = file:write_file(File, rename_module(Body, Name)),
    {ok, Erl} = leex:file(File, [{report, false}]),
    load(Erl, Dir).

build_parser(Dir, Name, Yrl) ->
    File = filename:join(Dir, Name ++ ".yrl"),
    ok = file:write_file(File, Yrl),
    {ok, Erl} = yecc:file(File, [{report, false}, {verbose, false}]),
    load(Erl, Dir).

load(Erl, Dir) ->
    {ok, Mod} = compile:file(Erl, [return_errors, {outdir, Dir}]),
    code:purge(Mod),
    {module, Mod} = code:load_abs(filename:join(Dir, atom_to_list(Mod))),
    ok.

%% leex takes the module name from the filename, so nothing to rewrite; yecc
%% likewise. Kept as a seam in case either grows an explicit module directive.
rename_module(Body, _Name) -> Body.

%% --- the variant patches ----------------------------------------------------

%% Parameterised type constructors, type positions only.
patch_b(G) ->
    insert_after(G,
      "type_prim -> '(' type_list ')' : {t_tuple, '$2'}.",
      "\n\ntype_prim -> lident '<' type_list '>' : {t_app, value('$1'), '$3'}."
      "\ntype_prim -> uident '<' type_list '>' : {t_app, value('$1'), '$3'}.").

%% B + C#'s shape: any PascalCase name may carry an instantiation bracket.
%% Also adds ticket 10 section 3 -- a module identifier in value position.
patch_d(G) ->
    G1 = patch_b(G),
    insert_before(G1,
      "expr -> uident '(' expr_list ')'",
      "expr -> uident : {e_modid, line('$1'), value('$1')}.\n\n"
      "expr -> uident '<' type_list '>' '(' expr_list ')' :\n"
      "    {e_inst, line('$1'), value('$1'), '$3', '$6'}.\n\n").

%% B + the adopted rule: only a compiler-known codegen obligation may carry a
%% bracket in expression position. Same module-identifier rule as D, so the two
%% differ in exactly one thing.
patch_c(G) ->
    G1 = patch_b(G),
    G2 = replace(G1, "  uident lident atom_lit integer '_'",
                     "  uident cgident lident atom_lit integer '_'"),
    insert_before(G2,
      "expr -> uident '(' expr_list ')'",
      "expr -> uident : {e_modid, line('$1'), value('$1')}.\n\n"
      "expr -> cgident '<' type_list '>' '(' expr_list ')' :\n"
      "    {e_inst, line('$1'), value('$1'), '$3', '$6'}.\n\n").

%% The lexer half of variant C: a closed set gets its own token class.
cg_lexer_patch(Xrl) ->
    X1 = replace(Xrl,
      "{UPPER}{ALNUM}*         : {token, {uident, TokenLine, list_to_atom(TokenChars)}}.",
      "{UPPER}{ALNUM}*         : {token, {class(TokenChars), TokenLine, list_to_atom(TokenChars)}}."),
    X1 ++
      "\n%% Ticket 27: a codegen obligation REQUIRES a ground type argument, so it is\n"
      "%% exactly the set whose type argument matching cannot recover -- and exactly\n"
      "%% the set that needs a bracket. Closed, and known before parsing begins.\n"
      "class(Chars) ->\n"
      "    case lists:member(Chars, [\"ValidateAs\", \"ParseAtom\", \"ToExistingAtom\"]) of\n"
      "        true  -> cgident;\n"
      "        false -> uident\n"
      "    end.\n".

%% --- the cases --------------------------------------------------------------

cases() ->
    [{"ticket 28's own example",             "Go() -> F(a < b, c > d);"},
     {"chained comparison",                  "Go() -> a < b > c;"},
     {"chained comparison in a guard",       "Go(x) when a < b > c -> :ok;"},
     {"ticket 08's guard shape",             "Go(x,y) when x < y && Total(x) > 0 -> :ok;"},
     {"instantiation in expr position",      "Go() -> ValidateAs<Order>(x);"},
     {"instantiation as an argument",        "Go() -> F(ValidateAs<Order>(x));"},
     {"nested type argument",                "Go(x) -> ValidateAs<list<Money>>(x);"},
     {"MODULE ID compared with <",           "Go() -> F(Foo < b, c > d);"},
     {"user generic call, no brackets",      "Go(xs,f) -> Map(xs, f);"},
     {"parameterised type in a signature",   "int Go(list<int> xs);"},
     {"nested parameterised type",           "type T = list<list<int>>;"},
     {"union inside a type argument",        "type R = result<int | atom, E>;"}].

report(Name, Lexer) ->
    Mod = list_to_atom(Name),
    io:format("~n========== variant ~s (lexer: ~s) ==========~n", [Name, Lexer]),
    lists:foreach(
      fun({Label, Src}) ->
          {ok, Toks, _} = Lexer:string(Src),
          R = case Mod:parse(Toks) of
                  {ok, Ast}  -> "ok    " ++ shape(Ast);
                  {error, E} -> "FAIL  " ++ err(E)
              end,
          io:format("  ~-36s ~s~n", [Label, R])
      end, cases()).

legend() ->
    "READING THE TABLE\n"
    "  e_op   a comparison won        e_inst  an instantiation won\n"
    "  e_call an ordinary call        t_app   a parameterised type\n"
    "  e_modid a module identifier in value position (ticket 10 section 3)\n\n"
    "THE ROW THAT DECIDES IT is `MODULE ID compared with <`. Variant D commits to\n"
    "the instantiation reading and then fails at `d`; variant C reads it as two\n"
    "comparisons. C is the only variant that gets BOTH that row and the\n"
    "instantiation rows right, and it does so with no lookahead and no\n"
    "backtracking -- the distinction is made in the lexer, on a closed set.".

%% --- helpers ----------------------------------------------------------------

shape(Ast) ->
    case lists:usort(collect(Ast)) of
        [] -> "(no marker nodes)";
        Ts -> string:join([atom_to_list(T) || T <- Ts], ",")
    end.

collect(T) when is_tuple(T) ->
    L = tuple_to_list(T),
    Hd = case L of
             [H | _] when is_atom(H) ->
                 case lists:member(H, ['e_op','e_inst','e_call','t_app','e_modid']) of
                     true -> [H]; false -> []
                 end;
             _ -> []
         end,
    Hd ++ lists:flatmap(fun collect/1, L);
collect(L) when is_list(L) -> lists:flatmap(fun collect/1, L);
collect(_) -> [].

err({_L, M, Msg}) -> lists:flatten(M:format_error(Msg));
err(E)            -> lists:flatten(io_lib:format("~p", [E])).

replace(S, From, To) ->
    case string:find(S, From) of
        nomatch -> erlang:error({patch_anchor_missing, From});
        _       -> lists:flatten(string:replace(S, From, To))
    end.

insert_after(S, Anchor, Text)  -> replace(S, Anchor, Anchor ++ Text).
insert_before(S, Anchor, Text) -> replace(S, Anchor, Text ++ Anchor).
