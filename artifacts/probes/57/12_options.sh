#!/usr/bin/env bash
# 12 -- the three B# programs printed in the brief's Options section, compiled
# whole under every variant. The brief says each compiles under its own option
# and is refused under at least one other. REFUTES that sentence: an option's
# program being REFUSED under its own variant, or ACCEPTED under every variant.
. "$(dirname "$0")/lib.sh"
progA='type Delta = int where value >= -100 and value <= 100
type Nz    = int where value != 0

int Step(Nz n)
Step(n) -> n

public atom Band(int n)
Band(n) when n >= -5 and n <= 5 -> :mid
Band(n) when n < -5             -> :low
Band(n) when n > 5              -> :high

public int Back()
Back() -> Step(-5)'
progB='type Delta = int where value >= -100 and value <= 100
type Hi    = int where value >= 2 + 3
type Lo    = int where value >= 0 - 5 * 2

public atom Band(int n)
Band(n) when n > 2 + 3 -> :high
Band(n) when n <= 5    -> :low'
progC1='type Delta = int where value >= -100 and value <= 100
public atom Sign(Delta d)
Sign(>= -100 and <= -1) -> :neg
Sign(0)                 -> :zero
Sign(>= 1 and <= 100)   -> :pos'
progC='type Delta = int where value >= -100 and value <= 100
public atom Band(Delta d)
Band(d) when d >= -5 and d <= 5 -> :mid
Band(d) when d < -5             -> :low
Band(d) when d > 5              -> :high'
printf '%-10s %-9s %-9s %-9s %-9s %-9s\n' program base g1 g1b c1 c2
for P in A B C1 C; do
  eval "src=\$prog$P"; cells=""
  for v in base g1 g1b c1 c2; do probe $v Opt$P "$src"; cells="$cells $(printf '%-9s' $verdict)"; done
  printf '%-10s%s\n' "program $P" "$cells"
done
echo "# separate line: the E7 behaviour change (compiles today, refused under A and c2):"
cells=""; for v in base g1 g1b c1 c2; do probe $v OptDiv 'public int Div(int x)
Div(x) -> x / -0'; cells="$cells $(printf '%-9s' $verdict)"; done; printf '%-10s%s\n' "x / -0" "$cells"
