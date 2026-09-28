%%% p01_shapes -- code size and guard survival on exported vs local (private) functions.
%%%
%%% LABEL: every number here is MEASURED-on-a-hand-written-analogue. It is NOT a measurement of bsc.
%%% Analogue assumptions (SOURCE: compiler/src/bs_emit.erl):
%%%   * the record tag test is  erlang:map_get('Kind', V) =:= Tag   (bs_emit.erl:576-580, erl_op('==') -> '=:=' at :1306)
%%%   * the kind test is       erlang:is_integer(V)                (bs_emit.erl:488-489)
%%%   * several tests are joined with andalso                       (bs_emit.erl:707-712, erl_op('and') at :1310)
%%%   * a private function is simply left out of -export           (bs_emit.erl:32-35)
%%%   * bsc compiles with [from_abstr, debug_info, ...] (bsc.erl:843); here erlc source with debug_info+deterministic.
%%%   * one guard per clause. Here every function has one clause, so that is one guard total.
%%%
%%% PREDICTIONS (written before the first run):
%%%   P1. On OTP 25 the exported tag test costs about +14 bytes of Code and is_integer about +3..5
%%%       (RECORDED as OTP 28.5 figures in tickets 18/26a). I expect OTP 25 to be within a few bytes.
%%%   P2. A local function whose every caller is proven to pass an integer LOSES its is_integer test
%%%       (RECORDED, 18a section 4b). Unknown caller: test kept.
%%%   P3. The tag test on a local function is NOT removed even when the caller has run the identical tag
%%%       test, because the compiler's type lattice records "is a map", not "the value under key 'Kind'".
%%%       So widening the tag test to private functions costs bytes that BEAM cannot take back.
%%%       A map literal built in the caller with 'Kind' => 'Order' is my second guess for "still kept".
%%%   P4. Exported function: guard always kept, whatever the caller proves.
%%%   P5. (added before the first run of the range rows) a local function whose caller ran the SAME 0..255
%%%       range test loses the whole kind+range guard (the type lattice tracks integer ranges).
%%%
%%% Run: erl -noshell -pa . -eval 'p01_shapes:go(), halt().'   (run.sh does this)
-module(p01_shapes).
-export([go/0]).

-define(TAG,  "erlang:map_get('Kind', O) =:= 'Order'").
-define(TAGW, "erlang:map_get('Kind', W) =:= 'Wrapper'").

go() ->
    Dir = "p01_out",
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    io:format("OTP ~s erts ~s~n", [erlang:system_info(otp_release), erlang:system_info(version)]),
    section_a(Dir),
    section_b(Dir),
    ok.

%% ---------------------------------------------------------------------------
%% A. exported single function: what the guard costs in Code bytes
section_a(Dir) ->
    io:format("~n=== A. exported f/1, Code-chunk bytes (equal-length module names, deterministic) ===~n"),
    Vs = [{"a_nf_x", "f(O) -> erlang:map_get(total, O)."},     % noise floor twin 1
          {"a_nf_y", "f(O) -> erlang:map_get(total, O)."},     % noise floor twin 2
          {"a_tg_u", "f(O) -> erlang:map_get(total, O)."},
          {"a_tg_g", "f(O) when " ?TAG " -> erlang:map_get(total, O)."},
          {"a_in_u", "f(O) -> O + 1."},
          {"a_in_g", "f(O) when erlang:is_integer(O) -> O + 1."},
          {"a_fl_u", "f(O) -> O * 2.0."},
          {"a_fl_g", "f(O) when erlang:is_float(O) -> O * 2.0."},
          {"a_rg_g", "f(O) when erlang:is_integer(O) andalso O >= 0 andalso O =< 255 -> O + 1."},
          {"a_rg_u", "f(O) -> O + 1."}],
    Sizes = [{M, code_bytes(Dir, M, "-export([f/1]).\n" ++ B)} || {M, B} <- Vs],
    [io:format("  ~-8s Code=~b~n", [M, S]) || {M, S} <- Sizes],
    D = fun(G, U) -> proplists:get_value(G, Sizes) - proplists:get_value(U, Sizes) end,
    io:format("  noise floor (nf_y - nf_x)  : ~s~n", [sg(D("a_nf_y", "a_nf_x"))]),
    io:format("  tag test    (tg_g - tg_u)  : ~s   [ticket 26a RECORDED on 28.5: +14]~n", [sg(D("a_tg_g", "a_tg_u"))]),
    io:format("  is_integer  (in_g - in_u)  : ~s   [ticket 18a RECORDED on 28.5: +3..+5]~n", [sg(D("a_in_g", "a_in_u"))]),
    io:format("  is_float    (fl_g - fl_u)  : ~s~n", [sg(D("a_fl_g", "a_fl_u"))]),
    io:format("  int + range 0..255         : ~s~n", [sg(D("a_rg_g", "a_rg_u"))]).

%% ---------------------------------------------------------------------------
%% B. private p/1 called from exported c/1: does the guard on p survive?
section_b(Dir) ->
    io:format("~n=== B. local p/1 behind exported c/1: is the guard on p kept? ===~n"),
    io:format("  columns: Code bytes of module with p guarded / p unguarded, delta, and whether the test survives in p's asm~n"),
    Tag = fun(G) -> case G of
                        true  -> "p(O) when " ?TAG " -> erlang:map_get(total, O).";
                        false -> "p(O) -> erlang:map_get(total, O)."
                    end end,
    Int = fun(G) -> case G of
                        true  -> "p(O) when erlang:is_integer(O) -> O + 1.";
                        false -> "p(O) -> O + 1."
                    end end,
    Rng = fun(G) -> case G of
                        true  -> "p(O) when erlang:is_integer(O) andalso O >= 0 andalso O =< 255 -> O + 1.";
                        false -> "p(O) -> O + 1."
                    end end,
    Cases =
        [%% name,         guard kind, p builder, exported c/1 (the caller), test-to-look-for
         {"int / caller unknown",         int, Int, "c(X) -> p(X).",                                         "is_integer"},
         {"int / caller proved integer",  int, Int, "c(X) when erlang:is_integer(X) -> p(X).",               "is_integer"},
         {"int / caller passes literal",  int, Int, "c(_) -> p(41).",                                         "is_integer"},
         {"range0..255 / caller unknown", rng, Rng, "c(X) -> p(X).",                                         "is_integer"},
         {"range0..255 / caller ran SAME range test", rng, Rng,
          "c(X) when erlang:is_integer(X) andalso X >= 0 andalso X =< 255 -> p(X).",                          "is_integer"},
         {"tag / caller unknown",         tag, Tag, "c(X) -> p(X).",                                         "map_get"},
         {"tag / caller ran SAME tag test", tag, Tag, "c(O) when " ?TAG " -> p(O).",                          "map_get"},
         {"tag / caller built the literal", tag, Tag, "c(T) -> p(#{'Kind' => 'Order', total => T}).",         "map_get"},
         {"tag / nested field of a tagged wrapper", tag, Tag,
          "c(W) when " ?TAGW " -> p(erlang:map_get(order, W)).",                                              "map_get"}],
    lists:foreach(
      fun({Name, _K, P, C, Look}) ->
              Body = fun(G) -> "-export([c/1]).\n" ++ P(G) ++ "\n" ++ C end,
              MG = "b_g", MU = "b_u",
              SG = code_bytes(Dir, MG, Body(true)),
              SU = code_bytes(Dir, MU, Body(false)),
              AsmG = local_fun_asm(Dir, MG, p),
              Kept = count(Look, AsmG) > 0 orelse (Look =:= "map_get" andalso count("is_eq_exact", AsmG) > 0),
              io:format("  ~-42s ~4b / ~4b  delta ~3s  test in p's asm: ~s~n",
                        [Name, SG, SU, sg(SG - SU), case Kept of true -> "KEPT"; false -> "ELIDED" end])
      end, Cases),
    io:format("~n  -- the same shapes when p is EXPORTED (control for P4; caller is c/1 as above) --~n"),
    lists:foreach(
      fun({Name, _K, P, C, Look}) ->
              Body = fun(G) -> "-export([c/1, p/1]).\n" ++ P(G) ++ "\n" ++ C end,
              SG = code_bytes(Dir, "b_g", Body(true)),
              SU = code_bytes(Dir, "b_u", Body(false)),
              AsmG = local_fun_asm(Dir, "b_g", p),
              Kept = count(Look, AsmG) > 0 orelse (Look =:= "map_get" andalso count("is_eq_exact", AsmG) > 0),
              io:format("  ~-42s ~4b / ~4b  delta ~3s  test in p's asm: ~s~n",
                        [Name, SG, SU, sg(SG - SU), case Kept of true -> "KEPT"; false -> "ELIDED" end])
      end, Cases),
    io:format("~n  -- asm of p in the tag/'caller ran SAME tag test' case, p local, guarded --~n"),
    Same = "-export([c/1]).\np(O) when " ?TAG " -> erlang:map_get(total, O).\nc(O) when " ?TAG " -> p(O).",
    _ = code_bytes(Dir, "b_g", Same),
    io:format("~s~n", [local_fun_asm(Dir, "b_g", p)]),
    io:format("  -- asm of p in the int/'caller proved integer' case, p local, guarded --~n"),
    SameI = "-export([c/1]).\np(O) when erlang:is_integer(O) -> O + 1.\nc(X) when erlang:is_integer(X) -> p(X).",
    _ = code_bytes(Dir, "b_g", SameI),
    io:format("~s~n", [local_fun_asm(Dir, "b_g", p)]).

%% ---------------------------------------------------------------------------
compile_mod(Dir, Mod, Body) ->
    Src = lists:flatten(io_lib:format("-module(~s).\n~s\n", [Mod, Body])),
    File = filename:join(Dir, Mod ++ ".erl"),
    ok = file:write_file(File, Src),
    {ok, _} = compile:file(File, [debug_info, deterministic, {outdir, Dir}, return_errors]),
    {ok, _} = compile:file(File, [debug_info, deterministic, 'S', {outdir, Dir}, return_errors]),
    ok.

code_bytes(Dir, Mod, Body) ->
    ok = compile_mod(Dir, Mod, Body),
    {ok, {_, [{"Code", C}]}} = beam_lib:chunks(filename:join(Dir, Mod ++ ".beam"), ["Code"]),
    byte_size(C).

%% The .S text of one function, from "{function, Name," to the next "{function,".
local_fun_asm(Dir, Mod, Name) ->
    {ok, Bin} = file:read_file(filename:join(Dir, Mod ++ ".S")),
    Lines = string:split(binary_to_list(Bin), "\n", all),
    Start = "{function, " ++ atom_to_list(Name) ++ ",",
    take_fun(Lines, Start, false, []).

take_fun([], _, _, Acc) -> string:join(lists:reverse(Acc), "\n");
take_fun([L | Rest], Start, In, Acc) ->
    Starts = lists:prefix("{function, ", L),
    case {In, Starts} of
        {false, true} -> case lists:prefix(Start, L) of
                             true  -> take_fun(Rest, Start, true, [L | Acc]);
                             false -> take_fun(Rest, Start, false, Acc)
                         end;
        {true, true}  -> string:join(lists:reverse(Acc), "\n");
        {true, false} -> take_fun(Rest, Start, true, [L | Acc]);
        {false, false} -> take_fun(Rest, Start, false, Acc)
    end.

sg(N) when N >= 0 -> "+" ++ integer_to_list(N);
sg(N) -> integer_to_list(N).

count(Needle, Hay) -> length(string:split(Hay, Needle, all)) - 1.
