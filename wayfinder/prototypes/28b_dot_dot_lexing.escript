#!/usr/bin/env escript
%%! -noshell
%%%
%%% Ticket 28's loose end — the `..` rest spelling, measured against the two
%%% other constructs that want a dot.
%%%
%%% Ticket 27 left `[h, ..t]` provisional; ticket 08 fixed the restriction
%%% (prefix-plus-rest only) but pinned no spelling. Two things could collide
%%% with it and neither had been checked:
%%%
%%%   1. ticket 26's PROJECTION DOT  -- `o.Status`, and ticket 17's `List.Map`
%%%   2. FLOAT LITERALS              -- the classic Pascal/Rust hazard, where
%%%                                     `1..5` lexes as `1.` `.5`
%%%
%%% Patches the REAL skeleton lexer (compiler/src/bs_lexer.xrl) with the four
%%% rules the full language needs and that the slice does not yet have — `[`,
%%% `]`, a float literal, the projection dot and `..` — then lexes the
%%% adversarial adjacencies.
%%%
%%% Run:  escript 28b_dot_dot_lexing.escript
%%% From: wayfinder/prototypes/

-mode(compile).

main(_) ->
    Src  = filename:join([filename:dirname(escript:script_name()),
                          "..", "..", "compiler", "src", "bs_lexer.xrl"]),
    Dir  = filename:join("/tmp", "bs28b_" ++ integer_to_list(erlang:unique_integer([positive]))),
    ok   = filelib:ensure_path(Dir),
    true = code:add_patha(Dir),
    {ok, Xrl} = file:read_file(Src),
    File = filename:join(Dir, "dots_lexer.xrl"),
    ok = file:write_file(File, patch(binary_to_list(Xrl))),
    {ok, Erl} = leex:file(File, [{report, false}]),
    {ok, Mod} = compile:file(Erl, [return_errors, {outdir, Dir}]),
    code:purge(Mod),
    {module, Mod} = code:load_abs(filename:join(Dir, atom_to_list(Mod))),
    io:format("lexer under test: ~s (patched)~n~n", [Src]),
    lists:foreach(fun({L, S}) -> show(Mod, L, S) end, cases()),
    io:format("~n~s~n", [verdict()]).

%% leex prefers the LONGEST match, and among equal-length matches the earliest
%% rule. So the float rule must demand digits on BOTH sides of its dot; that is
%% what makes `1..5` fall back to the integer rule instead of starting a float.
patch(X) ->
    Anchor = "{D}+                    : {token, {integer, TokenLine, list_to_integer(TokenChars)}}.",
    New =
      "{D}+\\.{D}+              : {token, {float_lit, TokenLine, list_to_float(TokenChars)}}.\n"
      ++ Anchor ++
      "\n\n%% Ticket 28: `..` before `.`, so the rest spelling wins over projection.\n"
      "\\.\\.                    : {token, {'..', TokenLine}}.\n"
      "\\.                      : {token, {'.', TokenLine}}.\n"
      "\\[                      : {token, {'[', TokenLine}}.\n"
      "\\]                      : {token, {']', TokenLine}}.",
    case string:find(X, Anchor) of
        nomatch -> erlang:error(patch_anchor_missing);
        _       -> lists:flatten(string:replace(X, Anchor, New))
    end.

cases() ->
    [{"the provisional spelling",        "[h, ..t]"},
     {"unspaced",                        "[h,..t]"},
     {"rest straight after an integer",  "[1,..t]"},
     {"construction-position spread",    "[f, ..Rest]"},
     {"ticket 26's projection dot",      "o.Status"},
     {"ticket 17's qualified name",      "List.Map"},
     {"a float literal",                 "1.5"},
     {"float then rest",                 "[1.5, ..t]"},
     {"THE ADVERSARIAL CASE",            "1..5"},
     {"projection then rest, unspaced",  "o.Status..t"}].

show(Mod, Label, S) ->
    R = case Mod:string(S) of
            {ok, Toks, _} -> fmt(Toks);
            {error, E, _} -> lists:flatten(io_lib:format("LEX FAIL ~p", [E]))
        end,
    io:format("  ~-32s ~-14s -> ~s~n", [Label, S, R]).

fmt(Toks) -> string:join([tok(T) || T <- Toks], " ").

tok(T) when tuple_size(T) =:= 3 ->
    lists:flatten(io_lib:format("~p(~p)", [element(1, T), element(3, T)]));
tok(T) ->
    lists:flatten(io_lib:format("~p", [element(1, T)])).

verdict() ->
    "VERDICT: `1..5` lexes as integer(1) '..' integer(5), NOT as `1.` `.5`.\n"
    "The float rule requires digits on both sides of its dot, so longest-match\n"
    "declines it and falls back to the integer rule. `..` therefore costs nothing\n"
    "against floats or against ticket 26's projection dot -- and the range\n"
    "spelling stays available should ticket 20's integer intervals ever want it.".
