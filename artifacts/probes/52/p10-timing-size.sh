#!/usr/bin/env bash
# P10: compile wall time (N=15 per variant, median / min / max, ms) and .beam size, stock vs prototype 52x.
# Wall time includes VM boot (~dominant). A variant that should differ only by the dependency check is compared with the same
# prototype with BSB_DEP_CHECK=off (control: the check costs nothing if medians overlap within spread).
PROTO=/tmp/bsb_52_x/ebin; STOCK=/tmp/bsbuild/ebin; LIBS=/usr/lib/elixir/lib; N=15
W=$(mktemp -d); cd "$W"
mkdir -p T1 T2 T3
printf 'module T1\npublic int Id(int x)\nId(x) -> x\n' > T1/a.bs                                   # no foreign
printf "module T2\nusing :'Elixir.Enum' {\n    int count(list<term> xs)\n}\npublic int Go(list<term> xs)\nGo(xs) -> :'Elixir.Enum'.count(xs)\n" > T2/a.bs   # foreign, no app
printf "module T3\nusing :'Elixir.Enum' in :elixir {\n    int count(list<term> xs)\n}\npublic int Go(list<term> xs)\nGo(xs) -> :'Elixir.Enum'.count(xs)\n" > T3/a.bs # foreign, app
stats() { sort -n | awk '{a[NR]=$1} END{printf "median=%d min=%d max=%d ms (n=%d)", a[int((NR+1)/2)], a[1], a[NR], NR}'; }
timeit() { # timeit LABEL EBIN DIR [env...]
  local label=$1 ebin=$2 dir=$3; shift 3
  local i; for i in $(seq $N); do
    local s=$(date +%s%N)
    env ERL_LIBS=$LIBS "$@" erl -noshell -pa $ebin -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra -o out_$dir_$i $dir/a.bs >/dev/null 2>&1
    echo $(( ($(date +%s%N) - s) / 1000000 ))
  done | stats | sed "s|^|$(printf '%-44s' "$label") |"; echo
}
timeit "stock  T1 (no foreign)"            $STOCK T1
timeit "stock  T2 (foreign, no app)"       $STOCK T2
timeit "proto  T2 check on"                $PROTO T2
timeit "proto  T2 check off (control)"     $PROTO T2 BSB_DEP_CHECK=off
timeit "proto  T3 check on (in :elixir)"   $PROTO T3
timeit "proto  T3 check off (control)"     $PROTO T3 BSB_DEP_CHECK=off
echo "--- .beam sizes (bytes)"
for v in "stock T1 $STOCK" "stock T2 $STOCK" "proto T2 $PROTO" "proto T3 $PROTO"; do set -- $v
  d=sz_$1_$2; mkdir -p $d; ERL_LIBS=$LIBS erl -noshell -pa $3 -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra -o $d $2/a.bs >/dev/null 2>&1
  printf '%-8s %-3s %s bytes\n' $1 $2 "$(stat -c %s $d/$2.beam)"; done
echo "--- bs@needs/0 as a function: bytes added by T3 over T2 are the 'size of the term a design would add' (here: [elixir])"
echo "--- code:which cost, in-VM: 1000 calls x 20 modules, default path vs path plus every OTP lib dir and elixir (most already present)"
erl -noshell -eval '
Mods=[lists,maps,ssl,crypto,inets,ets,string,binary,file,gen_server,application,public_key,zlib,re,json,epgsql,'"'"'Elixir.Req'"'"',nope1,nope2,nope3],
T=fun(L)-> {US,_}=timer:tc(fun()->[ [code:which(M)||M<-Mods] || _<-lists:seq(1,1000)] end), US/20000 end,
io:format("default path (~p dirs): ~.2f us per code:which~n",[length(code:get_path()),T(x)]),
[code:add_pathz(filename:join("/usr/lib/erlang/lib",D)++"/ebin") || D<-element(2,file:list_dir("/usr/lib/erlang/lib")), true],
code:add_pathz("/usr/lib/elixir/lib/elixir/ebin"),
io:format("path after add_pathz (~p dirs): ~.2f us per code:which~n",[length(code:get_path()),T(x)]), halt().'
