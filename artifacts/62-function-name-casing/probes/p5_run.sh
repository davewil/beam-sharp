#!/usr/bin/env bash
# Drives probe 5. Run: bash p5_run.sh > p5_measure.out 2>&1
# Asserts (exit 1 otherwise): each built beam exports exactly the expected count;
# plain < tramp <= dup in size for N=1000 (if not, the measurement is suspect and we say so).
set -eu
cd "$(dirname "$0")"
erlc p5_measure.erl
G=$(mktemp -d); trap 'rm -rf "$G"' EXIT
echo "OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')  (bsc compiles with [debug_info]; this probe does too)"
echo
echo "## sizes: whole .beam bytes and chunk bytes (beam_lib:all_chunks)"
erl -noshell -pa . -eval '
  Dir = "'"$G"'",
  Rows = [p5_measure:build(V, N, Dir) || N <- [10,100,1000], V <- [plain, tramp, tramp_spec, dup]],
  [begin
     G = fun(K) -> proplists:get_value(K, Ch, 0) end,
     io:format("N=~-5w ~-10w beam=~-8w ExpT=~-6w AtU8=~-6w Code=~-7w Dbgi=~-7w Attr=~-6w LocT=~-5w StrT=~-4w LitT=~-6w~n",
        [N, V, S, G("ExpT"), G("AtU8"), G("Code"), G("Dbgi"), G("Attr"), G("LocT"), G("StrT"), G("LitT")])
   end || {V, N, S, Ch0} <- Rows, Ch <- [[{Id, Sz} || {Id, Sz} <- Ch0]]],
  halt().' | sed 's/^/  /'
echo
echo "## fresh-VM load: atoms-added, code-memory-delta bytes, load microseconds (median of 15 fresh VMs)"
for N in 10 100 1000; do
  erl -noshell -pa . -eval 'Dir = "'"$G"'", [p5_measure:build(V, '$N', Dir) || V <- [plain,tramp,tramp_spec,dup]], halt().'
  for V in plain tramp tramp_spec dup; do
    : > "$G/runs"
    for i in $(seq 15); do
      erl -noshell -pa . -eval 'p5_measure:load("'"$G/${V}_$N.beam"'"), halt().' >> "$G/runs"
    done
    python3 -I -c '
import sys,statistics as st
rows=[list(map(int,l.split())) for l in open(sys.argv[3]) if l.strip()]
col=lambda k:[r[k] for r in rows]
print("  N=%-5s %-10s atoms+%-5d codemem+%-8d load_us(median)=%-6d exports=%d runs=%d" % (sys.argv[1],sys.argv[2],st.median(col(0)),st.median(col(1)),st.median(col(2)),rows[0][3],len(rows)))' $N $V "$G/runs"
  done
done
echo
echo "## abstract-format export attribute and asm for N=2"
erl -noshell -pa . -eval '
  [begin io:format("~-10w ~p~n", [V, hd(tl(p5_measure:forms(V, 2)))]) end || V <- [plain, tramp]],
  halt().'
cat > "$G/asm.escript" <<'EOS'
#!/usr/bin/env escript
main(_) ->
    code:add_patha("."),
    {ok, _, {_, Exp, _, Fns, _}} = compile:forms(p5_measure:forms(tramp, 1), ['S', binary, report_errors]),
    io:format("asm exports: ~p~n", [Exp]),
    [io:format("~n-- ~p/~p~n~p~n", [N, A, [I || I <- Is, element(1, I) =/= line]]) || {function, N, A, _, Is} <- Fns, N =/= module_info],
    %% assertion: the trampoline body is a tail call, not a copy
    {function, _, _, _, Is} = lists:keyfind(calc_total1, 2, Fns),
    case [I || {call_only, _, _} = I <- Is] of
        [] -> io:format("ASSERT FAIL: alias is not a call_only trampoline~n"), halt(1);
        _  -> io:format("~nASSERT OK: calc_total1/1 compiles to call_only (tail jump)~n")
    end.
EOS
escript "$G/asm.escript"

echo
echo "## assertions"
erl -noshell -pa . -eval '
  Dir = "'"$G"'",
  [{plain,_,P,_},{tramp,_,T,_},{tramp_spec,_,_,_},{dup,_,D,_}] = [p5_measure:build(V, 1000, Dir) || V <- [plain,tramp,tramp_spec,dup]],
  Ok = (P < T) andalso (T < D),
  io:format("N=1000 plain<tramp<dup bytes: ~p < ~p < ~p -> ~p~n", [P, T, D, Ok]),
  halt(case Ok of true -> 0; false -> 1 end).'
