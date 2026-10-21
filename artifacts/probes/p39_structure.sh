#!/usr/bin/env bash
# Ticket 39 §1/§3.1: is the emitted code really instruction-identical, and do both beams carry the same
# type information the JIT reads? Compares the `Type` chunk byte for byte and the disassembled hot functions
# (labels renumbered, atoms of the function name normalised).
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
cat > $PROBE_HOME/p39s.escript <<'X'
#!/usr/bin/env escript
main([A, B]) ->
    {ok, {_, [{"Type", TA}]}} = beam_lib:chunks(A, ["Type"]),
    {ok, {_, [{"Type", TB}]}} = beam_lib:chunks(B, ["Type"]),
    io:format("Type chunk: ~p bytes vs ~p bytes, byte-identical: ~p~n", [byte_size(TA), byte_size(TB), TA =:= TB]),
    {beam_file, _, _, _, _, DA} = beam_disasm:file(A),
    {beam_file, _, _, _, _, DB} = beam_disasm:file(B),
    Norm = fun(Is) -> [norm(I) || I <- Is, element(1, I) =/= label, element(1, I) =/= line, element(1, I) =/= func_info] end,
    Pairs = [{spin, 'Spin'}, {wrap, 'Wrap'}, {hit, 'Hit'}, {sign, 'Sign'}, {size_, 'Size'}, {clicks, 'Clicks'}],
    [begin
         FA = [Norm(Is) || {function, N, _, _, Is} <- DA, N =:= EN],
         FB = [Norm(Is) || {function, N, _, _, Is} <- DB, N =:= BN],
         io:format("~-8s erlang ~3w instrs, beam-sharp ~3w instrs, identical: ~p~n",
                   [EN, length(lists:append(FA)), length(lists:append(FB)), FA =:= FB])
     end || {EN, BN} <- Pairs].
norm({f, _}) -> f;
norm({M, F, A}) when (M =:= bench_erl orelse M =:= 'Day01') andalso is_atom(F) andalso is_integer(A) ->
    {m, list_to_atom(string:lowercase(atom_to_list(F))), A};
norm({atom, A}) when A =:= hit; A =:= 'Hit'; A =:= wrap; A =:= 'Wrap'; A =:= spin; A =:= 'Spin';
                     A =:= sign; A =:= 'Sign'; A =:= size_; A =:= 'Size'; A =:= clicks; A =:= 'Clicks';
                     A =:= bench_erl; A =:= 'Day01' -> fn;
norm(T) when is_tuple(T) -> list_to_tuple([norm(X) || X <- tuple_to_list(T)]);
norm(L) when is_list(L) -> [norm(X) || X <- L];
norm(X) -> X.
X
escript $PROBE_HOME/p39s.escript $PROBE_HOME/b39/ebin/bench_erl.beam $PROBE_HOME/b39/ebin/Day01.beam
