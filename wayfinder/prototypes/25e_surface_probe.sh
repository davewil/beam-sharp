#!/usr/bin/env bash
# PROTOTYPE 25e — what today's compiler says about the web-page exemplar's claims.
#
# Throwaway. Ticket 25, exemplar 5. Runs the compiler (`compiler/`) over seven
# probes. Each one decides a sentence in 25e-dynamic-web-page.md — the rule is
# to run the form rather than reason about it, because three prior exemplars
# each found a claim that reading alone got wrong.
#
# EVERY PROBE THAT ASSERTS A REFUSAL CARRIES A CONTROL. A refusal measured
# without one is a sentence about a program that may have failed for an
# unrelated reason: §2 below would read identically if binary patterns were
# broken in general rather than over `string` in particular, and §5's finding is
# invisible without the clause that compiles beside it.
#
#   ./25e_surface_probe.sh
#
# Requires: OTP 28, rebar3. Builds bsc if it is not already built.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER="$HERE/../../compiler"
BSC="$COMPILER/_build/default/bin/bsc"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -x "$BSC" ]; then
    echo "building bsc..."
    (cd "$COMPILER" && rebar3 escriptize >/dev/null 2>&1)
fi

# One directory per probe, named after the module — F15's rule.
n=0
probe () {
    local label="$1" body="$2"
    shift 2
    n=$((n + 1))
    local dir="$WORK/p$n/P"
    mkdir -p "$dir"
    printf '%s\n' "$body" > "$dir/p.bs"
    echo "--- $label ---"
    "$BSC" --src-root "$WORK/p$n" "$dir" "$@" 2>&1 | sed "s|$WORK/p$n/||" || true
    echo
}

echo "==================================================================="
echo "1. THE HEADLINE — iodata is a recursive type, and it is refused."
echo "==================================================================="
echo "A page is a tree of fragments. This is the type of every value the"
echo "exemplar produces, and it is the first thing the compiler sees."
echo
probe "the exemplar's own Iodata" 'module P
type Iodata = binary | list<Iodata>
public Iodata Doc(string t)
Doc(t) -> ["<h1>", t, "</h1>"]'

echo "CONTROL — the same program with the recursion removed compiles and runs,"
echo "so the refusal is the recursion and not the list, the union or the literal."
probe "CONTROL: non-recursive, one level" 'module P
public list<binary> Doc(string t)
Doc(t) -> ["<h1>", t, "</h1>"]' Doc '"hi"'

echo "AND THE CHECKER ALREADY KNOWS THE TYPE. Nest it one level and the residual"
echo "is exact — the algebra computes it and cannot be handed a name for it."
probe "the exact type of a nested fragment" 'module P
public list<string> Page(list<string> body)
Page(b) -> ["<html>", b, "</html>"]'

echo "==================================================================="
echo "2. \`string\` is not closed under binary decomposition."
echo "==================================================================="
echo "The tail of a binary pattern over a \`string\` is \`binary \\ string\`:"
echo "a byte off a multi-byte codepoint leaves invalid UTF-8, so the checker"
echo "is right. The consequence is that no character loop over a string exists."
echo
probe "a character walk over a string" 'module P
public atom Walk(string s)
Walk(<<"">>)        -> :done
Walk(<<c:8, rest>>) -> Walk(rest)'

echo "CONTROL A — the same walk at 32 bits. If this passed, the cause would be"
echo "the width; it fails identically, so the cause is the refinement."
probe "CONTROL: the same walk at 32 bits" 'module P
public atom Walk(string s)
Walk(<<"">>)         -> :done
Walk(<<c:32, rest>>) -> Walk(rest)'

echo "CONTROL B — the same walk over a bare \`binary\` type-checks and runs."
echo "This is what proves the refusal is about \`string\` specifically."
probe "CONTROL: the same walk over binary" 'module P
public atom Walk(binary s)
Walk(<<"">>)        -> :done
Walk(<<c:8, rest>>) -> Walk(rest)
Walk(_)             -> :partial' Walk '<<"ab">>'

echo "==================================================================="
echo "3. Binary CONSTRUCTION does not exist, and the escaper pays for it."
echo "==================================================================="
probe "<<...>> in expression position" 'module P
public binary Cat(binary a, binary b)
Cat(a, b) -> <<a, b>>'

echo "So a matched byte cannot go back on the list. Written the obvious way —"
echo "dropping it — the escaper compiles, runs, and DELETES the text it was"
echo "protecting. This is finding 3 and it is the sharpest thing here."
probe "the escaper that drops what it does not escape" 'module P
public list<binary> Escape(binary s, list<binary> acc)
Escape(<<"">>, acc)           -> Reverse(acc, [])
Escape(<<0x26:8, rest>>, acc) -> Escape(rest, ["&amp;", ..acc])
Escape(<<0x3C:8, rest>>, acc) -> Escape(rest, ["&lt;", ..acc])
Escape(<<c:8, rest>>, acc)    -> Escape(rest, acc)
Escape(_, acc)                -> Reverse(acc, [])
private list<binary> Reverse(list<binary> xs, list<binary> acc)
Reverse([], acc)          -> acc
Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])' Escape '<<"a<b&c">>' '[]'

echo "CONTROL — the same escaper with the foreign call is CORRECT, which is what"
echo "makes the one above a choice the language forces rather than a mistake."
probe "CONTROL: the escaper with :binary.encode_unsigned" 'module P
using :binary {
    binary encode_unsigned(int n)
}
public list<binary> Escape(binary s, list<binary> acc)
Escape(<<"">>, acc)           -> Reverse(acc, [])
Escape(<<0x26:8, rest>>, acc) -> Escape(rest, ["&amp;", ..acc])
Escape(<<0x3C:8, rest>>, acc) -> Escape(rest, ["&lt;", ..acc])
Escape(<<c:8, rest>>, acc)    -> Escape(rest, [:binary.encode_unsigned(c), ..acc])
Escape(_, acc)                -> Reverse(acc, [])
private list<binary> Reverse(list<binary> xs, list<binary> acc)
Reverse([], acc)          -> acc
Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])' Escape '<<"a<b&c">>' '[]'

echo "==================================================================="
echo "4. \`<<>>\` has no production; \`<<\"\">>\` is the empty binary."
echo "==================================================================="
echo "bs_parser.yrl:410 — bin_segments is one-or-more, so the empty binary has"
echo "no literal spelling. The string-literal segment supplies one."
echo
probe "<<>> as a pattern" 'module P
public atom E(binary b)
E(<<>>) -> :empty
E(_)    -> :more'

probe 'CONTROL: <<"">> as a pattern' 'module P
public atom E(binary b)
E(<<"">>) -> :empty
E(_)      -> :more' E '<<>>'

echo "==================================================================="
echo "5. A relational pattern binds nothing, and no as-pattern exists."
echo "==================================================================="
probe "a relational pattern whose value the body needs" 'module P
public int F(int n)
F(<= 9) -> n
F(_)    -> 0'

echo "CONTROL — the SAME pattern with the value unused compiles. This is the"
echo "control that locates the gap: the test works, the binding is what is"
echo "missing, and every prior use in the corpus discarded the value."
probe "CONTROL: the same pattern, value unused" 'module P
public atom F(int n)
F(<= 9) -> :small
F(_)    -> :big' F 3

echo "Three spellings of the missing capability, none of which exists:"
probe "an as-pattern, p @ <= 9" 'module P
public int F(int n)
F(p @ <= 9) -> p
F(_)        -> 0'

probe "the C# postfix spelling, <= 9 p" 'module P
public int F(int n)
F(<= 9 p) -> p
F(_)      -> 0'

probe "CONTROL: the guard, which is what 25e ships" 'module P
public int F(int n)
F(n) when n <= 9 -> n
F(_)             -> 0' F 3

echo "==================================================================="
echo "6. A vacuous clause is reported as SHADOWED, and that is untrue."
echo "==================================================================="
echo "option<T> is T | :nothing, UNTAGGED — so (:some, s) matches no value of"
echo "option<string>. The diagnostic for that names the wrong cause."
echo
probe "a vacuous clause 1, with clauses after it" 'module P
type K = :a | :b
public int F(K k)
F((:some, x)) -> 0
F(:a)         -> 1
F(:b)         -> 2'

echo "THE ONE THAT SETTLES IT — a vacuous clause that is the ONLY clause is"
echo "still reported as 'matched by an earlier clause'. There is no earlier"
echo "clause. Two different faults share one message and the wrong one is"
echo "the likelier, because (:some, s) is what a C#/Rust/F# reader writes."
probe "a vacuous clause that is the ONLY clause" 'module P
type K = :a | :b
public int F(K k)
F((:some, x)) -> 0'

echo "CONTROL — a genuinely shadowed clause 2, where the wording is correct."
probe "CONTROL: a genuinely shadowed clause" 'module P
type K = :a | :b
public int F(K k)
F(k)  -> 0
F(:a) -> 1'

echo "CONTROL — and the spelling that works, with :nothing first."
probe "CONTROL: option<string> matched correctly" 'module P
public list<string> Note(option<string> n)
Note(:nothing) -> []
Note(s)        -> ["<p>", s, "</p>"]' Note ':nothing'

echo "==================================================================="
echo "7. \`+\` over two strings — ticket 33's decision, and its price."
echo "==================================================================="
echo "33 §2 rules there is no sixth obligation site because e_op declares no"
echo "type. So + synthesises int whatever it is handed. The rule is coherent;"
echo "what this exemplar adds is that the realistic case is string CONCATENATION"
echo "in the one program where joining strings is the entire job."
echo
probe "string + string, declared int" 'module P
public int Cat(string a, string b)
Cat(a, b) -> a + b' Cat '"ab"' '"cd"'

echo "CONTROL — a string handed to a DECLARED int parameter is refused, with a"
echo "good diagnostic. So the checker is not blind to the type; the operator is"
echo "simply not a site. That contrast is the finding."
probe "CONTROL: a string into a declared int parameter" 'module P
public int Add(int a, int b)
Add(a, b) -> a + b
public int Via(string s)
Via(s) -> Add(s, 1)'

echo "==================================================================="
echo "8. There is no size operator, and no string operations at all."
echo "==================================================================="
probe "ByteSize, which a Content-Length needs" 'module P
public int Size(binary b)
Size(b) -> ByteSize(b)'

probe "CONTROL: the foreign declaration, which works" 'module P
using :erlang {
    int byte_size(binary b)
}
public int Size(binary b)
Size(b) -> :erlang.byte_size(b)' Size '<<"abc">>'

echo "==================================================================="
echo "done."
echo "==================================================================="
