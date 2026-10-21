#!/usr/bin/env escript
%% 59 / probe 4 — what does ONE private tag test cost on the BEAM?
%% Hand-written Erlang in the exact shape bsc emits (guard `map_get('Kind', O) =:= Tag`), the same
%% function with and without it, default compiler options (as bsc uses). This prices the guard; it does not
%% claim bsc would emit these modules. Bytes: beam size of K private functions. Time: ns per call, best of 7.
main(_) ->
    io:format("OTP ~s~n", [erlang:system_info(otp_release)]),
    int_part(),
    [begin
         P = size_of(mod(false, K)), G = size_of(mod(true, K)),
         io:format("~3p private fns: plain ~5p B, with tag test ~5p B, delta ~4p B (~.1f B per guard)~n", [K, P, G, G-P, (G-P)/K])
     end || K <- [1, 10, 100]],
    N = 50000000, O = #{'Kind' => 'M.Order', 'Id' => 1, 'Total' => 7},
    {Mp, _} = load(mod(false, 1, "mp")), {Mg, _} = load(mod(true, 1, "mg")),   % distinct module names: one name would make both loops run the second body
    Best = fun(F) -> lists:min([element(1, timer:tc(F)) || _ <- lists:seq(1,7)]) end,
    Tp = Best(fun() -> Mp:loop(N, O, 0) end), Tg = Best(fun() -> Mg:loop(N, O, 0) end),
    io:format("~p calls: plain ~p ms, guarded ~p ms, delta ~.3f ns/call (loop overhead included in both)~n",
              [N, Tp div 1000, Tg div 1000, (Tg - Tp) * 1000 / N]).

mod(Guarded, K) -> mod(Guarded, K, "m").
mod(Guarded, K, Name) -> mod(Guarded, K, Name, tag).
mod(Guarded, K, Name, Kind) ->
    G = case {Guarded, Kind} of {true, tag} -> " when map_get('Kind', O) =:= 'M.Order'"; {true, int} -> " when is_integer(O) andalso O >= 0 andalso O =< 255"; {false, _} -> "" end,
    Body = case Kind of tag -> "map_get('Total', O)"; int -> "O" end,
    Fns = [io_lib:format("f~p(O)~s -> ~s.~n", [I, G, Body]) || I <- lists:seq(1, K)],
    Calls = lists:flatten(["+ f" ++ integer_to_list(I) ++ "(O) " || I <- lists:seq(1, K)]),
    lists:flatten(["-module(", Name, ").\n-export([loop/3]).\n", Fns,
        "loop(0, _, Acc) -> Acc;\nloop(N, O, Acc) -> loop(N-1, O, Acc ", Calls, ").\n"]).

forms(Src) -> {ok, T, _} = erl_scan:string(Src), parse(T, []).
parse([], Acc) -> lists:reverse(Acc);
parse(T, Acc) -> {F, R} = lists:splitwith(fun(X) -> element(1, X) =/= dot end, T),
                 {ok, Form} = erl_parse:parse_form(F ++ [hd(R)]), parse(tl(R), [Form | Acc]).
size_of(Src) -> {ok, _, Bin} = compile:forms(forms(Src), [binary]), byte_size(Bin).
load(Src) -> {ok, M, Bin} = compile:forms(forms(Src), [binary]), {module, M} = code:load_binary(M, "m.beam", Bin), {M, Bin}.

%% the int kind+range test (F24 + F37 shape): `is_integer(O) andalso O >= 0 andalso O =< 255`
int_part() ->
    [begin P = size_of(mod(false, K, "m", int)), G = size_of(mod(true, K, "m", int)),
           io:format("int test, ~3p private fns: plain ~5p B, guarded ~5p B, delta ~4p B (~.1f B per guard)~n", [K, P, G, G-P, (G-P)/K]) end || K <- [1, 10, 100]],
    N = 50000000,
    {Mp, _} = load(mod(false, 1, "ip", int)), {Mg, _} = load(mod(true, 1, "ig", int)),
    Best = fun(F) -> lists:min([element(1, timer:tc(F)) || _ <- lists:seq(1,7)]) end,
    Tp = Best(fun() -> Mp:loop(N, 7, 0) end), Tg = Best(fun() -> Mg:loop(N, 7, 0) end),
    io:format("int test, ~p calls: plain ~p ms, guarded ~p ms, delta ~.3f ns/call~n", [N, Tp div 1000, Tg div 1000, (Tg - Tp) * 1000 / N]).
