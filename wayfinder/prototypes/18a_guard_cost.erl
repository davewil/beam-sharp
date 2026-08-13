%%% PROTOTYPE 18a -- what a defensive guard on an EXPORTED function costs.
%%%
%%% Ticket 18. Evidence for the decision whether beam-sharp's compiler should emit
%%% `when is_integer(A), ...` clauses at exported boundaries. Provenance: local, OTP 28.5
%%% (erts-16.4, compiler 9.0.6). Every number in 18a_guard_cost.md is printed by this file.
%%%
%%% Run (note the module name is a QUOTED ATOM, not a string -- `"18a_guard_cost":go()`
%%% raises badarg, because a leading digit forces the quoting):
%%%   erlc -o /tmp/18a 18a_guard_cost.erl
%%%   erl -noshell -pa /tmp/18a -eval "'18a_guard_cost':go(), halt()."
%%%
%%% go/1 overrides the scratch directory the generated variant modules, their .beam files
%%% and their .S listings are written into (default $TMPDIR/18a_guard_cost):
%%%   erl -noshell -pa /tmp/18a -eval "'18a_guard_cost':go(\"/tmp/scratch\"), halt()."
%%%
%%% Runtime is ~2 minutes, almost all of it in section 2 (the timing loops).
%%%
%%% ---------------------------------------------------------------------------------------
%%% WHAT IS COMPARED, AND WHY IT IS SHAPED THIS WAY
%%%
%%% Every variant module holds EXACTLY ONE exported function plus the two module_info/N that
%%% erlc synthesises. Within a pair the two modules are byte-identical apart from the guard,
%%% including the LENGTH OF THE MODULE NAME -- the name lands in the atom table and in the
%%% CInf chunk, so unequal name lengths would pollute a whole-file byte delta. All modules
%%% are compiled `deterministic` so no timestamp or absolute path varies between runs.
%%% Because the two modules are otherwise identical, the Code-chunk delta IS the function's
%%% own bytecode delta exactly -- it is not an estimate.
%%%
%%% Two controls exist that the brief did not ask for, and both change how the numbers read:
%%%
%%%   1. id/1 (`id(A) -> A.`) is measured alongside add/2. In the guarded add/2 the guard
%%%      feeds proven types into the `+` -- the emitted `gc_bif '+'` carries
%%%      [{tr,{x,0},{t_integer,any}},...] operands that the unguarded module does not have.
%%%      So an add/2 delta is "guard entry cost PLUS whatever body optimisation the guard
%%%      unlocked", not the guard's cost. id/1 has no body to optimise, so it isolates the
%%%      entry cost. Both are reported; neither is labelled as the other.
%%%
%%%   2. v_id_x and v_id_y are two IDENTICAL unguarded id/1 modules under different names.
%%%      They go through the identical generate-compile-drive-time pipeline, and their
%%%      measured difference is this harness's noise floor. A guarded-vs-unguarded delta
%%%      smaller than that floor has not been measured, only bounded.
%%%
%%% Each variant is driven by its OWN generated driver module holding a STATIC remote call
%%% (`call_ext`), because a remote call cannot be inlined or elided across a module boundary
%%% and because dispatching through a variable module name would add dynamic-lookup cost that
%%% swamps what is being measured. The loop argument derives from the counter and the result
%%% is folded into an accumulator that is returned, so nothing in the chain is dead code;
%%% section 2 also runs one pair at N and 2N to show elapsed time tracks N.

-module('18a_guard_cost').
-export([go/0, go/1]).

-include_lib("kernel/include/file.hrl").

-define(BENCH_N,     200000000).   %% ~0.43 s per rep at the ~2.2 ns/call floor measured here
-define(BENCH_REPS,  6).           %% first rep of each variant is discarded as warmup
-define(CODE_COPIES, 100).         %% modules loaded per arm of the erlang:memory(code) probe

%% ===========================================================================================

go() -> go(default_dir()).

go(Dir) ->
    ok = filelib:ensure_dir(filename:join(Dir, "keep")),
    true = code:add_patha(Dir),
    banner("PROTOTYPE 18a -- cost of a defensive guard on an exported function"),
    io:format("~s~n", [erlang:system_info(system_version)]),
    io:format("OTP release        : ~s~n", [erlang:system_info(otp_release)]),
    io:format("compiler version   : ~s~n", [compiler_version()]),
    io:format("scratch directory  : ~s~n", [Dir]),
    io:format("compile options    : ~p~n", [copts(Dir)]),
    Built = build_variants(Dir),
    section_1_size(Dir, Built),
    section_2_time(Dir, Built),
    section_3_violation(),
    section_4_elision(Dir),
    section_5_code_memory(Dir),
    banner("end"),
    ok.

default_dir() ->
    Tmp = case os:getenv("TMPDIR") of false -> "/tmp"; D -> D end,
    filename:join(Tmp, "18a_guard_cost").

compiler_version() ->
    _ = application:load(compiler),                    %% not loaded under `erl -noshell`
    {ok, V} = application:get_key(compiler, vsn),
    V.

%% `deterministic` strips the source path and timestamp from CInf, so repeated runs from
%% different directories produce byte-identical .beam files.
copts(Dir) -> [{outdir, Dir}, deterministic, return_errors].

%% ===========================================================================================
%% The variants. Name lengths are equal on purpose (see header).

%% {Key, Shape, ModuleName, FunctionSource}
variants() ->
    [{id_u, id,   "v_id_u", "id(A) -> A."},
     {id_g, id,   "v_id_g", "id(A) when is_integer(A) -> A."},
     {id_x, id,   "v_id_x", "id(A) -> A."},
     {id_y, id,   "v_id_y", "id(A) -> A."},

     {a1_u, add2, "v_a1_u", "add(A, B) -> A + B."},
     {a1_g, add2, "v_a1_g", "add(A, B) when is_integer(A) -> A + B."},

     {a2_u, add2, "v_a2_u", "add(A, B) -> A + B."},
     {a2_g, add2, "v_a2_g", "add(A, B) when is_integer(A), is_integer(B) -> A + B."},

     {a4_u, add4, "v_a4_u", "add(A, B, C, D) -> A + B + C + D."},
     {a4_g, add4, "v_a4_g",
      "add(A, B, C, D) when is_integer(A), is_integer(B), is_integer(C), is_integer(D) ->\n"
      "    A + B + C + D."},

     %% The realistic beam-sharp case: the discriminator is a record/tuple shape, not a
     %% single type test. The unguarded twin still reaches element/2, so it is not a
     %% no-crash baseline -- see section 3.
     {tp_u, tup,  "v_tp_u", "amt(X) -> element(3, X)."},
     {tp_g, tup,  "v_tp_g",
      "amt(X) when is_tuple(X), tuple_size(X) =:= 3, element(1, X) =:= order ->\n"
      "    element(3, X)."}].

%% Shape -> {ExportAttrText, FunName, Arity, CallExprFormat}
shape(id)   -> {"id/1",  id,  1, "~s:id(N)"};
shape(add2) -> {"add/2", add, 2, "~s:add(N, 1)"};
shape(add4) -> {"add/4", add, 4, "~s:add(N, 1, 2, 3)"};
shape(tup)  -> {"amt/1", amt, 1, "~s:amt({order, 1, 2})"}.

%% {Caption, UnguardedKey, GuardedKey}
pairs() ->
    [{"id/1  1 guard (body cannot benefit; isolates entry cost)", id_u, id_g},
     {"id/1  NOISE FLOOR: two identical unguarded modules", id_x, id_y},
     {"add/2 1 guard", a1_u, a1_g},
     {"add/2 2 guards", a2_u, a2_g},
     {"add/4 4 guards", a4_u, a4_g},
     {"amt/1 tuple discriminator (is_tuple+tuple_size+element)", tp_u, tp_g}].

%% ===========================================================================================
%% Generation and compilation

build_variants(Dir) ->
    [begin
         {ExportTxt, Fun, Arity, CallFmt} = shape(Shape),
         Src = io_lib:format("-module(~s).~n-export([~s]).~n~n~s~n", [Mod, ExportTxt, Body]),
         ok = compile_text(Dir, Mod, Src),
         Drv = [$d | tl(Mod)],
         Call = io_lib:format(CallFmt, [Mod]),
         DrvSrc = driver_src(Drv, Call),
         ok = compile_text(Dir, Drv, DrvSrc),
         {module, _} = code:load_file(list_to_atom(Mod)),
         {module, _} = code:load_file(list_to_atom(Drv)),
         {Key, #{mod => Mod, drv => Drv, fun_name => Fun, arity => Arity,
                 shape => Shape, src => lists:flatten(Src)}}
     end
     || {Key, Shape, Mod, Body} <- variants()].

%% The driver holds a static remote call, so the call cannot be inlined away. The `band`
%% keeps the accumulator small (no bignum promotion partway through the run) and costs the
%% same in every driver. Acc is returned, so the chain is live.
driver_src(Drv, Call) ->
    io_lib:format(
      "-module(~s).~n"
      "-export([loop/2]).~n~n"
      "loop(0, Acc) -> Acc;~n"
      "loop(N, Acc) -> loop(N - 1, (Acc + ~s) band 16#FFFF).~n",
      [Drv, Call]).

compile_text(Dir, Mod, Src) ->
    File = filename:join(Dir, Mod ++ ".erl"),
    ok = file:write_file(File, unicode:characters_to_binary(Src)),
    case compile:file(File, copts(Dir)) of
        {ok, _}       -> ok;
        {error, E, W} -> erlang:error({compile_failed, Mod, E, W})
    end.

%% Symbolic assembly for the same source, so the emitted instructions can be quoted exactly.
asm_of(Dir, Mod) ->
    File = filename:join(Dir, Mod ++ ".erl"),
    {ok, _} = compile:file(File, [to_asm | copts(Dir)]),
    {ok, Bin} = file:read_file(filename:join(Dir, Mod ++ ".S")),
    binary_to_list(Bin).

%% Pull one `{function, F, A, _}.` block out of a .S listing.
asm_function(Asm, Fun, Arity) ->
    Head = lists:flatten(io_lib:format("{function, ~s, ~b,", [Fun, Arity])),
    Lines = string:split(Asm, "\n", all),
    Rest = lists:dropwhile(fun(L) -> string:prefix(L, Head) =:= nomatch end, Lines),
    case Rest of
        [] -> "<<function block not found>>";
        [H | T] ->
            Body = lists:takewhile(
                     fun(L) -> string:prefix(L, "{function,") =:= nomatch end, T),
            lists:flatten(lists:join("\n", [H | Body]))
    end.

%% ===========================================================================================
%% Section 1 -- code size

section_1_size(Dir, Built) ->
    banner("1. CODE SIZE"),
    io:format("Chunk byte counts are chunk PAYLOAD (beam_lib), excluding the 8-byte chunk~n"
              "header and 4-byte padding. Because the paired modules are identical apart~n"
              "from the guard, the Code delta is the function's own bytecode delta exactly.~n"
              "`instrs` counts symbolic BEAM instructions in the function under test only~n"
              "(beam_disasm), which is attributable by construction. ImpT is the imported~n"
              "MFA table -- a guard that proves a term's shape lets a CHECKED bif be~n"
              "replaced by an UNCHECKED instruction, dropping the import, which shows here.~n~n"),
    io:format("~-8s ~8s ~8s ~8s ~8s ~8s~n",
              ["module", "file", "Code", "AtU8", "ImpT", "instrs"]),
    io:format("~-8s ~8s ~8s ~8s ~8s ~8s~n",
              ["------", "----", "----", "----", "----", "------"]),
    Sizes =
        maps:from_list(
          [begin
               S = measure_size(Dir, V),
               #{file := F, code := C, atu8 := A, impt := P, instrs := I} = S,
               io:format("~-8s ~8b ~8b ~8b ~8b ~8b~n", [maps:get(mod, V), F, C, A, P, I]),
               {Key, S}
           end || {Key, V} <- Built]),
    io:format("~n~-56s ~14s ~14s ~7s ~7s ~7s~n",
              ["pair", "d_file", "d_Code", "d_AtU8", "d_ImpT", "d_inst"]),
    [begin
         #{file := FU, code := CU, atu8 := AU, impt := PU, instrs := IU} = maps:get(KU, Sizes),
         #{file := FG, code := CG, atu8 := AG, impt := PG, instrs := IG} = maps:get(KG, Sizes),
         io:format("~-56s ~14s ~14s ~7s ~7s ~7s~n",
                   [Cap, pct(FG - FU, FU), pct(CG - CU, CU),
                    signed(AG - AU), signed(PG - PU), signed(IG - IU)])
     end || {Cap, KU, KG} <- pairs()],
    io:format("~ncolumns d_file / d_Code are `+N (+P%)`; the rest are absolute bytes,~n"
              "except d_inst which counts instructions.~n"),

    banner("1b. EMITTED ASSEMBLY FOR EACH PAIR"),
    [begin
         #{mod := MU, fun_name := F, arity := A} = maps:get(KU, maps:from_list(Built)),
         #{mod := MG} = maps:get(KG, maps:from_list(Built)),
         io:format("~n--- ~s ---~n", [Cap]),
         io:format("~n[unguarded ~s]~n~s~n", [MU, asm_function(asm_of(Dir, MU), F, A)]),
         io:format("[guarded   ~s]~n~s~n", [MG, asm_function(asm_of(Dir, MG), F, A)])
     end || {Cap, KU, KG} <- pairs()],
    ok.

measure_size(Dir, #{mod := Mod, fun_name := Fun, arity := Arity}) ->
    Beam = filename:join(Dir, Mod ++ ".beam"),
    {ok, #file_info{size = FileSize}} = file:read_file_info(Beam),
    {ok, {_, Chunks}} = beam_lib:chunks(Beam, ["Code", "AtU8", "ImpT"]),
    Code = byte_size(proplists:get_value("Code", Chunks)),
    AtU8 = byte_size(proplists:get_value("AtU8", Chunks)),
    ImpT = byte_size(proplists:get_value("ImpT", Chunks)),
    {beam_file, _, _, _, _, Fs} = beam_disasm:file(Beam),
    [{function, Fun, Arity, _, Is}] =
        [F || {function, N, A, _, _} = F <- Fs, N =:= Fun, A =:= Arity],
    #{file => FileSize, code => Code, atu8 => AtU8, impt => ImpT, instrs => length(Is)}.

%% ===========================================================================================
%% Section 2 -- call overhead

section_2_time(Dir, Built) ->
    _ = Dir,
    banner("2. CALL OVERHEAD THROUGH THE EXPORTED ENTRY POINT"),
    io:format("N = ~b calls per rep, ~b reps per variant, first rep of each discarded as~n"
              "warmup. Variants are interleaved (U,G,U,G,...) so thermal or scheduler drift~n"
              "hits both arms equally. Figures are ns/call.~n~n",
              [?BENCH_N, ?BENCH_REPS]),
    linearity(Built),
    io:format("~n~-42s ~9s ~9s ~9s~n",
              ["pair (unguarded -> guarded)", "min", "median", "max"]),
    M = maps:from_list(Built),
    [begin
         #{drv := DU} = maps:get(KU, M),
         #{drv := DG} = maps:get(KG, M),
         {Us, Gs} = interleaved(list_to_atom(DU), list_to_atom(DG), ?BENCH_N, ?BENCH_REPS),
         io:format("~n~s~n", [Cap]),
         io:format("  ~-40s ~9.3f ~9.3f ~9.3f~n", ["unguarded " ++ DU,
                                                   lists:min(Us), median(Us), lists:max(Us)]),
         io:format("  ~-40s ~9.3f ~9.3f ~9.3f~n", ["guarded   " ++ DG,
                                                   lists:min(Gs), median(Gs), lists:max(Gs)]),
         io:format("  ~-40s ~9s ~9s~n",
                   ["delta (guarded - unguarded)",
                    fmtd(lists:min(Gs) - lists:min(Us)),
                    fmtd(median(Gs) - median(Us))]),
         io:format("  ~-40s ~9s ~9s~n",
                   ["  as % of unguarded",
                    pctf(lists:min(Gs) - lists:min(Us), lists:min(Us)),
                    pctf(median(Gs) - median(Us), median(Us))]),
         io:format("  raw unguarded: ~s~n", [fmtl(Us)]),
         io:format("  raw guarded  : ~s~n~n", [fmtl(Gs)])
     end || {Cap, KU, KG} <- pairs()],
    ok.

%% Does elapsed time actually track N? If the loop were being optimised away it would not.
linearity(Built) ->
    M = maps:from_list(Built),
    #{drv := D} = maps:get(id_u, M),
    Drv = list_to_atom(D),
    io:format("linearity check on ~s (unguarded id/1):~n", [D]),
    [begin
         {Ns, Elapsed} = timed(Drv, N),
         io:format("  N = ~12b  elapsed = ~9.1f ms  ~7.3f ns/call~n",
                   [N, Elapsed / 1000000, Ns])
     end || N <- [?BENCH_N div 4, ?BENCH_N div 2, ?BENCH_N, ?BENCH_N * 2]],
    ok.

interleaved(DU, DG, N, Reps) ->
    Rs = [{element(1, timed(DU, N)), element(1, timed(DG, N))} || _ <- lists:seq(1, Reps)],
    [_ | Kept] = Rs,                                   %% discard the warmup pair
    {[U || {U, _} <- Kept], [G || {_, G} <- Kept]}.

timed(Drv, N) ->
    T0 = erlang:monotonic_time(nanosecond),
    Acc = Drv:loop(N, 0),
    T1 = erlang:monotonic_time(nanosecond),
    true = is_integer(Acc),                            %% keep the result live
    {(T1 - T0) / N, T1 - T0}.

%% ===========================================================================================
%% Section 3 -- what happens on violation

section_3_violation() ->
    banner("3. WHAT HAPPENS WHEN THE DECLARED TYPE IS VIOLATED"),
    io:format("Raw Erlang caller passes a float where the guard declares an integer.~n"),

    io:format("~n--- 3.1 unguarded  v_a2_u:add(1.0, 3) ---~n"),
    io:format("returns: ~p~n", [v_a2_u:add(1.0, 3)]),

    io:format("~n--- 3.2 guarded    v_a2_g:add(1.0, 3) ---~n"),
    report_violation(fun() -> v_a2_g:add(1.0, 3) end, 1.0),

    io:format("~n--- 3.3 unguarded tuple  v_tp_u:amt({customer, 7}) ---~n"),
    report_violation(fun() -> v_tp_u:amt({customer, 7}) end, {customer, 7}),

    io:format("~n--- 3.4 guarded tuple    v_tp_g:amt({customer, 7}) ---~n"),
    report_violation(fun() -> v_tp_g:amt({customer, 7}) end, {customer, 7}),
    ok.

report_violation(F, Offender) ->
    case catch_it(F) of
        {returned, R} ->
            io:format("no crash. returns: ~p~n", [R]);
        {C, R, S} ->
            io:format("caught class  : ~p~n", [C]),
            io:format("caught reason : ~p~n", [R]),
            io:format("stacktrace    : ~p~n", [S]),
            io:format("top frame     : ~p~n", [hd(S)]),
            io:format("offending arg ~p present in top frame? ~p~n",
                      [Offender, offender_in_frame(hd(S), Offender)]),
            io:format("shell rendering (erl_error:format_exception/3):~n"),
            io:format("~ts~n", [erl_error:format_exception(C, R, S)]),
            %% Deterministic process-exit reason: spawn_monitor, not a race with the logger.
            {Pid, Ref} = spawn_monitor(F),
            Down = receive {'DOWN', Ref, process, Pid, Reason} -> Reason
                   after 5000 -> timeout end,
            io:format("process exit reason (spawn_monitor): ~p~n", [Down])
    end.

catch_it(F) ->
    try F() of R -> {returned, R}
    catch C:R:S -> {C, R, S} end.

offender_in_frame({_M, _F, Args, _Loc}, Offender) when is_list(Args) ->
    case lists:any(fun(A) -> A =:= Offender end, Args) of
        true  -> {yes, Args};
        false -> {no, {frame_args, Args}}
    end;
offender_in_frame({_M, _F, Arity, _Loc}, _Offender) ->
    {no, {frame_carries_arity_only, Arity}}.

%% ===========================================================================================
%% Section 4 -- is the guard ever elided?

%% The discriminator is exported-vs-local, not local-call-vs-remote-call: a BEAM function has
%% one entry label shared by both call kinds, so an exported function's guard is reachable
%% from outside the module no matter what the in-module callers look like.
elision_modules() ->
    [{"e_ex", "exported guarded f/1, called locally with a PROVEN integer",
      "-export([f/1, caller/1]).\n\n"
      "f(A) when is_integer(A) -> A + 1.\n\n"
      "caller(X) when is_integer(X) -> f(X)."},
     {"e_lo", "local-only guarded f/1, called with a PROVEN integer",
      "-export([caller/1]).\n\n"
      "f(A) when is_integer(A) -> A + 1.\n\n"
      "caller(X) when is_integer(X) -> f(X)."},
     {"e_un", "local-only guarded f/1, called with an UNKNOWN-type argument",
      "-export([caller/1]).\n\n"
      "f(A) when is_integer(A) -> A + 1.\n\n"
      "caller(X) -> f(X)."}].

section_4_elision(Dir) ->
    banner("4. IS THE GUARD EVER ELIDED FOR AN INTRA-MODULE CALL?"),
    [begin
         Src = io_lib:format("-module(~s).~n~s~n", [Mod, Body]),
         ok = compile_text(Dir, Mod, Src),
         io:format("~n--- ~s: ~s ---~n", [Mod, Desc]),
         io:format("~s~n", [lists:flatten(Src)]),
         Asm = asm_of(Dir, Mod),
         io:format("~s~n", [strip_prelude(Asm)])
     end || {Mod, Desc, Body} <- elision_modules()],
    ok.

%% Drop the {module,...}/{exports,...}/{attributes,...}/{labels,...} preamble and the two
%% module_info blocks -- only the functions under test are interesting here.
strip_prelude(Asm) ->
    Lines = string:split(Asm, "\n", all),
    Rest = lists:dropwhile(fun(L) -> string:prefix(L, "{function,") =:= nomatch end, Lines),
    Kept = lists:takewhile(
             fun(L) -> string:prefix(L, "{function, module_info") =:= nomatch end, Rest),
    lists:flatten(lists:join("\n", Kept)).

%% ===========================================================================================
%% Section 5 -- loaded code, not disk bytes

%% .beam bytes are not what the guard costs in a running node: the JIT emits native code at
%% load time. This loads ?CODE_COPIES identical modules per arm and reads erlang:memory(code)
%% between arms.
%%
%% The arms ALTERNATE unguarded, guarded, unguarded, guarded. A three-arm U,U,G design cannot
%% tell "this batch is guarded" from "this is the third batch of 100 modules loaded" -- an
%% allocator carrier boundary crossed at batch three looks exactly like a guard cost.
%% Alternating gives two independent U->G steps and two independent same-kind comparisons,
%% so a positional effect and a guard effect are separable. Same-length module names
%% throughout. If the per-arm totals do not repeat by position, no per-module figure should
%% be read out of this probe at all.
section_5_code_memory(Dir) ->
    banner("5. LOADED CODE SIZE (erlang:memory(code)), NOT DISK BYTES"),
    K = ?CODE_COPIES,
    Plain = "id(A) -> A.",
    Guard = "id(A) when is_integer(A) -> A.",
    Arms = [{"a", unguarded, Plain}, {"b", guarded, Guard},
            {"c", unguarded, Plain}, {"d", guarded, Guard}],
    Named = [{Kind, [fmtname("c_" ++ Tag ++ "_~3..0b", I) || I <- lists:seq(0, K - 1)], Src}
             || {Tag, Kind, Src} <- Arms],
    [[ok = compile_text(Dir, M, mk_id_src(M, Src)) || M <- Ms] || {_, Ms, Src} <- Named],
    erlang:garbage_collect(),
    Readings =
        lists:foldl(
          fun({Kind, Ms, _}, Acc) ->
                  Before = erlang:memory(code),
                  [{module, _} = code:load_file(list_to_atom(M)) || M <- Ms],
                  After = erlang:memory(code),
                  [{Kind, Before, After} | Acc]
          end, [], Named),
    Arms1 = lists:reverse(Readings),
    io:format("~b modules per arm, loaded in the order shown.~n~n", [K]),
    io:format("~-6s ~-10s ~12s ~12s ~10s ~12s~n",
              ["arm", "kind", "before", "after", "delta", "delta/module"]),
    [io:format("~-6b ~-10s ~12b ~12b ~10b ~12.1f~n", [N, atom_to_list(Kind), B, A, A - B, (A - B) / K])
     || {N, {Kind, B, A}} <- lists:zip(lists:seq(1, length(Arms1)), Arms1)],
    Ds = [A - B || {_, B, A} <- Arms1],
    [D1, D2, D3, D4] = Ds,
    io:format("~nsame-kind, different position:~n"),
    io:format("  unguarded arm3 - unguarded arm1 : ~s bytes (~s/module)~n",
              [signed(D3 - D1), sgnf((D3 - D1) / K, 1)]),
    io:format("  guarded   arm4 - guarded   arm2 : ~s bytes (~s/module)~n",
              [signed(D4 - D2), sgnf((D4 - D2) / K, 1)]),
    io:format("adjacent U->G steps:~n"),
    io:format("  arm2 - arm1 : ~s bytes (~s/module)~n", [signed(D2 - D1), sgnf((D2 - D1) / K, 1)]),
    io:format("  arm4 - arm3 : ~s bytes (~s/module)~n", [signed(D4 - D3), sgnf((D4 - D3) / K, 1)]),
    io:format("~nerlang:memory(code) is a whole-node counter over coarse-grained allocations~n"
              "and includes per-module metadata, not only JIT-emitted instructions. It counts~n"
              "a DIFFERENT thing from the .beam bytes in section 1. Read a per-module guard~n"
              "cost out of it ONLY if the two U->G steps agree with each other AND the two~n"
              "same-kind, different-position comparisons are near zero.~n"),
    ok.

mk_id_src(Mod, Body) ->
    io_lib:format("-module(~s).~n-export([id/1]).~n~n~s~n", [Mod, Body]).

fmtname(Fmt, I) -> lists:flatten(io_lib:format(Fmt, [I])).

%% ===========================================================================================
%% Formatting helpers

banner(S) -> io:format("~n~s~n~s~n", [string:copies("=", 91), S]).

signed(N) when N >= 0 -> lists:flatten(io_lib:format("+~b", [N]));
signed(N)             -> lists:flatten(io_lib:format("~b", [N])).

%% Erlang's io_lib has no `+` flag, so a leading sign is attached by hand.
sgnf(F, Dec) ->
    Sign = case F >= 0 of true -> "+"; false -> "-" end,
    Sign ++ lists:flatten(io_lib:format("~.*f", [Dec, abs(F) * 1.0])).

pct(D, Base) ->
    lists:flatten(io_lib:format("~s (~s%)", [signed(D), sgnf(100 * D / Base, 1)])).

pctf(D, Base) -> sgnf(100 * D / Base, 2) ++ "%".

fmtd(F) -> sgnf(F, 3).

fmtl(L) ->
    lists:flatten(lists:join(" ", [io_lib:format("~.3f", [X]) || X <- L])).

median(L) ->
    S = lists:sort(L),
    N = length(S),
    case N rem 2 of
        1 -> lists:nth(N div 2 + 1, S);
        0 -> (lists:nth(N div 2, S) + lists:nth(N div 2 + 1, S)) / 2
    end.
