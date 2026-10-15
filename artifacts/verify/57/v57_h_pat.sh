. "$(dirname "$0")/v57_lib.sh"
cmp_src "match lhs (n, -5) = p" $'public int F((int, int) p)\nF(p) ->\n    (n, -5) = p\n    n' F '(1, -5)'
cmp_src "match lhs (n, 5) = p (ctl)" $'public int F((int, int) p)\nF(p) ->\n    (n, 5) = p\n    n' F '(1, 5)'
cmp_src "match lhs -5 = n" $'public int F(int n)\nF(n) ->\n    -5 = n\n    n' F -5
cmp_src "match lhs 5 = n (ctl)" $'public int F(int n)\nF(n) ->\n    5 = n\n    n' F 5
cmp_src "lambda body -5" $'public int F(int n)\nF(n) -> (x => x + -5)(n)' F 10
cmp_src "switch arm -5" $'public atom F(int n)\nF(n) -> n switch { -5 => :m, _ => :o }' F -5
cmp_src "bin seg -5" $'public int F()\nF() -> 1'
cmp_src "interp $\"{-5}\"" $'public string F()\nF() -> $"v={-5}"' F
cmp_src "-5 with e_neg of call" $'public int F(int n)\nF(n) -> -G(n)\nint G(int n) -> n' F 4
