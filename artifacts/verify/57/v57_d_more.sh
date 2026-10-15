. "$(dirname "$0")/v57_lib.sh"
cmp_src "record field alias -5" $'type T = int where value >= -5\nrecord R { Temp: T }\npublic int F(R r)\nF(r) -> r.Temp' F
cmp_src "record field inline where" $'record R { Temp: int where value >= -5 }\npublic int F(R r)\nF(r) -> 1' F
cmp_src "record ctor -6 into T" $'type T = int where value >= -5\nrecord R { Temp: T }\npublic int G()\nG() -> R { Temp: -6 }.Temp' G
cmp_src "record ctor -5 into T" $'type T = int where value >= -5\nrecord R { Temp: T }\npublic int G()\nG() -> R { Temp: -5 }.Temp' G
cmp_src "(-5) switch ranges" $'public atom F()\nF() -> (-5) switch { <= -1 => :neg, 0 => :z, >= 1 => :pos }' F
cmp_src "var k=-1; sum" $'public int F(int n)\nF(n) ->\n    var k = -1\n    n + k' F 5
cmp_src "var k=-1 to NZ" $'type NZ = int where value != 0\npublic int G(NZ n)\nG(n) -> n\npublic int F()\nF() ->\n    var k = -1\n    G(k)' F
cmp_src "clause head -5 literal arg" $'public atom F(int n)\nF(-5) -> :a\nF(n) -> :b' F -5
cmp_src "-5 in list/tuple pat" $'public atom F((int, int) p)\nF((-5, n)) -> :a\nF(p) -> :b' F '(-5, 1)'
cmp_src "float: -5.0 vs 0-5.0" $'public float F()\nF() -> -0.0' F
cmp_src "int*float neg" $'public float F(float x)\nF(x) -> x * -2.0' F 1.5
cmp_src "x - -5.0 float" $'public float F(float x)\nF(x) -> x - -5.0' F 1.5
cmp_src "-x - -5 (var,int)" $'public int F(int x)\nF(x) -> -x - -5' F 2
cmp_src "int where range + guard -5" $'type T = int where value >= -5\npublic atom F(T t)\nF(t) when t >= -5 -> :a' F -3
cmp_src "T>=-5, F(<= -6) dead clause?" $'type T = int where value >= -5\npublic atom F(T t)\nF(<= -6) -> :x\nF(t) -> :a' F -3
cmp_src "T>=-5, F(-5),F(>=-4) exh" $'type T = int where value >= -5\npublic atom F(T t)\nF(-5) -> :x\nF(>= -4) -> :a' F -5
cmp_src "T>=-5, F(>=-4) only (residual)" $'type T = int where value >= -5\npublic atom F(T t)\nF(>= -4) -> :a'
cmp_src "T>=-5, F(>=-5)" $'type T = int where value >= -5\npublic atom F(T t)\nF(>= -5) -> :a' F 0
