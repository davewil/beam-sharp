#!/usr/bin/env bash
# 04 -- the same programs through base / g1 / g1b / c1 / c2. Rows are refinement
# predicates (declared, then used by an identity function) and then programs.
# Each expectation is what the variant's DESIGN predicts, written BEFORE the
# run; REFUTED means the design did not do what it was meant to.
#   g1  : -N is the literal everywhere (refinement, guard, expression)
#   g1b : -N is the literal under a refinement only
#   c1  : checker folds constants in comparison/1 (guard AND refinement)
#   c2  : c1 + the type of `-N` as an expression
# A fold that "stops" is a row expected `refused` under every variant.
. "$(dirname "$0")/lib.sh"
mk () { printf 'type T = int where %s\npublic int Id(T b)\nId(b) -> b' "$1"; }
printf '%-34s %-9s %-9s %-9s %-9s %-9s\n' "refinement predicate" base g1 g1b c1 c2
row () { # predicate, then expectations for base g1 g1b c1 c2
    local pred=$1; shift; local cells="" i=0 exp
    for v in base g1 g1b c1 c2; do
        probe $v T "$(mk "$pred")"; exp=$1; shift
        if [ "$verdict" = "$exp" ]; then cells="$cells $(printf '%-9s' "$verdict")"; else cells="$cells $(printf '%-9s' "$verdict!=$exp")"; fi
    done
    printf '%-34s%s\n' "$pred" "$cells"
}
A=accepted; R=refused
#   predicate                          base g1 g1b c1 c2
row 'value >= -5'                      $R $A $A $A $A
row 'value >= -5 and value <= 5'       $R $A $A $A $A
row 'value >= 1 or value <= -1'        $R $A $A $A $A
row '-5 <= value'                      $R $A $A $A $A
row 'value != -3'                      $R $A $A $A $A
row 'value > -3 and value < 0'         $R $A $A $A $A
row 'value >= -(5)'                    $R $A $A $A $A
row 'value >= - 5'                     $R $A $A $A $A
row 'value >= --5'                     $R $A $R $A $A
row 'value >= - -5'                    $R $A $R $A $A
row 'value >= 2 + 3'                   $R $R $R $A $A
row 'value >= 0 - 5'                   $R $R $R $A $A
row 'value >= -5 * 2'                  $R $R $R $A $A
row 'value >= 10 / 2'                  $R $R $R $R $R
row 'value >= n'                       $R $R $R $R $R
row 'value >= -n'                      $R $R $R $R $R
row '-value >= 5'                      $R $R $R $R $R
row 'value + 5 >= 0'                   $R $R $R $R $R
row 'value >= 0 and value <= 255'      $A $A $A $A $A
echo
echo "# does the declared domain mean EXACTLY -100..100? (a clause set that covers it exactly must compile;"
echo "# the same set one short must be refused with the missing integer as the residual)"
for v in g1 g1b c1 c2; do
  probe $v Dl 'type Delta = int where value >= -100 and value <= 100
public atom Sign(Delta d)
Sign(>= -100 and <= -1) -> :neg
Sign(0)                 -> :zero
Sign(>= 1 and <= 100)   -> :pos'
  printf '%-4s exact cover of -100..100, no catch-all: %s\n' $v $verdict
  probe $v Ds 'type Delta = int where value >= -100 and value <= 100
public atom Sign(Delta d)
Sign(>= -99 and <= -1) -> :neg
Sign(0)                -> :zero
Sign(>= 1 and <= 100)  -> :pos'
  printf '%-4s one short (-100 missing), expect refused: %s | %s\n' $v $verdict "$(grep -E '^ +Sign\(' "$OUT/cases/$v/Ds.out" | tr -s ' ')"
  probe $v Dc 'type Delta = int where value >= -100 and value <= 100
public atom Sign(Delta d)
Sign(<= -1) -> :neg
Sign(>= 1)  -> :pos
Sign(_)     -> :zero'
  printf '%-4s residual {0} is closed, so `_` must be refused (ticket 12 s2): %s\n' $v $verdict
done
echo
echo "# the guard side (G1 = exhaustive three-clause guard program with negative literals)"
for v in base g1 g1b c1 c2; do
  probe $v G1 'public atom Band(int n)
Band(n) when n >= -5 and n <= 5 -> :mid
Band(n) when n < -5 -> :low
Band(n) when n > 5 -> :high'
  printf '%-5s G1 guard program, no catch-all: %s\n' $v $verdict
done
echo "# AGREEMENT: one program that declares a signed refinement AND guards on the same bound:"
for v in g1 g1b c1 c2; do
  probe $v Ag 'type Delta = int where value >= -100 and value <= 100
public atom Band(Delta d)
Band(d) when d >= -5 and d <= 5 -> :mid
Band(d) when d < -5 -> :low
Band(d) when d > 5 -> :high'
  printf '%-4s refinement -100..100 + guards on -5/5, no catch-all: %s\n' $v $verdict
  sed -n 2,6p "$OUT/cases/$v/Ag.out" | sed 's/^/        /'
done
echo "# guard that stops: a folded 2 + 3 in a guard"
for v in base g1 g1b c1 c2; do
  probe $v Gs 'public atom Band(int n)
Band(n) when n > 2 + 3 -> :high
Band(n) when n <= 5 -> :low'
  printf '%-5s `when n > 2 + 3` exhaustive pair: %s\n' $v $verdict
done
