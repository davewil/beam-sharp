cd "$(dirname "$0")"
for f in 0*.sh 1*.sh; do n=${f%.sh}; bash $f > $n.out 2>&1; echo "$f exit=$?" >> status.txt; done
echo DONE >> status.txt
