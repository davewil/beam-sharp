. "$(dirname "$0")/v57_lib.sh"
cmp_src "x-5"      $'public int F(int x)\nF(x) -> x-5' F 10
cmp_src "x - 5"    $'public int F(int x)\nF(x) -> x - 5' F 10
cmp_src "x -5"     $'public int F(int x)\nF(x) -> x -5' F 10
cmp_src "5 - 3"    $'public int F()\nF() -> 5 - 3' F
cmp_src "n -1 call"$'public int F(int n)\nF(n) -> n -1' F 7
cmp_src "a - -5"   $'public int F(int a)\nF(a) -> a - -5' F 10
cmp_src "- -5"     $'public int F()\nF() -> - -5' F
cmp_src "-(5)"     $'public int F()\nF() -> -(5)' F
cmp_src "-(-5)"    $'public int F()\nF() -> -(-5)' F
cmp_src "-0"       $'public int F()\nF() -> -0' F
cmp_src "-9223372036854775808" $'public int F()\nF() -> -9223372036854775808' F
cmp_src "-9223372036854775809" $'public int F()\nF() -> -9223372036854775809' F
cmp_src "-99999999999999999999999" $'public int F()\nF() -> -99999999999999999999999' F
cmp_src "-5.0 float"  $'public float F()\nF() -> -5.0' F
cmp_src "-5 as float (int->float?)" $'public float F()\nF() -> -5' F
cmp_src "5 - -3.0"  $'public float F()\nF() -> 5.0 - -3.0' F
cmp_src "-2 * 3"   $'public int F()\nF() -> -2 * 3' F
cmp_src "-2 + 3"   $'public int F()\nF() -> -2 + 3' F
cmp_src "2 - 3 - 4" $'public int F()\nF() -> 2 - 3 - 4' F
cmp_src "-7 / 2"   $'public int F()\nF() -> -7 / 2' F
cmp_src "n / -1"   $'public int F(int n)\nF(n) -> n / -1' F 8
cmp_src "n / -0"   $'public int F(int n)\nF(n) -> n / -0' F 8
cmp_src "n / (0-0)" $'public int F(int n)\nF(n) -> n / (0 - 0)' F 8
cmp_src "n / 0"    $'public int F(int n)\nF(n) -> n / 0' F 8
cmp_src "n % -0"   $'public int F(int n)\nF(n) -> n % -0' F 8
cmp_src "-5 |> abs"  $'public int F()\nF() -> -5 |> Abs\nint Abs(int n) when n < 0 -> -n\nint Abs(n) -> n' F
