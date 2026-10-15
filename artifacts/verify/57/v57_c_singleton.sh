. "$(dirname "$0")/v57_lib.sh"
for r in 'value >= 0 and value <= 0' 'value > 4 and value < 6' 'value >= 5 and value <= 5' 'value > -1 and value < 1' 'value >= -5 and value <= -5' 'value == 0' 'value == 5' 'value == -3' 'value >= -3 and value <= -3'; do
 cmp_src "T: $r" "type T = int where $r"$'\npublic atom F(T t)\nF(t) -> :a'
done
