. "$(dirname "$0")/v57_lib.sh"
cmp_src "bind -1 then sum" $'public int F(int n)\nF(n) ->\n    k = -1\n    n + k' F 5
cmp_src "if/else -1 | 1" $'public int F(int n)\nF(n) when n > 0 -> 1\nF(n) -> -1' F 0
cmp_src "tuple with -1" $'public (atom, int) F()\nF() -> (:ok, -1)' F
cmp_src "list of negs" $'public int F()\nF() -> [-1, -2, 3] |> Sum\nint Sum(list<int> l) -> 0' F
cmp_src "-1 vs 1 return refined" $'type Sg = int where value >= -1 and value <= 1\npublic Sg F(int n)\nF(n) when n > 0 -> 1\nF(n) when n < 0 -> -1\nF(n) -> 0' F 4
cmp_src "-1 return refined(stock?)" $'type Sg = int where value != 0\npublic Sg F(int n)\nF(n) -> -1' F 4
cmp_src "return -1 as pos" $'type P = int where value > 0\npublic P F()\nF() -> -1' F
cmp_src "return 5 as pos (ctl)" $'type P = int where value > 0\npublic P F()\nF() -> 5' F
cmp_src "arg -1 to Nonneg" $'type N = int where value >= 0\npublic int F(N n)\nF(n) -> n\npublic int G()\nG() -> F(-1)' G
cmp_src "arg -1 to int param" $'public int F(int n)\nF(n) -> n\npublic int G()\nG() -> F(-1)' G
cmp_src "arg 5 to Nonneg (ctl)" $'type N = int where value >= 0\npublic int F(N n)\nF(n) -> n\npublic int G()\nG() -> F(5)' G
cmp_src "arg -1 to !=0 NZ" $'type NZ = int where value != 0\npublic int F(NZ n)\nF(n) -> n\npublic int G()\nG() -> F(-1)' G
cmp_src "arg 0 to NZ (ctl)" $'type NZ = int where value != 0\npublic int F(NZ n)\nF(n) -> n\npublic int G()\nG() -> F(0)' G
cmp_src "guard n == -3" $'public atom F(int n)\nF(n) when n == -3 -> :a\nF(n) -> :b' F -3
cmp_src "guard n != -3 exh" $'public atom F(int n)\nF(n) when n != -3 -> :a\nF(n) when n == -3 -> :b' F -3
cmp_src "guard -5<=n<=5" $'public atom F(int n)\nF(n) when n >= -5 and n <= 5 -> :a\nF(n) when n < -5 -> :b\nF(n) -> :c' F 5
cmp_src "pattern range -5" $'public atom F(int n)\nF(<= -5) -> :a\nF(>= -4) -> :b' F -4
cmp_src "pattern lit -5" $'public atom F(int n)\nF(-5) -> :a\nF(n) -> :b' F -5
cmp_src "case -5 literal switch" $'public atom F()\nF() -> -5 switch { -5 => :a, _ => :b }' F
cmp_src "x = -5; x switch" $'public atom F()\nF() ->\n    x = -5\n    x switch { <= -1 => :neg, 0 => :z, >= 1 => :pos }' F
cmp_src "-5 literal switch no catchall" $'public atom F()\nF() -> -5 switch { <= -1 => :neg, >= 0 => :nn }' F
cmp_src "record where -5" $'record R { int Temp where value >= -5 }\npublic int F(R r)\nF(r) -> r.Temp' F
cmp_src "record field type alias" $'type T = int where value >= -5\nrecord R { T Temp }\npublic int F(R r)\nF(r) -> 1' F
cmp_src "unary of var" $'public int F(int x)\nF(x) -> -x' F 3
cmp_src "float where >= -5.0" $'type T = float where value >= -5.0\npublic atom F(T t)\nF(t) -> :a' F
cmp_src "type >= - 5 (space)" $'type T = int where value >= - 5\npublic atom F(T t)\nF(t) -> :a' F -5
cmp_src "type >= -(5)" $'type T = int where value >= -(5)\npublic atom F(T t)\nF(t) -> :a' F -5
cmp_src "type >= - -5" $'type T = int where value >= - -5\npublic atom F(T t)\nF(t) -> :a' F 5
cmp_src "type -5 <= value" $'type T = int where -5 <= value\npublic atom F(T t)\nF(t) -> :a' F -5
cmp_src "type >=-5 nospace" $'type T = int where value>=-5\npublic atom F(T t)\nF(t) -> :a' F -5
cmp_src "type value >= -5 + 10" $'type T = int where value >= -5 + 10\npublic atom F(T t)\nF(t) -> :a' F -5
cmp_src "type -0" $'type T = int where value >= -0\npublic atom F(T t)\nF(t) -> :a' F -1
cmp_src "type huge" $'type T = int where value >= -9223372036854775809\npublic atom F(T t)\nF(t) -> :a' F -9223372036854775809
cmp_src "type >=-5 and <=-10" $'type T = int where value >= -5 and value <= -10\npublic atom F(T t)\nF(t) -> :a' F -9
cmp_src "type -5..?" $'type T = int where value > -1 and value < 1\npublic atom F(T t)\nF(t) -> :a' F 0
