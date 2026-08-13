#!/usr/bin/env escript
%%! -pa .
%% Ticket 32: where does the boundary code live?
%%
%% Ticket 15 gives a foreign call a compiler-emitted try-wrapper; ticket 18
%% gives its result a guard. Both need a place, and Gleam's lowering (measured
%% in 32a) picks "erase the declaration, inline at every call site".
%%
%% Emits the same program two ways at N call sites and reports Code chunk size:
%%   (a) declaration IS a function  -> boundary code once, call sites are calls
%%   (b) declaration is ERASED      -> boundary code inlined per call site
%%   (c) baseline, no boundary code -> what Elixir emits
main(_) ->
    io:format("~-6s ~8s ~8s ~8s ~8s ~11s ~11s ~11s~n",
              ["N", "bare", "thin", "wrapped", "inlined",
               "thin-bare", "wrap-thin", "inline-bare"]),
    [measure(N) || N <- [1, 2, 5, 10, 20, 40]],
    ok.

measure(N) ->
    B = size_of(mod(bare, N)),
    T = size_of(mod(thin, N)),
    W = size_of(mod(wrapped, N)),
    I = size_of(mod(inlined, N)),
    io:format("~-6w ~8w ~8w ~8w ~8w ~11w ~11w ~11w~n",
              [N, B, T, W, I, T - B, W - T, I - B]).

size_of(Src) ->
    Name = list_to_atom("probe_" ++ integer_to_list(erlang:unique_integer([positive]))),
    Src1 = re:replace(Src, "MODNAME", atom_to_list(Name), [{return, list}, global]),
    {ok, Toks, _} = erl_scan:string(Src1),
    Forms = split_forms(Toks),
    {ok, _, Bin} = compile:forms(Forms, [binary, return_errors]),
    {ok, {_, [{"Code", Code}]}} = beam_lib:chunks(Bin, ["Code"]),
    byte_size(Code).

split_forms(Toks) -> split_forms(Toks, [], []).
split_forms([], _, Acc) -> lists:reverse(Acc);
split_forms([{dot, _} = D | Rest], Cur, Acc) ->
    {ok, F} = erl_parse:parse_form(lists:reverse([D | Cur])),
    split_forms(Rest, [], [F | Acc]);
split_forms([T | Rest], Cur, Acc) -> split_forms(Rest, [T | Cur], Acc).

mod(Kind, N) ->
    Header = "-module(MODNAME). -export([run/1]).\n",
    Body = string:join([call(Kind, I) || I <- lists:seq(1, N)], ",\n"),
    Helper = case Kind of
                 thin ->
                     %% forwards only: isolates the call-shape saving from the
                     %% boundary code, so `wrapped - thin` is the true cost of
                     %% ticket 15's try and ticket 18's guard.
                     "\nchecked(K, L) -> lists:keyfind(K, 1, L).\n";
                 wrapped ->
                     "\nchecked(K, L) ->\n"
                     "  try lists:keyfind(K, 1, L) of\n"
                     "    R when is_tuple(R) -> {ok, R};\n"
                     "    false -> {ok, false};\n"
                     "    O -> {error, {contract, O}}\n"
                     "  catch C:E -> {error, {foreign_error, C, E}} end.\n";
                 _ -> "\n"
             end,
    Header ++ "run(L) -> [\n" ++ Body ++ "].\n" ++ Helper.

call(bare, I) ->
    "  lists:keyfind(" ++ integer_to_list(I) ++ ", 1, L)";
call(Kind, I) when Kind =:= wrapped; Kind =:= thin ->
    "  checked(" ++ integer_to_list(I) ++ ", L)";
call(inlined, I) ->
    S = integer_to_list(I),
    "  (try lists:keyfind(" ++ S ++ ", 1, L) of\n"
    "     R" ++ S ++ " when is_tuple(R" ++ S ++ ") -> {ok, R" ++ S ++ "};\n"
    "     false -> {ok, false};\n"
    "     O" ++ S ++ " -> {error, {contract, O" ++ S ++ "}}\n"
    "   catch C" ++ S ++ ":E" ++ S ++ " -> {error, {foreign_error, C" ++ S ++ ", E" ++ S ++ "}} end)".
