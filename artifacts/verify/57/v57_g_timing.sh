# Interleaved CLI wall-clock, n=15 per build, 2 stock rows as noise control; plus in-VM check timing (probes' escript) n=500 x5 repeats.
. /home/user/beam-sharp/artifacts/probes/env.sh
w=$(mktemp -d /tmp/v57t.XXXX); mkdir -p $w/C $w/O
{ echo "module C"; echo "type D = int where value >= 0 and value <= 100"; echo "public atom Cls(D d)"
  for i in $(seq 1 30); do echo "Cls(d) when d >= $i and d < $((i+1)) -> :a$i"; done
  echo "Cls(<= 0) -> :low"; echo "Cls(>= 31) -> :hi"
  echo "public atom Gd(int n)"; for i in $(seq 1 30); do echo "Gd(n) when n == $i -> :g$i"; done; echo "Gd(n) -> :none"; } > $w/C/a.bs
N=15
for v in stock stock2 gramA gramB gramC chk; do : > $w/$v.t; done
for i in $(seq 1 $N); do for v in stock stock2 gramA gramB gramC chk; do
  d=${v%2}; s=$(date +%s%N); $V57/$d/_build/default/bin/bsc -o $w/O $w/C >/dev/null 2>&1; e=$(date +%s%N); echo $(( (e-s)/1000000 )) >> $w/$v.t; done; done
echo "CLI wall ms, n=$N interleaved: min / median"
for v in stock stock2 gramA gramB gramC chk; do sort -n $w/$v.t | awk -v v=$v '{a[NR]=$1} END{printf "%-7s %d / %d\n", v, a[1], a[int((NR+1)/2)]}'; done
echo "in-VM lex+parse n=2000, check n=500 (3 repeats; min/median us)"
for r in 1 2 3; do for v in stock stock gramA gramB gramC chk; do printf 'r%s %-6s ' $r $v; escript /home/user/beam-sharp/artifacts/probes/57_timing.escript $V57/$v/_build/default/lib/bsc/ebin $w/C/a.bs 2000 2>&1 | tail -1; done; done
