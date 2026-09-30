# Cases for ticket 57. EXPECTATIONS ARE WRITTEN HERE BEFORE ANY RUN (git history of this file, and the
# brief's section 2, show them; nothing below is edited to make a compiler pass).
#
# Compilers, in column order:   base  A  Aprod  B0  Bn  Ba
#   base  = HEAD compiler, unpatched copy
#   A     = parser action folds a negated integer literal:  negate(_, {e_int,L,N}) -> {e_int,L,-N}
#   Aprod = new production  expr_low -> '-' integer  (the literal mirror of int_lit)
#   B0    = checker: const_int/1 (literal, unary minus) read by comparison/1 ONLY
#   Bn    = B0 + type_of(e_neg) uses const_int/1 (so a `-5` VALUE is typed range(-5,-5))
#   Ba    = Bn + const_int/1 also folds + - * of constants
# Expectation letters: a = accepted (bsc exit 0, silent), r = refused.
#
# c ID "e_base e_A e_Aprod e_B0 e_Bn e_Ba" 'what it tests'   <source on stdin, without the module line>

# --- refinement site: the ticket's five rows -------------------------------------------------------
c R1  "r a a a a a" 'ticket row 1: value >= -5' <<'EOF'
type T = int where value >= -5
public int Id(T b)
Id(b) -> b
EOF
c R2  "r a a a a a" 'ticket row 2: >= -5 and <= 5' <<'EOF'
type T = int where value >= -5 and value <= 5
public int Id(T b)
Id(b) -> b
EOF
c R3  "r a a a a a" 'ticket row 3: >= 1 or <= -1' <<'EOF'
type T = int where value >= 1 or value <= -1
public int Id(T b)
Id(b) -> b
EOF
c R4  "a a a a a a" 'ticket row 4: <= 3 or >= 10 (disjoint, non-negative)' <<'EOF'
type T = int where value <= 3 or value >= 10
public int Id(T b)
Id(b) -> b
EOF
c R5  "a a a a a a" 'ticket row 5: != 0' <<'EOF'
type T = int where value != 0
public int Id(T b)
Id(b) -> b
EOF
# --- how far does folding go ------------------------------------------------------------------------
c R6  "r r r r r a" 'value >= 2 + 3' <<'EOF'
type T = int where value >= 2 + 3
public int Id(T b)
Id(b) -> b
EOF
c R7  "r a r a a a" 'value >= -(-5): parens are transparent to A (negate folds twice), not to Aprod' <<'EOF'
type T = int where value >= -(-5)
public int Id(T b)
Id(b) -> b
EOF
c R8  "r r r r r a" 'value >= 5 - 10' <<'EOF'
type T = int where value >= 5 - 10
public int Id(T b)
Id(b) -> b
EOF
c R9  "r r r r r a" 'value >= 2 * 3' <<'EOF'
type T = int where value >= 2 * 3
public int Id(T b)
Id(b) -> b
EOF
c R10 "r a a a a a" 'literal on the left: -5 <= value' <<'EOF'
type T = int where -5 <= value
public int Id(T b)
Id(b) -> b
EOF
c R11 "r r r r r r" 'value >= n : must stay refused (n is not a constant)' <<'EOF'
type T = int where value >= n
public int Id(T b)
Id(b) -> b
EOF
c R12 "r r r r r r" 'value >= Min() : a call is not a constant' <<'EOF'
type T = int where value >= Min()
public int Id(T b)
Id(b) -> b
public int Min()
Min() -> 3
EOF
# --- a `-5` VALUE: what does the checker type it as? (Nz is writable in every compiler) --------------
c V1  "r a a r a a" 'Id(-5) into int where value != 0 : is -5 typed as the literal -5?' <<'EOF'
type Nz = int where value != 0
public int Id(Nz b)
Id(b) -> b
public int Go()
Go() -> Id(-5)
EOF
c V2  "r r r r r r" 'Id(2 + 3) into != 0 : arithmetic is typed int, not the interval 5..5 (bs_check type_of comment)' <<'EOF'
type Nz = int where value != 0
public int Id(Nz b)
Id(b) -> b
public int Go()
Go() -> Id(2 + 3)
EOF
c V3  "r r r r r a" 'Id(-(2 + 3)) into != 0 : Ba folds it although V2 (2 + 3) is typed int' <<'EOF'
type Nz = int where value != 0
public int Id(Nz b)
Id(b) -> b
public int Go()
Go() -> Id(-(2 + 3))
EOF
c V4  "r r r r r r" 'Id(0) into != 0 : a real violation stays refused' <<'EOF'
type Nz = int where value != 0
public int Id(Nz b)
Id(b) -> b
public int Go()
Go() -> Id(0)
EOF
c V5  "r a a r a a" 'Delta domain, in range: Id(-100)' <<'EOF'
type Delta = int where value >= -100 and value <= 100
public int Id(Delta d)
Id(d) -> d
public int Go()
Go() -> Id(-100)
EOF
c V6  "r r r r r r" 'Delta domain, out of range: Id(-101) must be refused (base: refused earlier, at the type)' <<'EOF'
type Delta = int where value >= -100 and value <= 100
public int Id(Delta d)
Id(d) -> d
public int Go()
Go() -> Id(-101)
EOF
# --- guard site (same alternatives/1) -----------------------------------------------------------------
c G1  "r a a a a a" 'guard partition on -5 with no catch-all: exhaustive only if both guards are read' <<'EOF'
public atom Side(int n)
Side(n) when n >= -5 -> :in
Side(n) when n < -5  -> :out
EOF
c G2  "r r r r r a" 'guard partition with 2 + 3 and 5' <<'EOF'
public atom Side(int n)
Side(n) when n >= 2 + 3 -> :in
Side(n) when n < 5      -> :out
EOF
c G3  "a a a a a a" 'unread guard with a catch-all: accepted everywhere (a guard only ever credits, never errors)' <<'EOF'
public atom Side(int n)
Side(n) when n >= -5 -> :in
Side(_) -> :out
EOF
c G4  "r a a a a a" 'switch arm guards on -5, no catch-all' <<'EOF'
public atom Side(int n)
Side(n) -> n switch {
    x when x >= -5 => :in,
    x when x < -5  => :out
}
EOF
# --- pattern sites: int_lit already folds ---------------------------------------------------------------
c P1  "a a a a a a" 'relational patterns with negative bounds (int_lit)' <<'EOF'
public atom Sign(int n)
Sign(<= -1) -> :neg
Sign(0)     -> :zero
Sign(>= 1)  -> :pos
EOF
c P2  "a a a a a a" 'negative literal pattern' <<'EOF'
public atom Sign(int n)
Sign(-1) -> :minus_one
Sign(_)  -> :other
EOF
c P3  "r r r r r r" 'pattern bound written 2 - 3: int_lit is a literal only, in every compiler here' <<'EOF'
public atom Sign(int n)
Sign(<= 2 - 3) -> :neg
Sign(>= -2)    -> :other
EOF
# P4 was first written as  "a a a a a a"  (int_lit folds, so the segment parses). OBSERVED r in all six:
# the segment-size check refuses -1 in 8 bits. The prediction was wrong; the corrected expectation below
# was written after seeing that diagnostic, and the brief says so.
c P4  "r r r r r r" 'negative literal in an 8-bit binary segment: parses (int_lit), refused by the size check' <<'EOF'
public atom Sign(binary b)
Sign(<<-1:8, rest>>) -> :minus_one
Sign(_)              -> :other
EOF
# --- other sites that read an integer -------------------------------------------------------------------
c S1  "r r r r r r" 'a range literal -5..5 : no such syntax (.. is a rest)' <<'EOF'
public atom In(int n)
In(-5..5) -> :in
In(_)     -> :out
EOF
c S2  "r r r r r r" 'a where on a record field, NON-negative: syntax absent independent of the gap' <<'EOF'
record R { X: int where value >= 5 }
EOF
c S3  "r a a a a a" 'a record field of a refined alias with a negative bound (the only way a field gets one)' <<'EOF'
type D = int where value >= -5
record R { X: D }
public int Get(R r)
Get(r) -> r.X
EOF

# --- does folding change what an existing program means? ---------------------------------------------------
# D1: `n / -0`. At HEAD `-0` is e_neg(e_int 0), typed int, so the provably-zero divisor check (ticket 38 s2)
# does not fire. Where `-0` is typed as the literal 0..0 it must fire. EXPECTED: base a, A r, Aprod r, B0 a, Bn r, Ba r.
c D1  "a r r a r r" 'n / -0 : a provably zero divisor spelled with unary minus' <<'EOF'
public int Half(int n)
Half(n) -> n / -0
EOF
