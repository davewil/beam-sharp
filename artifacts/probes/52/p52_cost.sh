#!/usr/bin/env bash
# Ticket 52. Measurable costs of the two halves: (a) the compile-time lookup, (b) recording provenance in the .beam.
. "$(dirname "$0")/../env.sh"
W=$(mktemp -d); LIBS=$W/libs
echo "--- (a) lookup cost: code:ensure_loaded / code:which for a present module, and 'which application owns this module?' by scanning N installed apps"
for N in 10 60 200; do
  rm -rf $LIBS; mkdir -p $LIBS
  for i in $(seq $N); do d=$LIBS/app$i-1.0.0/ebin; mkdir -p $d; printf '{application, app%s, [{vsn,"1.0.0"},{modules,[m%s]},{registered,[]},{applications,[kernel,stdlib]}]}.\n' $i $i > $d/app$i.app; done
  ERL_LIBS=$LIBS erl -noshell -eval '
    T = fun(F, K) -> {U, _} = timer:tc(fun() -> [F() || _ <- lists:seq(1, K)] end), U / K end,
    W = T(fun() -> code:which(lists) end, 2000),
    Scan = fun() -> [ok || A <- [list_to_atom("app" ++ integer_to_list(I)) || I <- lists:seq(1, '$N')],
                   {ok, _} <- [case code:lib_dir(A) of {error, _} -> error; D -> file:consult(filename:join([D, "ebin", atom_to_list(A) ++ ".app"])) end]] end,
    S = T(Scan, 20),
    io:format("apps=~p  code:which ~.1f us   scan-all-.app-files ~.1f us (~.1f us/app)~n", ['$N', W, S, S / '$N']), halt().'
done
echo "--- (b) beam size: record provenance as a module attribute -bs_needs([{app,Vsn},...])"
erl -noshell -eval '
  {ok, Fs} = file:consult("'"$(dirname "$0")"'/fixtures/uses.abstr"),
  Size = fun(Forms) -> {ok, _, B} = compile:forms(Forms, [debug_info]), byte_size(B) end,
  Base = Size(Fs),
  [M | Rest] = Fs,
  One = Size([M, {attribute, 0, bs_needs, [{demo, "1.2.3"}]} | Rest]),
  Three = Size([M, {attribute, 0, bs_needs, [{demo, "1.2.3"}, {req, "0.7.3"}, {jason, "1.4.4"}]} | Rest]),
  io:format("no attribute ~p B;  1 dependency ~p B (+~p);  3 dependencies ~p B (+~p)~n", [Base, One, One - Base, Three, Three - Base]),
  halt().'
