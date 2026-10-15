# Compile every real program in the repo (aoc/ + compiler/examples non-exemplar and exemplars) with stock and gramA; compare diagnostics and beam code md5.
. /home/user/beam-sharp/artifacts/probes/env.sh
R=/home/user/beam-sharp
o=$(mktemp -d /tmp/v57corp.XXXX)
for dir in $(find $R/aoc $R/compiler/examples -name '*.bs' -printf '%h\n' | sort -u); do
  for v in stock gramA; do
    b=$V57/$v/_build/default/bin/bsc; mkdir -p $o/$v
    out=$("$b" --src-root "$(echo $dir | sed 's#\(.*/examples\).*#\1#; s#\(.*/aoc/[0-9a-z]*\)/.*#\1#')" -o $o/$v "$dir" 2>&1 | sed "s#$o/$v##g" | md5sum | cut -c1-8)
    printf '%s %s diag=%s\n' "${dir#$R/}" $v $out
  done
done > $o/summary.txt
awk '{k=$1; d[k]=d[k]" "$3; c[k]++} END{for(k in d){split(d[k],a," "); print (a[1]==a[2]?"SAME ":"DIFF ") k}}' $o/summary.txt | sort | uniq -c -w4
echo dirs: $(awk '{print $1}' $o/summary.txt | sort -u | wc -l)
# beam code identity
for v in stock gramA; do (cd $o/$v && for f in $(find . -name '*.beam' | sort); do escript /home/user/beam-sharp/artifacts/probes/57_emit.escript . $f 2>/dev/null | tail -1; done) > $o/$v.md5s; done
echo beams stock: $(find $o/stock -name '*.beam' | wc -l) gramA: $(find $o/gramA -name '*.beam'|wc -l)
awk '{print $0}' $o/summary.txt | head -3; echo $o
