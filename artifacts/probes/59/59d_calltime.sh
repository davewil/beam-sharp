#!/usr/bin/env bash
# 59d — CLAIM (ticket 59 "What this owes" 3): the tag test and is_integer cost "below ±0.09
# ns/call resolution" so cost is not an argument either way. Re-measured with a timer:tc
# loop through the exported ViaList / ViaInts of src/Forge/forge.bs, which call the private
# Total (tag test) / Plus1 (kind test) once per list element on a 1000-element list.
# Variants cur / narrow / widen from lib.sh. Each round runs every variant once in a fresh
# order-rotated sequence; R rounds; reports min and median ns per private call.
# NOISE FLOOR / CONTROL: `cur2` is a second compile of the SAME compiler — the cur-vs-cur2
# spread is the noise floor; a delta is only real if it exceeds it.
# Machine: whatever this runs on (a shared Firecracker VM); read the numbers as relative only.
set -uo pipefail
source "${ENV_SH:-/tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh}"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
export ERL_CRASH_DUMP=/dev/null
cd "$REPO"; build_variants
R=${R:-9}
for v in cur cur2 narrow widen; do
  src=$v; [ $v = cur2 ] && { src=cur; }
  mkdir -p "$WORK/b_$v"; bsc_v $src "$PROBE/src" "$WORK/b_$v" "$PROBE/src/Forge" >/dev/null
done
cat > "$WORK/bench.erl" <<'ERL'
-module(bench).
-export([main/1]).
-define(LEN, 1000).
-define(REPS, 3000).
run(Dir, Fn, Arg) ->
  code:purge('Forge'), code:delete('Forge'), code:purge('Forge'),
  {module,'Forge'} = code:load_abs(filename:join(Dir,"Forge")),
  _ = [apply('Forge',Fn,[Arg]) || _ <- lists:seq(1,200)],             % warm
  {T,_} = timer:tc(fun() -> loop(?REPS, Fn, Arg) end),
  T*1000/(?REPS*?LEN).                                                 % ns per private call
loop(0,_,_) -> ok;
loop(N,Fn,A) -> 'Forge':Fn(A), loop(N-1,Fn,A).
main(Args) ->
  Dirs = [{list_to_atom(V),D} || A <- Args, [V,D] <- [string:split(A,"=")]],
  Ord = #{'Kind'=>'Forge.Order','Id'=>1,'Total'=>5},
  Lists = #{'ViaList' => lists:duplicate(?LEN, Ord), 'ViaInts' => lists:seq(1,?LEN)},
  R = list_to_integer(os:getenv("R")),
  Res = [{Fn, V, [begin
         Rot = rotate(Dirs, I), {_,D} = lists:keyfind(V,1,Rot), run(D, Fn, maps:get(Fn,Lists)) end || I <- lists:seq(1,R)]}
         || Fn <- ['ViaList','ViaInts'], {V,_} <- Dirs],
  [begin S = lists:sort(Ts), Med = lists:nth((length(S)+1) div 2, S),
     io:format("~-8s ~-6s min ~7.3f  median ~7.3f  max ~7.3f ns/call~n",[Fn,V,hd(S),Med,lists:last(S)]) end || {Fn,V,Ts} <- Res].
rotate(L,I) -> {A,B} = lists:split(I rem length(L), L), B++A.
ERL
erlc -o "$WORK" "$WORK/bench.erl"
echo "OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().') JIT=$(erl -noshell -eval 'io:format("~p",[erlang:system_info(emu_flavor)]),halt().') schedulers_online=$(nproc)"
R=$R erl -noshell +S 1 -pa "$WORK" -eval 'bench:main(init:get_plain_arguments()), halt().' -extra $(for v in cur cur2 narrow widen; do echo "$v=$WORK/b_$v"; done)
