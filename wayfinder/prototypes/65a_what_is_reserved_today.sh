#!/usr/bin/env bash
# PROTOTYPE 65a — what does the compiler reserve today, and where does it say so?
#
# Throwaway. Ticket 65, round 1 (2026-11-12). The ticket was written on
# 2026-08-25, when B# reserved no name and `Map` was about to become the first.
# It put three policies side by side: refuse the declaration, a namespace the
# user's syntax cannot reach, or let the user's name win. Since then ticket 67
# (Q1, Q6) and ticket 96 (Q6) were answered and F32, F51, F62, F64 and F75 were
# built. This probe measures what those left the compiler doing, against the
# three policies.
#
#   1. `module List`, bare                     — refused at the declaration?
#   2. every other name in the table, bare     — `Map`, `Term`, `Float`, `Enumerable`
#   3. `module Shop.List`                      — a path segment: legal?
#   4. `using Shop` + `List.Sum(...)`          — the call that means two things
#   5. `using Shop` + `Shop.List.Sum(...)`     — the same module, called in full
#   6. the user's `List` against the compiler's — can a user name ever win?
#   7. the names ticket 96 Q6 reserved by rule and no feature has built yet,
#      and `Binary`, which ticket 93 asks about and nothing has answered
#   8. `bs@`, the prefix ticket 87 handed to this ticket
#   9. `not`, the identifier ticket 63 left alone pending this ticket
#  10. Erlang's own answer: a user module called `lists`
#
#   ./65a_what_is_reserved_today.sh
#
# Requires: OTP 28, a built bsc. Runs in a temp dir, touches nothing in the tree.
set -uo pipefail
# The diagnostics hold an em dash; under a POSIX locale erl prints it as \x{2014}.
export LC_ALL=C.UTF-8

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER="$HERE/../../compiler"
BSC="$COMPILER/_build/default/bin/bsc"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -x "$BSC" ]; then
    echo "building bsc..."
    (cd "$COMPILER" && rebar3 escriptize >/dev/null 2>&1)
fi

# One directory per module (F15): `mk root Shop.List` writes root/Shop/List/List.bs.
mk  () { local d="$WORK/$1/$(echo "$2" | tr . /)"; mkdir -p "$d"; cat > "$d/${2##*.}.bs"; }
dir () { echo "$WORK/$1/$(echo "$2" | tr . /)"; }
bsc () { "$BSC" "$@" 2>&1; echo "[rc=$?]"; }
run () { bsc "$@" | sed "s#$WORK/##g" | sed 's/^/    /'; }
hdr () { echo; echo "=== $* ==="; }

# ---------------------------------------------------------------------------
hdr "1. module List, bare"
mk bare List <<'EOF'
module List

public int Go(int n)
Go(n) -> n
EOF
run --src-root "$WORK/bare" "$(dir bare List)" Go 1

# ---------------------------------------------------------------------------
hdr "2. the rest of the table, bare: first line of each diagnostic"
for name in Map Term Float Enumerable; do
    mk "t_$name" "$name" <<EOF
module $name

public int Go(int n)
Go(n) -> n
EOF
    printf '  module %-11s ' "$name"
    bsc --src-root "$WORK/t_$name" "$(dir "t_$name" "$name")" Go 1 \
        | sed "s#$WORK/##g" | tr '\n' ' ' | sed -E 's/  +.*(\[rc=[0-9]+\])/ \1/'; echo
done

# ---------------------------------------------------------------------------
hdr "3. module Shop.List: the word as a path segment"
mk src Shop.List <<'EOF'
module Shop.List

public int Sum(list<int> xs, int acc)
Sum([], acc)          -> acc
Sum([x, ..rest], acc) -> Sum(rest, acc + x)
EOF
run --src-root "$WORK/src" "$(dir src Shop.List)" Sum '[1, 2, 3]' 0

# ---------------------------------------------------------------------------
hdr "4. using Shop, then List.Sum(...): the call that means two things"
mk src Short <<'EOF'
module Short

using Shop

public int Go(int n)
Go(n) -> List.Sum([n, n, n], 0)
EOF
run --src-root "$WORK/src" "$(dir src Short)" Go 2

# ---------------------------------------------------------------------------
hdr "5. the same module, called in full"
mk src Full <<'EOF'
module Full

using Shop

public int Go(int n)
Go(n) -> Shop.List.Sum([n, n, n], 0)
EOF
run --src-root "$WORK/src" "$(dir src Full)" Go 2

# ---------------------------------------------------------------------------
hdr "6. can the user's name win? the compiler's List.Sum beside an imported Shop.List"
# `Shop.List.Sum/2` exists and `List.Sum/1` is the compiler's. If user names
# won, `List.Sum([n, n, n])` would be an arity error against the user's module.
mk src Mine <<'EOF'
module Mine

using Shop

public int Go(int n)
Go(n) -> List.Sum([n, n, n])
EOF
run --src-root "$WORK/src" "$(dir src Mine)" Go 2
echo "  and with no using at all:"
mk src Theirs <<'EOF'
module Theirs

public int Go(int n)
Go(n) -> List.Sum([n, n, n])
EOF
run --src-root "$WORK/src" "$(dir src Theirs)" Go 2

# ---------------------------------------------------------------------------
hdr "7. ticket 96 Q6's eight names, and ticket 93's Binary: does a bare module of that name compile today?"
for name in Enum String Int Process GenServer Supervisor Logger System Binary; do
    mk "u_$name" "$name" <<EOF
module $name

public int Go(int n)
Go(n) -> n
EOF
    printf '  module %-11s ' "$name"
    bsc --src-root "$WORK/u_$name" "$(dir "u_$name" "$name")" Go 1 \
        | sed "s#$WORK/##g" | tr '\n' ' ' | sed -E 's/  +.*(\[rc=[0-9]+\])/ \1/'; echo
done

# ---------------------------------------------------------------------------
hdr "8. bs@: can an author's function carry the compiler's prefix?"
mk at At <<'EOF'
module At

public int bs@x(int n)
bs@x(n) -> n
EOF
echo "  a lowercase name with the prefix:"
run --src-root "$WORK/at" "$(dir at At)"
mk at2 At <<'EOF'
module At

public int Bs@x(int n)
Bs@x(n) -> n
EOF
echo "  a PascalCase name holding @:"
run --src-root "$WORK/at2" "$(dir at2 At)"
mk at3 Plain <<'EOF'
module Plain

public atom Go(int n)
Go(n) -> :ok
EOF
mkdir -p "$WORK/out"
"$BSC" --src-root "$WORK/at3" -o "$WORK/out" "$(dir at3 Plain)" >/dev/null 2>&1
echo "  what a module that never wrote it exports:"
(cd "$WORK/out" && erl -noshell -eval '
    {ok, {_, [{exports, Es}]}} = beam_lib:chunks("Plain.beam", [exports]),
    [io:format("    ~ts/~p~n", [F, A]) || {F, A} <- lists:sort(Es)],
    halt().')

# ---------------------------------------------------------------------------
hdr "9. not: an identifier, as ticket 63 left it"
mk kw Kw <<'EOF'
module Kw

public bool F(int not)
F(not) when not > 100 -> :true
F(_)                  -> :false
EOF
run --src-root "$WORK/kw" "$(dir kw Kw)" F 101

# ---------------------------------------------------------------------------
hdr "10. Erlang: a user module called lists"
mkdir -p "$WORK/er" "$WORK/elsewhere"
printf -- '-module(lists).\n-export([sum/1]).\nsum(_) -> 42.\n' > "$WORK/er/lists.erl"
(cd "$WORK/er" && erlc lists.erl; echo "  erlc lists.erl: [rc=$?]")
echo "  loaded into a running VM, then lists:sum([1,2,3]):"
(cd "$WORK/elsewhere" && erl -noshell -eval '
    code:add_patha("../er"),
    io:format("    ~p~n    ~p~n", [code:load_file(lists), lists:sum([1,2,3])]),
    halt().' 2>&1)
echo "  first on the code path at boot (erl -pa): first 100 bytes, and the exit status"
(cd "$WORK/elsewhere" && erl -noshell -pa ../er -eval 'halt().' > boot.out 2>&1; rc=$?
 head -c 100 boot.out | sed 's/^/    /'; echo; echo "    [rc=$rc]")
