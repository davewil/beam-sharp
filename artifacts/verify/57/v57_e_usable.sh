# For every refinement the brief marks "accepted" on gramA, USE the type in a function and call it, to see the declaration is not just parsed.
. "$(dirname "$0")/v57_lib.sh"
for r in 'value >= -5' 'value >= -5 and value <= 5' 'value >= 1 or value <= -1' 'value > -1' 'value == -3' 'value != -3' 'value >= - 5' 'value >= -0' 'value >= -100 and value <= 100' '-5 <= value'; do
 cmp_src "use: $r" "type T = int where $r"$'\npublic atom F(T t)\nF(t) -> :a' F -3
done
