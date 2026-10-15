# Case set shared by 57_stock / 57_variants. Source after env.sh and 57_lib.sh.
# run_cases BSCBIN  -> one line per case: name, accepted|refused, first diagnostic line.
run_cases () {
  local b=$1 t='type T = int where '
  # --- refinement cases (the ticket's table, rows 1-5) -------------------------
  try $b 'R01 value >= -5'                    "${t}value >= -5"
  try $b 'R02 >= -5 and <= 5'                 "${t}value >= -5 and value <= 5"
  try $b 'R03 >= 1 or <= -1'                  "${t}value >= 1 or value <= -1"
  try $b 'R04 <= 3 or >= 10 (control)'        "${t}value <= 3 or value >= 10"
  try $b 'R05 != 0 (control)'                 "${t}value != 0"
  # --- the fold boundary --------------------------------------------------------
  try $b 'R06 value >= -(-5)'                 "${t}value >= -(-5)"
  try $b 'R07 value >= -5 + 10'               "${t}value >= -5 + 10"
  try $b 'R08 value >= 2 + 3'                 "${t}value >= 2 + 3"
  try $b 'R09 value >= 2 * 3'                 "${t}value >= 2 * 3"
  try $b 'R10 value >= 10 % 3'                "${t}value >= 10 % 3"
  try $b 'R11 value >= n (MUST refuse)'       "${t}value >= n"
  try $b 'R12 value >= 5 - value (MUST ref.)' "${t}value >= 5 - value"
  try $b 'R13 5 - value >= 0 (MUST refuse)'   "${t}5 - value >= 0"
  try $b 'R14 -value >= 5 (MUST refuse)'      "${t}-value >= 5"
  try $b 'R15 -5 <= value (flipped)'          "${t}-5 <= value"
  try $b 'R16 value > -1'                     "${t}value > -1"
  try $b 'R17 value == -3'                    "${t}value == -3"
  try $b 'R18 value != -3'                    "${t}value != -3"
  try $b 'R19 value >= - 5 (space)'           "${t}value >= - 5"
  try $b 'R20 value >= -0'                    "${t}value >= -0"
  try $b 'R21 Delta -100..100'                "type Delta = int where value >= -100 and value <= 100"
  try $b 'R22 >=-5 and <=-10 (MUST empty)' "${t}value >= -5 and value <= -10"
  try $b 'R23 value >= -5.0 (float lit)'      "${t}value >= -5.0"
  # --- guards: same expr, same alternatives/1 -----------------------------------
  try $b 'G01 guard n>=-5 / n<-5 (exhaust.)'  $'public atom F(int n)\nF(n) when n >= -5 -> :a\nF(n) when n < -5 -> :b'
  try $b 'G02 guard n>=0 / n<0 (control)'     $'public atom F(int n)\nF(n) when n >= 0 -> :a\nF(n) when n < 0 -> :b'
  try $b 'G03 guard n>=-5 + catch-all n'      $'public atom F(int n)\nF(n) when n >= -5 -> :a\nF(n) -> :b'
  try $b 'G04 guard n>=2+3 / n<5 (exhaust.)'  $'public atom F(int n)\nF(n) when n >= 2 + 3 -> :a\nF(n) when n < 5 -> :b'
  # --- patterns: int_lit rule ---------------------------------------------------
  try $b 'P01 pattern >= -5 / < -5'           $'public atom F(int n)\nF(>= -5) -> :a\nF(< -5) -> :b'
  try $b 'P02 pattern literal -5 + n'         $'public atom F(int n)\nF(-5) -> :a\nF(n) -> :b'
  try $b 'P03 pattern >= -(-5) (MUST refuse)' $'public atom F(int n)\nF(>= -(-5)) -> :a\nF(< 5) -> :b'
  # --- signed domain, residual --------------------------------------------------
  try $b 'S01 Delta param, total on Delta'   $'type Delta = int where value >= -100 and value <= 100\npublic Delta F(Delta d)\nF(d) -> d'
  # --- typing of the literal itself (e_neg types as `int`, e_int as the exact range) -------------
  local d='type Delta = int where value >= -100 and value <= 100'
  try $b 'E01 Delta fn returns -100'          $"$d"$'\npublic Delta Low()\nLow() -> -100'
  try $b 'E02 Delta returns -101 (MUST ref)' $"$d"$'\npublic Delta Low()\nLow() -> -101'
  try $b 'E03 Neg = <= -1, fn returns -1'     $'type Neg = int where value <= -1\npublic Neg M()\nM() -> -1'
  try $b 'E04 fn returns -1 as int (control)' $'public int M()\nM() -> -1'
  # --- ticket 38's divisor check reads literals ------------------------------------------------------
  try $b 'D01 n / -0 (zero divisor)'          $'public int D(int n)\nD(n) -> n / -0'
  try $b 'D02 n / 0 (control: refused)'       $'public int D(int n)\nD(n) -> n / 0'
  try $b 'D03 n / (0 - 0) (control)'          $'public int D(int n)\nD(n) -> n / (0 - 0)'
}
