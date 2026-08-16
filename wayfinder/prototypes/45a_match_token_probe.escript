#!/usr/bin/env escript
%%% Ticket 45 — which token marks a match against a value already bound?
%%%
%%% Probe for the recommended answer `== name`. It patches the SHIPPED grammar
%%% (`compiler/src/bs_parser.yrl`) rather than a hand-written toy, so what is
%%% measured is what would actually be built.
%%%
%%% THE CONTROL EXISTS BECAUSE A CLEAN RESULT IS NOT EVIDENCE ON ITS OWN.
%%% Every variant tried came back clean first time, which is exactly what a
%%% broken harness reports. So phase 1 feeds yecc a grammar already KNOWN to be
%%% bad — F8 records `binding -> pattern '=' expr` at fifteen reduce/reduce with
%%% yecc refusing to generate — and requires it to report 15. Only then does
%%% "clean" mean anything.
%%%
%%% And per F6.9: yecc resolves shift/reduce silently through the precedence
%%% table, so a form is asserted by PARSING it, never by a conflict count.
%%%
%%% Run:  ./wayfinder/prototypes/45a_match_token_probe.escript

-mode(compile).

%% ---------------------------------------------------------------------------

main(_) ->
    io:format("OTP ~s~n", [erlang:system_info(otp_release)]),
    Root = repo_root(),
    Yrl  = filename:join([Root, "compiler", "src", "bs_parser.yrl"]),
    Xrl  = filename:join([Root, "compiler", "src", "bs_lexer.xrl"]),
    case filelib:is_file(Yrl) of
        false -> io:format("cannot find ~ts~n", [Yrl]), halt(1);
        true  -> ok
    end,
    {ok, Base} = file:read_file(Yrl),
    Work = work_dir(),
    file:set_cwd(Work),
    {ok, _} = file:copy(Xrl, "lexer.xrl"),

    Fails0 = phase_control(binary_to_list(Base)),
    Fails1 = phase_proposed(binary_to_list(Base)),
    Fails2 = phase_parses(binary_to_list(Base)),
    Fails3 = phase_side_effects(binary_to_list(Base)),

    Total = Fails0 + Fails1 + Fails2 + Fails3,
    io:format("~n=== ~s ===~n",
              [case Total of 0 -> "ALL PROBES AGREE"; _ ->
                   lists:flatten(io_lib:format("~p PROBE(S) DISAGREED", [Total])) end]),
    halt(case Total of 0 -> 0; _ -> 1 end).

%% --- phase 1: the control -------------------------------------------------

phase_control(Base) ->
    io:format("~n=== PHASE 1 — CONTROL. A known-bad grammar MUST report 15 r/r ===~n"),
    Bad = replace(Base,
        "binding -> expr '=' expr : bind(line('$2'), '$1', '$3').",
        "binding -> pattern '=' expr : {dbind, line('$2'), '$1', '$3'}."),
    true = (Bad =/= Base),
    {Res, Out} = yecc_run("control", Bad),
    N = count_conflicts(Out),
    io:format("  yecc returned  : ~p~n", [Res]),
    io:format("  conflicts seen : ~p  (F8 recorded 15)~n", [N]),
    case {Res, N} of
        {error, 15} -> io:format("  CONTROL OK — the harness can see a conflict~n"), 0;
        _           -> io:format("  **CONTROL FAILED** — trust nothing below~n"), 1
    end.

%% --- phase 2: the proposed grammar ----------------------------------------

phase_proposed(Base) ->
    io:format("~n=== PHASE 2 — the proposed rule, against that control ===~n"),
    {Res, Out} = yecc_run("proposed", proposed(Base)),
    N = count_conflicts(Out),
    io:format("  yecc returned  : ~p~n", [Res]),
    io:format("  conflicts      : ~p~n", [N]),
    case {Res, N} of
        {ok, 0} -> io:format("  `pattern -> '==' lident` is FREE: one rule, no new token~n"), 0;
        _       -> io:format("  **the rule is NOT free** — 45 becomes a real decision~n"), 1
    end.

%% --- phase 3: where the grammar admits it ---------------------------------

phase_parses(Base) ->
    io:format("~n=== PHASE 3 — asserted by PARSE, per F6.9 ===~n"),
    ok = build("proposed", proposed(Base)),
    Cases = [
     {"clause head, literal relational (ticket 42)", true,
      "module M\nint C(int)\nC(>= 4) -> 1\nC(_) -> 0\n"},
     {"clause head, `==acc` with NO space", true,
      "module M\nint F(int,int)\nF(acc, ==acc) -> 1\nF(_,_) -> 0\n"},
     {"clause head, `== acc` WITH space", true,
      "module M\nint F(int,int)\nF(acc, == acc) -> 1\nF(_,_) -> 0\n"},
     {"switch arm", true,
      "module M\nint F(int,int)\nF(acc,m) -> m switch { == acc => 1, _ => 0 }\n"},
     {"list element (F8.5's reduce)", true,
      "module M\nint F(int,list<int>)\nF(acc,[== acc, ..rest]) -> 1\nF(_,_) -> 0\n"},
     {"record field", true,
      "module M\nint F(int,Thing)\nF(k,{ Kind: == k }) -> 1\nF(_,_) -> 0\n"},
     {"tuple element", true,
      "module M\nint F(int,(int,int))\nF(k,(== k, x)) -> 1\nF(_,_) -> 0\n"},
     {"NESTED at depth - F8 called this unmeasured", true,
      "module M\nint F(int,((Thing),int))\nF(k,({ Kind: == k }, x)) -> 1\nF(_,_) -> 0\n"},
     {"bind position, left of a bare `=` (must NOT parse)", false,
      "module M\nint F(int)\nF(k) -> == k = 1\n"}
    ],
    run_cases("proposed", Cases).

%% --- phase 4: what does NOT come free -------------------------------------

phase_side_effects(Base) ->
    io:format("~n=== PHASE 4 — the two side effects that must not arrive silently ===~n"),
    ok = build("relvar",  proposed_plus(Base, rel_var())),
    ok = build("eqlit",   proposed_plus(Base, eq_lit())),
    F1 = run_cases("proposed", [
     {"`>= acc` runtime-bounded span - NOT admitted", false,
      "module M\nint F(int,int)\nF(acc, >= acc) -> 1\nF(_,_) -> 0\n"},
     {"`== 4` as a 2nd spelling for literal 4 - NOT admitted", false,
      "module M\nint F(int)\nF(== 4) -> 1\nF(_) -> 0\n"}]),
    io:format("  -- and each WOULD work if deliberately added: --~n"),
    F2 = run_cases("relvar", [{"`>= acc` once relational takes a name", true,
      "module M\nint F(int,int)\nF(acc, >= acc) -> 1\nF(_,_) -> 0\n"}]),
    F3 = run_cases("eqlit", [{"`== 4` once `==` takes a literal", true,
      "module M\nint F(int)\nF(== 4) -> 1\nF(_) -> 0\n"}]),
    F1 + F2 + F3.

%% --- grammar fragments ----------------------------------------------------

anchor() -> "guard -> '$empty'            : none.".

rel_lit() ->
    "\n%% ticket 42 - relational patterns, LITERAL operand\n"
    "pattern -> '>=' integer : {p_rel, line('$1'), '>=', value('$2')}.\n"
    "pattern -> '<=' integer : {p_rel, line('$1'), '<=', value('$2')}.\n"
    "pattern -> '>'  integer : {p_rel, line('$1'), '>',  value('$2')}.\n"
    "pattern -> '<'  integer : {p_rel, line('$1'), '<',  value('$2')}.\n".

eq_var() ->
    "%% ticket 45 - the answer\n"
    "pattern -> '==' lident  : {p_eqvar, line('$1'), value('$2')}.\n".

rel_var() ->
    "pattern -> '>=' lident : {p_relvar, line('$1'), '>=', value('$2')}.\n"
    "pattern -> '<=' lident : {p_relvar, line('$1'), '<=', value('$2')}.\n".

eq_lit() ->
    "pattern -> '==' integer : {p_eqlit, line('$1'), value('$2')}.\n".

%% The proposed grammar carries 42's rules too, because `== acc` is defended as
%% the equality member of a family - so the family must be present to measure it.
proposed(Base) -> proposed_plus(Base, "").

%% Extra rules go in at the ANCHOR, never at the end of the file: a .yrl closes
%% with an `Erlang code.` section, and a grammar rule appended after it is not a
%% grammar rule at all. Cost of learning that: one failed run.
proposed_plus(Base, Extra) ->
    replace(Base, anchor(), rel_lit() ++ eq_var() ++ Extra ++ "\n" ++ anchor()).
build(Name, Src) ->
    {ok, _} = yecc_gen(Name, Src),
    {ok, _} = compile:file(Name ++ "_parser.erl", [{outdir, "."}]),
    ensure_lexer(),
    ok.

%% --- machinery ------------------------------------------------------------

yecc_gen(Name, Src) ->
    ok = file:write_file(Name ++ ".yrl", Src),
    yecc:file(Name ++ ".yrl", [{parserfile, Name ++ "_parser.erl"}, {report, true}]).

%% Captures yecc's REPORT, which goes to the group leader, so conflicts can be
%% counted rather than merely seen.
yecc_run(Name, Src) ->
    Self = self(),
    Cap  = spawn(fun() -> capture(Self, []) end),
    Old  = group_leader(),
    group_leader(Cap, self()),
    Res = try yecc_gen(Name, Src) of
              {ok, _}    -> ok;
              {ok, _, _} -> ok;
              _          -> error
          catch _:_ -> error end,
    group_leader(Old, self()),
    Cap ! {done, self()},
    Out = receive {captured, T} -> T after 5000 -> "" end,
    {Res, Out}.

capture(Owner, Acc) ->
    receive
        {io_request, From, Ref, {put_chars, _, Chars}} ->
            From ! {io_reply, Ref, ok}, capture(Owner, [Chars | Acc]);
        {io_request, From, Ref, {put_chars, _, M, F, A}} ->
            From ! {io_reply, Ref, ok},
            capture(Owner, [apply(M, F, A) | Acc]);
        {io_request, From, Ref, _} ->
            From ! {io_reply, Ref, ok}, capture(Owner, Acc);
        {done, P} ->
            P ! {captured, lists:flatten(lists:reverse(Acc))}
    end.

count_conflicts(Out) ->
    length([x || "Parse action conflict" ++ _ <- tails(Out)]).

tails([])         -> [];
tails(L=[_ | T])  -> [L | tails(T)].

ensure_lexer() ->
    case code:is_loaded(lexer) of
        false ->
            {ok, _} = leex:file("lexer.xrl", [{scannerfile, "lexer.erl"}]),
            {ok, _} = compile:file("lexer.erl", [{outdir, "."}]),
            code:add_patha("."), ok;
        _ -> ok
    end.

run_cases(Variant, Cases) ->
    P = list_to_atom(Variant ++ "_parser"),
    code:add_patha("."),
    lists:foldl(fun({Label, Must, Src}, Acc) ->
        Got = case lexer:string(Src) of
                  {ok, Toks, _} -> case P:parse(Toks) of {ok,_} -> true; _ -> false end;
                  _             -> false
              end,
        {V, D} = case Got =:= Must of true -> {"ok", 0}; false -> {"**DISAGREES**", 1} end,
        io:format("  ~-52ts want=~-6ts got=~-6ts ~ts~n",
                  [Label, atom_to_list(Must), atom_to_list(Got), V]),
        Acc + D
      end, 0, Cases).

replace(S, From, To) -> lists:flatten(string:replace(S, From, To)).

work_dir() ->
    D = filename:join("/tmp", "bs45_" ++ integer_to_list(erlang:phash2(make_ref()))),
    ok = filelib:ensure_dir(filename:join(D, "x")),
    D.

%% The script lives at wayfinder/prototypes/, so the repo root is two up. Walking
%% up rather than hard-coding keeps this runnable from a worktree or a clone.
repo_root() ->
    Self = filename:absname(escript:script_name()),
    filename:dirname(filename:dirname(filename:dirname(Self))).
