%%% p04_hole -- what a forged value does inside a PRIVATE function, with and without its boundary guard.
%%%
%%% LABEL: MEASURED-on-a-hand-written-analogue (NOT bsc). Analogue assumptions:
%%%   * exported functions carry the guards bs_emit emits on an exported parameter (tag test on a record
%%%     parameter, is_integer on an int parameter) - SOURCE bs_emit.erl:251-275 (guard_one/8);
%%%   * the private function p/1 (record) or q/1 (int) carries the SAME guard or none: that is the
%%%     one variable ("private guard on/off") this ticket is about;
%%%   * a B# body is typed, not guarded (F5: bs_check never guards a body); bodies here are the three
%%%     kinds ticket 46/26 §1 distinguish: proj = projects a field, cmp = only compares, keep = stores/returns it.
%%%   * a record is a map with 'Kind' => Tag (ticket 26 §1); Erlang funs and lists:map stand in for
%%%     F46's `Free` (a private fn returned as a value) and `List.Map(xs, Double/1)` (compiler/features/F46-function-as-a-value.md:65-77,93-98).
%%%
%%% Four ways a value reaches the private function:
%%%   top     exported E(Order o) passes its own guarded parameter straight on
%%%   nested  exported E(Wrapper w) passes w.Order, a field: the exported guard tests w's tag, not w.Order's
%%%   escape  exported returns `fun p/1` (F46), the caller then calls it with anything
%%%   many    exported E(list<Order> os) maps p over the elements: the exported guard cannot test elements
%%%
%%% A THIRD COLUMN ("wrap") was added after the first run of the first two, and its prediction is written here
%%% before its first run: the private function stays UNguarded but the escape site (the place a private fn's
%%% address is taken, bs_emit.erl:1036-1045 for F46's e_fname) hands out a guarded wrapper
%%% `fun(X) when TEST -> p(X) end` instead of `fun p/1`.
%%%   H6. wrap == on for the `escape` and `many` paths (the address is only reachable through the wrapper),
%%%       wrap == off for the `nested` path (a direct private call never crosses an escape site), and
%%%       wrap == off == on for `top` (the exported guard already threw).
%%%
%%% PREDICTIONS (written before the first run):
%%%   H1. top:    identical outcome with the private guard on or off (the exported guard already threw).
%%%               This is the ticket's "dead weight" argument, and it holds on this path.
%%%   H2. nested/escape/many with a WRONG-KIND same-fields record and a projecting body: with the private
%%%       guard OFF it returns the forged value's field silently; ON it is function_clause at p/1.
%%%   H3. a MISSING-fields forgery that wears the right tag passes the tag test, so on = off (badkey).
%%%       The tag test is tier one; only the exact-field-set tier would catch it (26 §1, RECORDED).
%%%   H4. body keep: with guard off the forged record travels and the crash appears in a DIFFERENT
%%%       function (consume/1); with guard on it stops at p/1.
%%%   H5. int: arithmetic body q(N) -> N*2 turns 1.5 into 3.0 silently when the private guard is off (18 outcome 3);
%%%       and an atom crashes in the arithmetic BIF, one frame from q/1 (18 outcome 1).
%%%       comparison body (Classify-like) is silent for a float and an atom either way
%%%       (in Erlang term order an atom is > any number).
-module(p04_hole).
-export([go/0]).

-define(TAG,  "erlang:map_get('Kind', O) =:= 'Order'").
-define(TAGW, "erlang:map_get('Kind', W) =:= 'Wrapper'").

rec_forgeries() ->
    [{wrong_kind_same_fields, #{'Kind' => 'Invoice', id => 1, total => 7, status => draft}},
     {right_tag_no_fields,    #{'Kind' => 'Order'}},
     {non_map,                42},
     {no_kind_key,            #{id => 1, total => 7, status => draft}}].

int_forgeries() -> [{float, 1.5}, {atom, ok}, {binary, <<"7">>}].

good_rec() -> #{'Kind' => 'Order', id => 1, total => 3, status => draft}.

source(Mod, PGuard, PBody, QGuard, QBody) ->
    G = fun(true, Test) -> " when " ++ Test; (_, _) -> "" end,
    %% wrap: p stays unguarded; the escape site hands out a guarded wrapper instead of `fun p/1`
    PFun = case PGuard of wrap -> "fun(O) when " ?TAG " -> p(O) end"; _ -> "fun p/1" end,
    QFun = case QGuard of wrap -> "fun(N) when erlang:is_integer(N) -> q(N) end"; _ -> "fun q/1" end,
    lists:flatten(io_lib:format(
      "-module(~s).\n"
      "-export([top/1, nested/1, escape/0, many/1, top_i/1, nested_i/1, escape_i/0, many_i/1, consume/1]).\n"
      "top(O) when " ?TAG " -> p(O).\n"
      "nested(W) when " ?TAGW " -> p(erlang:map_get(order, W)).\n"
      "escape() -> ~s.\n"
      "many(L) when erlang:is_list(L) -> lists:map(~s, L).\n"
      "p(O)~s -> ~s.\n"
      "consume({kept, O}) -> erlang:map_get(total, O).\n"
      "top_i(N) when erlang:is_integer(N) -> q(N).\n"
      "nested_i(W) when " ?TAGW " -> q(erlang:map_get(count, W)).\n"
      "escape_i() -> ~s.\n"
      "many_i(L) when erlang:is_list(L) -> lists:map(~s, L).\n"
      "~s\n",
      [Mod, PFun, PFun, G(PGuard, ?TAG), PBody, QFun, QFun, qclauses(QGuard, QBody)])).

qclauses(Guard, arith) ->
    G = case Guard of true -> " when erlang:is_integer(N)"; _ -> "" end,
    "q(N)" ++ G ++ " -> N * 2.";
qclauses(Guard, classify) ->
    G = case Guard of true -> " andalso erlang:is_integer(N)"; _ -> "" end,
    %% clause 1 mirrors Classify(>= 9): a relational pattern pins no kind (F24), so the kind test is owed
    "q(N) when N >= 9" ++ G ++ " -> reserved;\nq(N)" ++
        (case Guard of true -> " when erlang:is_integer(N)"; _ -> "" end) ++ " -> low.".

build(Mod, PGuard, PBody, QGuard, QBody) ->
    Dir = "p04_out",
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    File = filename:join(Dir, atom_to_list(Mod) ++ ".erl"),
    ok = file:write_file(File, source(Mod, PGuard, PBody, QGuard, QBody)),
    {ok, _} = compile:file(File, [debug_info, deterministic, {outdir, Dir}, return_errors, nowarn_unused_function]),
    true = code:add_patha(Dir),
    {module, Mod} = code:load_file(Mod),
    ok.

show(F) -> lists:flatten(show1(F)).

show1(F) ->
    try {ok, F()} of
        {ok, V} -> io_lib:format("ok:~w", [V])
    catch
        Class:Reason:St ->
            Where = case [{Fn, A} || {M, Fn, A, _} <- St, is_hole_mod(M)] of
                        [{Fn0, A0} | _] -> io_lib:format("~s/~b", [Fn0, arity(A0)]);
                        [] -> "?"
                    end,
            io_lib:format("~s:~s@~s", [Class, short(Reason), Where])
    end.

is_hole_mod(M) -> lists:prefix("h_body", atom_to_list(M)) orelse lists:prefix("hi_", atom_to_list(M)).
arity(A) when is_integer(A) -> A;
arity(L) when is_list(L) -> length(L).
short({badkey, _}) -> "badkey";
short(R) when is_atom(R) -> atom_to_list(R);
short({R, _}) when is_atom(R) -> atom_to_list(R);
short(R) -> io_lib:format("~w", [R]).

go() ->
    io:format("OTP ~s erts ~s~n", [erlang:system_info(otp_release), erlang:system_info(version)]),
    io:format("~nlegend: three variants of the PRIVATE function, columns  off | on | wrap:~n"
              "  off  = private function unguarded              (the 'narrow' scope)~n"
              "  on   = private function carries the same guard  (the 'widen' scope)~n"
              "  wrap = private function unguarded, but a fun handed out of it is a guarded wrapper (escape-site guard)~n"
              "  ok:V is a value RETURNED with no error (the silent case). Cells are cut at 40 characters.~n"
              "  The exported function is guarded in every variant, as bs_emit emits it on an exported parameter.~n"),
    Bodies = [{proj, "erlang:map_get(total, O)"},
              {cmp,  "erlang:map_get(status, O) =:= draft"},
              {keep, "{kept, O}"}],
    lists:foreach(
      fun({BN, Body}) ->
              Ms = [build_v("h_body" ++ atom_to_list(BN), V, Body, false, arith) || V <- [false, true, wrap]],
              io:format("~n=== RECORD private p(Order o), body = ~s ===~n", [BN]),
              [table_row(Path, FN, [fun() -> rec_call(M, Path, Forged) end || M <- Ms])
               || Path <- [top, nested, escape, many], {FN, Forged} <- rec_forgeries() ++ [{good_control, good_rec()}]]
      end, Bodies),
    io:format("~n=== 'keep' body: the forged record is stored by p and used later by consume/1 (path: escape) ===~n"),
    Ks = [build_v("h_body" ++ "keep", V, "{kept, O}", false, arith) || V <- [false, true, wrap]],
    lists:foreach(
      fun({FN, Forged}) ->
              Later = fun(Mod) -> fun() -> {kept, X} = (Mod:escape())(Forged), Mod:consume({kept, X}) end end,
              table_row(escape_then_consume, FN, [Later(M) || M <- Ks])
      end, [{wrong_kind_same_fields, proplists:get_value(wrong_kind_same_fields, rec_forgeries())},
            {right_tag_no_fields,    proplists:get_value(right_tag_no_fields, rec_forgeries())},
            {non_map, 42},
            {no_kind_key,            proplists:get_value(no_kind_key, rec_forgeries())}]),
    lists:foreach(
      fun({QN, QB}) ->
              Ms = [build_v("hi_" ++ atom_to_list(QN), V, "ok", V, QB) || V <- [false, true, wrap]],
              io:format("~n=== INT private q(int n), body = ~s ===~n", [QN]),
              [table_row(Path, FN, [fun() -> int_call(M, Path, Forged) end || M <- Ms])
               || Path <- [top, nested, escape, many], {FN, Forged} <- int_forgeries() ++ [{good_control, 21}]]
      end, [{arith, arith}, {classify, classify}]),
    ok.

%% Build the module for one variant; the same variant flag drives the record p and the int q.
build_v(Prefix, V, PBody, _, QB) ->
    Mod = list_to_atom(Prefix ++ "_" ++ atom_to_list(V)),
    ok = build(Mod, V, PBody, V, QB),
    Mod.

table_row(Path, FN, Thunks) ->
    Cells = [cut(show(T)) || T <- Thunks],
    io:format("  ~-8s ~-24s ~s~n", [Path, FN, string:join([string:pad(C, 40, trailing) || C <- Cells], " | ")]).

cut(S) when length(S) > 40 -> lists:sublist(S, 37) ++ "...";
cut(S) -> S.

rec_call(M, top, X)    -> M:top(X);
rec_call(M, nested, X) -> M:nested(#{'Kind' => 'Wrapper', order => X});
rec_call(M, escape, X) -> (M:escape())(X);
rec_call(M, many, X)   -> M:many([good_rec(), X]).

int_call(M, top, X)    -> M:top_i(X);
int_call(M, nested, X) -> M:nested_i(#{'Kind' => 'Wrapper', count => X});
int_call(M, escape, X) -> (M:escape_i())(X);
int_call(M, many, X)   -> M:many_i([21, X]).

