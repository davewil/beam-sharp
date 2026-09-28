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
    G = fun(true, Test) -> " when " ++ Test; (false, _) -> "" end,
    lists:flatten(io_lib:format(
      "-module(~s).\n"
      "-export([top/1, nested/1, escape/0, many/1, top_i/1, nested_i/1, escape_i/0, many_i/1, consume/1]).\n"
      "top(O) when " ?TAG " -> p(O).\n"
      "nested(W) when " ?TAGW " -> p(erlang:map_get(order, W)).\n"
      "escape() -> fun p/1.\n"
      "many(L) when erlang:is_list(L) -> lists:map(fun p/1, L).\n"
      "p(O)~s -> ~s.\n"
      "consume({kept, O}) -> erlang:map_get(total, O).\n"
      "top_i(N) when erlang:is_integer(N) -> q(N).\n"
      "nested_i(W) when " ?TAGW " -> q(erlang:map_get(count, W)).\n"
      "escape_i() -> fun q/1.\n"
      "many_i(L) when erlang:is_list(L) -> lists:map(fun q/1, L).\n"
      "~s\n",
      [Mod, G(PGuard, ?TAG), PBody, qclauses(QGuard, QBody)])).

qclauses(Guard, arith) ->
    G = case Guard of true -> " when erlang:is_integer(N)"; false -> "" end,
    "q(N)" ++ G ++ " -> N * 2.";
qclauses(Guard, classify) ->
    G = case Guard of true -> " andalso erlang:is_integer(N)"; false -> "" end,
    %% clause 1 mirrors Classify(>= 9): a relational pattern pins no kind (F24), so the kind test is owed
    "q(N) when N >= 9" ++ G ++ " -> reserved;\nq(N)" ++
        (case Guard of true -> " when erlang:is_integer(N)"; false -> "" end) ++ " -> low.".

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

is_hole_mod(M) -> lists:member(M, [h_bodyproj_off, h_bodyproj_on, h_bodycmp_off, h_bodycmp_on,
                                   h_bodykeep_off, h_bodykeep_on, hi_arith_off, hi_arith_on,
                                   hi_classify_off, hi_classify_on]).
arity(A) when is_integer(A) -> A;
arity(L) when is_list(L) -> length(L).
short({badkey, _}) -> "badkey";
short(R) when is_atom(R) -> atom_to_list(R);
short({R, _}) when is_atom(R) -> atom_to_list(R);
short(R) -> io_lib:format("~w", [R]).

go() ->
    io:format("OTP ~s erts ~s~n", [erlang:system_info(otp_release), erlang:system_info(version)]),
    io:format("~nlegend: `private guard off -> X | on -> Y`; ok:V is a value RETURNED with no error (the silent case).~n"),
    io:format("exported guard is always on (tag test / is_integer), as bs_emit emits it on an exported parameter.~n"),
    Bodies = [{proj, "erlang:map_get(total, O)"},
              {cmp,  "erlang:map_get(status, O) =:= draft"},
              {keep, "{kept, O}"}],
    lists:foreach(
      fun({BN, Body}) ->
              Off = list_to_atom("h_body" ++ atom_to_list(BN) ++ "_off"),
              On  = list_to_atom("h_body" ++ atom_to_list(BN) ++ "_on"),
              ok = build(Off, false, Body, false, arith),
              ok = build(On,  true,  Body, false, arith),
              io:format("~n=== RECORD private p(Order o), body = ~s ===~n", [BN]),
              lists:foreach(
                fun(Path) ->
                        lists:foreach(
                          fun({FN, Forged}) ->
                                  R = fun(Mod) -> rec_call(Mod, Path, Forged) end,
                                  io:format("  ~-7s ~-24s off -> ~s | on -> ~s~n",
                                            [Path, FN, pad(show(fun() -> R(Off) end)), show(fun() -> R(On) end)])
                          end, rec_forgeries()),
                        io:format("  ~-7s ~-24s off -> ~s | on -> ~s~n",
                                  [Path, "GOOD record (control)", pad(show(fun() -> rec_call(Off, Path, good_rec()) end)),
                                   show(fun() -> rec_call(On, Path, good_rec()) end)])
                end, [top, nested, escape, many])
      end, Bodies),
    %% H4: where does a kept forged record finally blow up?
    io:format("~n=== 'keep' body: the forged record is stored, and used later by consume/1 ===~n"),
    F1 = maps:get(wrong_kind_same_fields, maps:from_list(rec_forgeries())),
    F2 = maps:get(right_tag_no_fields, maps:from_list(rec_forgeries())),
    lists:foreach(
      fun({FN, Forged}) ->
              Later = fun(Mod) -> fun() ->
                                          {kept, X} = (Mod:escape())(Forged),
                                          Mod:consume({kept, X}) end end,
              io:format("  ~-24s guard off -> ~s | on -> ~s~n",
                        [FN, pad(show(Later(h_bodykeep_off))), show(Later(h_bodykeep_on))])
      end, [{wrong_kind_same_fields, F1}, {right_tag_no_fields, F2}, {non_map, 42}, {no_kind_key, maps:get(no_kind_key, maps:from_list(rec_forgeries()))}]),
    %% INT
    lists:foreach(
      fun({QN, QB}) ->
              Off = list_to_atom("hi_" ++ atom_to_list(QN) ++ "_off"),
              On  = list_to_atom("hi_" ++ atom_to_list(QN) ++ "_on"),
              ok = build(Off, false, "ok", false, QB),
              ok = build(On,  false, "ok", true, QB),
              io:format("~n=== INT private q(int n), body = ~s ===~n", [QN]),
              lists:foreach(
                fun(Path) ->
                        lists:foreach(
                          fun({FN, Forged}) ->
                                  R = fun(Mod) -> int_call(Mod, Path, Forged) end,
                                  io:format("  ~-7s ~-8s off -> ~s | on -> ~s~n",
                                            [Path, FN, pad(show(fun() -> R(Off) end)), show(fun() -> R(On) end)])
                          end, int_forgeries()),
                        io:format("  ~-7s ~-8s off -> ~s | on -> ~s~n",
                                  [Path, "GOOD 21", pad(show(fun() -> int_call(Off, Path, 21) end)),
                                   show(fun() -> int_call(On, Path, 21) end)])
                end, [top, nested, escape, many])
      end, [{arith, arith}, {classify, classify}]),
    ok.

rec_call(M, top, X)    -> M:top(X);
rec_call(M, nested, X) -> M:nested(#{'Kind' => 'Wrapper', order => X});
rec_call(M, escape, X) -> (M:escape())(X);
rec_call(M, many, X)   -> M:many([good_rec(), X]).

int_call(M, top, X)    -> M:top_i(X);
int_call(M, nested, X) -> M:nested_i(#{'Kind' => 'Wrapper', count => X});
int_call(M, escape, X) -> (M:escape_i())(X);
int_call(M, many, X)   -> M:many_i([21, X]).

pad(S) -> string:pad(lists:flatten(S), 56, trailing).
