-module(bench).
-export([main/0]).
%% Hand-written Erlang with exactly the guard shape bsc emits (see 59-01/out.txt).
%% Called through a local call from a driver loop; the callee is not inlined (no +inline).
-compile({no_auto_inline}).
tag(O)   when map_get('Kind', O) =:= 'T.Order' -> map_get('Total', O).
none(O)  -> map_get('Total', O).
int_g(N) when is_integer(N) -> N + 1.
int_n(N) -> N + 1.
loop_o(_F, _O, 0, Acc) -> Acc;
loop_o(tag, O, I, Acc)  -> loop_o(tag,  O, I-1, Acc + tag(O));
loop_o(none, O, I, Acc) -> loop_o(none, O, I-1, Acc + none(O)).
loop_i(_F, 0, Acc)  -> Acc;
loop_i(g, I, Acc)   -> loop_i(g, I-1, Acc + int_g(I));
loop_i(n, I, Acc)   -> loop_i(n, I-1, Acc + int_n(I)).
-define(N, 20000000).
run(Name, Fun) ->
    Ts = [element(1, timer:tc(Fun)) || _ <- lists:seq(1, 9)],
    S = lists:sort(Ts),
    Med = lists:nth(5, S), Min = hd(S), Max = lists:last(S),
    io:format("~-22s min=~7.2f ns/call  median=~7.2f  max=~7.2f  (N=~p, 9 runs)~n",
              [Name, Min*1000/?N, Med*1000/?N, Max*1000/?N, ?N]),
    Min*1000/?N.
main() ->
    O = #{'Kind' => 'T.Order', 'Id' => 1, 'Total' => 7},
    io:format("OTP ~s, JIT=~p~n", [erlang:system_info(otp_release), erlang:system_info(emu_flavor)]),
    A = run("record, no tag test", fun() -> loop_o(none, O, ?N, 0) end),
    B = run("record, tag test",    fun() -> loop_o(tag,  O, ?N, 0) end),
    C = run("int, no is_integer",  fun() -> loop_i(n, ?N, 0) end),
    D = run("int, is_integer",     fun() -> loop_i(g, ?N, 0) end),
    io:format("tag test delta (min-to-min): ~.2f ns/call; is_integer delta: ~.2f ns/call~n", [B-A, D-C]),
    A2 = run("record, no tag (rerun)", fun() -> loop_o(none, O, ?N, 0) end),
    io:format("noise floor: same code twice differs by ~.2f ns/call~n", [abs(A2-A)]).
