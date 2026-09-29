#!/usr/bin/env escript
%% PROBE 3 — cost of a snake_case alias wrapper beside each PascalCase export.
%% argv: PLAINROOT ALIASROOT   (each holds 1/ 10/ 100/ 1000/ with N<n>.beam)
%% plain = compiler copy with BS_ALIAS unset; alias = same copy with BS_ALIAS=wrapper (alias.patch).
%%
%% EXPECTED (stated before the load-time and call-overhead runs; the .beam byte sizes had been
%% seen once in an exploratory build before this file was written and are NOT independent):
%%   E1 module_info(exports) length: plain = n+3, alias = 2n+3 (n author exports + bs@type_atoms
%%      + module_info/0,1; alias adds exactly n).
%%   E2 .beam bytes: alias/plain between 1.15 and 1.60 for n >= 10.
%%   E3 the alias is ONE extra function and a tail call: beam_disasm of get_item5/1 contains a
%%      call_only (or jump/call_ext_only) to 'GetItem5'/1 and no `call`+`return`/allocate pair.
%%   E4 load time (code:load_binary, 30 runs): alias median > plain median, ratio < 2.0.
%%      RESULT ON FIRST RUN: FAIL at n=1 only (alias/plain 0.94: a ~600 us fixed load cost swamps the
%%      difference, i.e. my 'all n' wording was too broad). E4 is left as pre-stated and stays FAIL.
%%      E4b (POST-HOC, written after seeing that result, not independent): for n >= 100 the ratio
%%      is between 1.1 and 2.0 (n=100) and between 1.3 and 2.0 (n=1000). Three runs so far gave n=100: 1.55, 1.17 and n=1000: 1.59, 1.68 -- load time is noisy.
%%   E5 call overhead of alias over direct (1e7 calls, 7 runs): median extra < 10 ns per call.
%%   E6 alias returns the same value as the PascalCase export for every n.
main([PlainRoot, AliasRoot]) ->
    Ns = [1, 10, 100, 1000],
    Res = [measure(N, PlainRoot, AliasRoot) || N <- Ns],
    io:format("~n~-6s ~10s ~10s ~7s ~8s ~8s ~12s ~12s ~7s~n",
              [n, plain_B, alias_B, ratio, exp_pl, exp_al, load_pl_us, load_al_us, lratio]),
    [io:format("~-6w ~10w ~10w ~7.2f ~8w ~8w ~12w ~12w ~7.2f~n",
               [N, Bp, Ba, Ba/Bp, Ep, Ea, Lp, La, La/Lp]) || {N, Bp, Ba, Ep, Ea, Lp, La} <- Res],
    Dis = disasm(AliasRoot),
    Call = calls(PlainRoot, AliasRoot),
    E1 = lists:all(fun({N, _, _, Ep, Ea, _, _}) -> Ep =:= N + 3 andalso Ea =:= 2*N + 3 end, Res),
    E2 = lists:all(fun({N, Bp, Ba, _, _, _, _}) -> N < 10 orelse (Ba/Bp >= 1.15 andalso Ba/Bp =< 1.60) end, Res),
    E3 = Dis,
    E4 = lists:all(fun({_, _, _, _, _, Lp, La}) -> La > Lp andalso La/Lp < 2.0 end, Res),
    E4b = lists:all(fun({N, _, _, _, _, Lp, La}) -> R = La/Lp, (N < 100) orelse (N =:= 100 andalso R >= 1.1 andalso R < 2.0) orelse (N =:= 1000 andalso R >= 1.3 andalso R < 2.0) end, Res),
    {E5, E6} = Call,
    [io:format("~s ~s~n", [K, case V of true -> "PASS"; false -> "FAIL" end])
     || {K, V} <- [{"E1 export table", E1}, {"E2 bytes ratio", E2}, {"E3 tail call", E3},
                   {"E4 load slower<2x (pre-stated, all n)", E4}, {"E4b n=100 1.1-2.0, n=1000 1.3-2.0 (post-hoc)", E4b}, {"E5 call <10ns", E5}, {"E6 same values", E6}]],
    io:format("~s p3~n", [case lists:all(fun(X) -> X end, [E1,E2,E3,E4,E5,E6]) of true -> "PASS"; false -> "FAIL" end]).

load_mod(Mod, Root, N) ->
    F = filename:join([Root, integer_to_list(N), atom_to_list(Mod) ++ ".beam"]),
    {ok, Bin} = file:read_file(F),
    {Mod, F, Bin}.

median(L) -> S = lists:sort(L), lists:nth((length(S) + 1) div 2, S).

measure(N, PR, AR) ->
    Mod = list_to_atom("N" ++ integer_to_list(N)),
    {_, Fp, Bp} = load_mod(Mod, PR, N),
    {_, Fa, Ba} = load_mod(Mod, AR, N),
    Lp = median(times(Mod, Fp, Bp)),
    La = median(times(Mod, Fa, Ba)),
    {module, Mod} = code:load_binary(Mod, Fp, Bp),
    Ep = length(Mod:module_info(exports)),
    code:purge(Mod), code:delete(Mod), code:purge(Mod),
    {module, Mod} = code:load_binary(Mod, Fa, Ba),
    Ea = length(Mod:module_info(exports)),
    code:purge(Mod), code:delete(Mod), code:purge(Mod),
    {N, byte_size(Bp), byte_size(Ba), Ep, Ea, Lp, La}.

times(Mod, F, Bin) ->
    [begin
         code:purge(Mod), code:delete(Mod), code:purge(Mod),
         {T, {module, Mod}} = timer:tc(code, load_binary, [Mod, F, Bin]),
         T
     end || _ <- lists:seq(1, 30)].

disasm(AliasRoot) ->
    F = filename:join([AliasRoot, "10", "N10.beam"]),
    {beam_file, _, _, _, _, Fns} = beam_disasm:file(F),
    [Code] = [C || {function, get_item5, 1, _, C} <- Fns],
    io:format("~nbeam_disasm of get_item5/1 (alias wrapper):~n"),
    [io:format("    ~p~n", [I]) || I <- Code],
    Tail = lists:any(fun({call_only, 1, {_, 'GetItem5', 1}}) -> true;
                        ({call_only, 1, {f, _}}) -> true; ({jump, {f, _}}) -> true; (_) -> false end, Code),
    NoFrame = not lists:any(fun({allocate, _, _}) -> true; ({call, _, _}) -> true; (_) -> false end, Code),
    Tail andalso NoFrame.

calls(PR, AR) ->
    %% 1e7 direct vs alias calls, from a compiled loop so the calls are external calls.
    Dir = filename:dirname(escript:script_name()),
    {ok, p3loop, Bin} = compile:file(filename:join(Dir, "p3loop.erl"), [binary]),
    {module, p3loop} = code:load_binary(p3loop, "p3loop", Bin),
    F = filename:join([AR, "100", "N100.beam"]),
    {ok, B} = file:read_file(F),
    {module, 'N100'} = code:load_binary('N100', F, B),
    Same = lists:all(fun(I) -> 'N100':get_item5(I) =:= 'N100':'GetItem5'(I) end, lists:seq(0, 50)),
    NCalls = 10000000,
    Runs = [begin
                {Td, _} = timer:tc(p3loop, direct, [NCalls, 3]),
                {Ta, _} = timer:tc(p3loop, alias, [NCalls, 3]),
                {Te, _} = timer:tc(p3loop, empty, [NCalls, 3]),
                {Td * 1000 / NCalls, Ta * 1000 / NCalls, Te * 1000 / NCalls}
            end || _ <- lists:seq(1, 8)],
    Rs = tl(Runs),   %% first run is a warm-up
    Dd = [D || {D, _, _} <- Rs], Aa = [A || {_, A, _} <- Rs], Ee = [E || {_, _, E} <- Rs],
    Extra = [A - D || {D, A, _} <- Rs],
    io:format("~ncall cost, ns per call over 1e7 calls, 7 runs (after 1 warm-up), OTP ~s ~p:~n",
              [erlang:system_info(otp_release), erlang:system_info(emu_flavor)]),
    io:format("    empty loop (abs/1)  min ~.2f median ~.2f~n", [lists:min(Ee), median(Ee)]),
    io:format("    direct 'GetItem5'   min ~.2f median ~.2f~n", [lists:min(Dd), median(Dd)]),
    io:format("    alias  get_item5    min ~.2f median ~.2f~n", [lists:min(Aa), median(Aa)]),
    io:format("    alias - direct      min ~.2f median ~.2f max ~.2f~n", [lists:min(Extra), median(Extra), lists:max(Extra)]),
    {median(Extra) < 10.0, Same}.
