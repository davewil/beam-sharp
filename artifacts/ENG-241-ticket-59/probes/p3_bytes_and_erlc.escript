#!/usr/bin/env escript
%% H3a: a record tag test costs ~+14 bytes of Code, an is_integer ~+3..5 (recorded numbers, OTP 28.5 arm64).
%% H3c: erlc already removes a redundant is_integer from a LOCAL function whose only caller tested it
%%      (beam_ssa_type), but cannot remove a map_get(kind)=:=tag test the same way.
%% H3d: the same is_integer test is KEPT when the callee's argument is an untested list element.
%% Falsifier: H3a numbers differ from those ranges (reported as measured, not forced);
%%            H3c: is_integer survives in the local callee's asm, or the tag test vanishes.
%% Command: escript p3_bytes_and_erlc.escript          Toolchain: OTP 25.3 (apt), NOT the pinned 28.5
-mode(compile).

compile_src(Name, Src, Opts) ->
    Path = filename:join(tmp(), atom_to_list(Name) ++ ".erl"),
    ok = file:write_file(Path, Src),
    {ok, Name, Bin} = compile:file(Path, [binary, return_errors | Opts]),
    {ok, Name, Asm} = compile:file(Path, ['S', binary, return_errors | Opts]),
    {Bin, Asm}.

tmp() -> D = filename:join(os:getenv("TMPDIR", "/tmp"), "p3_" ++ os:getpid()), filelib:ensure_dir(D ++ "/x"), D.

code_size(Bin) -> {ok, {_, [{"Code", C}]}} = beam_lib:chunks(Bin, ["Code"]), byte_size(C).

%% count instructions in the {function, Name, Arity, _, Instrs} entry
count(Asm, F, Pred) ->
    {_, _, _, Fs, _} = Asm,
    case [Is0 || {function, N, _, _, Is0} <- Fs, N =:= F] of
        [Is] -> length([I || I <- Is, is_tuple(I), Pred(I)]);
        []   -> gone                      % callee inlined away entirely
    end.
is_int(I) -> element(1, I) =:= test andalso element(2, I) =:= is_integer.
is_eq(I) -> element(1, I) =:= test andalso element(2, I) =:= is_eq_exact.

main(_) ->
    Hdr = "-module(m).\n-export([pub/1]).\n",
    %% ---- bytes: the guard on a private fn (never inlined, called from an exported driver)
    Variants = [
        {tag_none,  "total(O) -> map_get(total, O).\n"},
        {tag_guard, "total(O) when map_get(kind, O) =:= 'P59.Order' -> map_get(total, O).\n"},
        {int_none,  "total(N) when N >= 9 -> 1;\ntotal(N) when N >= 0, N =< 8 -> 0.\n"},
        {int_guard, "total(N) when is_integer(N), N >= 9 -> 1;\ntotal(N) when is_integer(N), N >= 0, N =< 8 -> 0.\n"}],
    io:format("OTP ~s~n", [erlang:system_info(otp_release)]),
    Mk = fun(V, Body) ->
             Mod = list_to_atom("m_" ++ atom_to_list(V)),
             Src = "-module(" ++ atom_to_list(Mod) ++ ").\n-export([pub/1]).\npub(X) -> total(X).\n" ++ Body,
             {Bin, _} = compile_src(Mod, Src, []),
             {V, code_size(Bin), byte_size(Bin)}
         end,
    R = [Mk(V, B) || {V, B} <- Variants],
    [io:format("BYTES ~-10s Code=~p file=~p~n", [V, C, F]) || {V, C, F} <- R],
    {tag_none, T0, _} = lists:keyfind(tag_none, 1, R), {tag_guard, T1, _} = lists:keyfind(tag_guard, 1, R),
    {int_none, I0, _} = lists:keyfind(int_none, 1, R), {int_guard, I1, _} = lists:keyfind(int_guard, 1, R),
    io:format("DELTA tag guard Code bytes: ~p   (recorded: +14)~n", [T1 - T0]),
    io:format("DELTA is_integer x2 Code bytes: ~p   (recorded: +3..5 each)~n", [I1 - I0]),

    %% ---- H3c: does erlc drop the redundant test in a local callee?
    Int = "-module(c_int).\n-export([f/1]).\nf(N) when is_integer(N) -> g(N).\ng(N) when is_integer(N) -> N + 1.\n",
    Tag = "-module(c_tag).\n-export([f/1]).\nf(O) when map_get(kind, O) =:= t -> g(O).\ng(O) when map_get(kind, O) =:= t -> map_get(v, O).\n",
    Show = fun(Label, Mod, Src, Opts, Pred) ->
               {_, Asm} = compile_src(Mod, Src, Opts),
               io:format("ASM ~-34s  f: ~p test(s)   g: ~p test(s)~n",
                         [Label, count(Asm, f, Pred), count(Asm, g, Pred)])
           end,
    %% the nested case: the callee's argument is a list element no caller tested
    Nest = "-module(c_nest).\n-export([f/1]).\nf([N|_]) -> g(N).\ng(N) when is_integer(N) -> N + 1.\n",
    Show("is_integer, element of a list",  c_nest, Nest, [],            fun is_int/1),
    Show("is_integer, no inline",        c_int, Int, [],                fun is_int/1),
    Show("is_integer, +inline",          c_int, Int, [inline],          fun is_int/1),
    Show("is_integer, {inline_size,0}",  c_int, Int, [{inline_size,0}], fun is_int/1),
    Show("tag test,   no inline",        c_tag, Tag, [],                fun is_eq/1),
    Show("tag test,   +inline",          c_tag, Tag, [inline],          fun is_eq/1).
