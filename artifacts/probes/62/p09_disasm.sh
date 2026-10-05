#!/usr/bin/env bash
# P09: does a thin alias cost a stack frame? Disassemble the real beam (Sz10, BS_ALIAS=thin) with beam_disasm.
# CLAIM: the alias body is a tail call (`call_only`), no `allocate`/`deallocate`/`return` pair, so it adds a jump but no frame.
# REFUTED IF the alias function's instruction list contains `allocate*` or a `call` followed by `return`.
. "$(dirname "$0")/lib.sh"; build_alias_compiler || exit 1
W="$SCRATCH/p09"; rm -rf "$W"; mkdir -p "$W/src" "$W/o"; "$HERE/gen_sz.sh" 3 "$W/src"
BS_ALIAS=thin "$BSC_ALIAS" --src-root "$W/src" -o "$W/o" "$W/src/Sz3" 2>&1 | head -3
erl -noshell -eval '
  {beam_file, _M, _Exp, _Attr, _Ci, Fns} = beam_disasm:file("'"$W"'/o/Sz3.beam"),
  Want = [{function, N, 1} || N <- [score_at1_value, '"'"'ScoreAt1Value'"'"']],
  [begin {function, N, A, E, Code} = F,
         io:format("~n== ~p/~p (entry label ~p)~n", [N, A, E]),
         [io:format("   ~p~n", [I]) || I <- Code] end
   || F = {function, N, A, _, _} <- [{function, Nm, Ar, E, C} || {function, Nm, Ar, E, C} <- Fns],
      lists:member({function, N, A}, Want)],
  Alias = hd([C || {function, score_at1_value, 1, _, C} <- Fns]),
  Frame = lists:any(fun(I) -> element(1, I) =:= allocate orelse element(1, I) =:= allocate_zero orelse element(1, I) =:= allocate_heap end, Alias),
  io:format("~nalias has allocate (a frame)? ~p~n", [Frame]),
  io:format("alias instructions: ~p~n", [[element(1,I) || I <- Alias]]),
  halt().' 2>&1 | head -80
