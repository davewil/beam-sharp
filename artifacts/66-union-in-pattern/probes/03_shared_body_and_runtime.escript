#!/usr/bin/env escript
%% Probe 03: (a) does erlc keep ONE body when the member test is a guard
%% disjunction? Counted as call_ext erlang:phash2 instructions in `erlc -S`
%% output (the body contains exactly B of them). (b) run-time cost, timer:tc,
%% 15 repetitions each, spread reported, variants interleaved to spread drift.
%% Command: escript 03_shared_body_and_runtime.escript   (from this dir)
%% Asserts: behaviour identical to `dup` (inherited from lib_gen use); the
%% body-count figures are read from the asm, not assumed.
main(_) ->
    {ok, lib_gen, B0} = compile:file("lib_gen.erl", [binary, return_errors]),
    {module, lib_gen} = code:load_binary(lib_gen, "lib_gen.erl", B0),
    N = 20, Reps = 25, Outer = 100000,
    io:format("otp ~s, schedulers online ~p, jit=~p~n",
              [erlang:system_info(otp_release), erlang:system_info(schedulers_online),
               erlang:system_info(emu_flavor)]),
    io:format("~nA. body copies in asm (N=~p members; B = phash2 calls in one body)~n", [N]),
    [begin
         Copies = [{V, phash_calls(V, N, B)} || V <- lib_gen:variants()],
         io:format("B=~-3w expected-if-one-body=~-3w  ~p~n", [B, B, Copies])
     end || B <- [1, 8]],
    io:format("~nB. run-time, ~p members, ~p outer iterations x ~p inputs per rep, ~p reps (microseconds)~n",
              [N, Outer, N, Reps]),
    io:format("~-4s ~-13s ~9s ~9s ~9s ~8s~n", ["B","variant","min","median","max","spread%"]),
    [begin
         Mods = [{V, load(V, N, B)} || V <- lib_gen:variants()],
         In = lib_gen:input(N),
         erlang:garbage_collect(),
         Samples = lists:foldl(fun(_, Acc) ->
              lists:foldl(fun({V, Mod}, A2) ->
                   {T, ok} = timer:tc(Mod, bench, [Outer, In]),
                   maps:update_with(V, fun(L) -> [T | L] end, [T], A2)
              end, Acc, Mods)
         end, #{}, lists:seq(1, Reps)),
         [begin
              L = lists:sort(maps:get(V, Samples)),
              Min = hd(L), Max = lists:last(L), Med = lists:nth((Reps+1) div 2, L),
              io:format("~-4w ~-13s ~9w ~9w ~9w ~8.1f~n", [B, V, Min, Med, Max, (Max-Min)*100/Med])
          end || V <- lib_gen:variants()]
     end || B <- [1, 8]],
    ok.

phash_calls(V, N, B) ->
    F = "/tmp/p66_gen3/m.erl", ok = filelib:ensure_dir(F),
    ok = file:write_file(F, lib_gen:source(V, N, B)),
    {ok, m, {m, _, _, Asm, _}} = compile:file(F, [to_asm, binary, return_errors]),
    walk(Asm).

%% count {extfunc,erlang,phash2,1} anywhere in the asm term
walk({extfunc, erlang, phash2, 1}) -> 1;
walk(T) when is_tuple(T) -> walk(tuple_to_list(T));
walk(L) when is_list(L) -> lists:sum([walk(X) || X <- L]);
walk(_) -> 0.

load(V, N, B) ->
    Mod = list_to_atom("m_" ++ atom_to_list(V) ++ "_" ++ integer_to_list(B)),
    Src = re:replace(lib_gen:source(V, N, B), "-module\\(m\\)", "-module(" ++ atom_to_list(Mod) ++ ")", [{return, list}]),
    F = "/tmp/p66_gen3/" ++ atom_to_list(Mod) ++ ".erl", ok = file:write_file(F, Src),
    {ok, Mod, Bin} = compile:file(F, [binary, return_errors]),
    {module, Mod} = code:load_binary(Mod, F, Bin),
    Mod.
