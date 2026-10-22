#!/usr/bin/env bash
# Probe 65/05: what does the B# reference compiler do with reserved names, and what would
# each ticket-65 policy do to a program that compiles today?
#
# THE REPO COMPILER PINS OTP 28.5 AND DOES NOT BUILD ON OTP 25 (leex `error_location`/`TokenLoc`
# are OTP 26+; `~kp` is OTP 26+). So this script builds a SCRATCH COPY and patches the COPY ONLY:
#   * otp25-and-probe-switches.patch (in this directory; read it) does three things
#     1. rebar.config: drop `{xrl_opts, [{error_location, column}]}`
#     2. bs_lexer.xrl: `TokenLoc` -> `{TokenLine, 1}` (every column reads 1, so diagnostics print
#        column 1; line numbers and refusal tags/texts are unaffected), + a stub `adjust_col/3`
#     3. bs_run.erl: `~kp` -> `~p`
#     4. bs_check.erl: two PROBE-ONLY env switches, both OFF by default (so with neither set the
#        reserved-name logic is byte-for-byte the repo's):
#          BS_PROBE_EXTRA=A,B    adds names to reserved_qualifiers()  (simulates ticket 96's roster arriving)
#          BS_PROBE_USER_WINS=1  a reserved name the current module declares or `using`s as a module is
#                                NOT reserved in that module (an approximation of ticket 65 option 3)
# Known scratch-build limits: columns are always 1; compiler/examples/Signalbox fails with an
# erl_anno error on both the patched baseline and the switches, so it is not used.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
WS="${WS:-$(mktemp -d)}"
echo "repo HEAD $(git -C "$REPO" rev-parse --short HEAD); erl OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().'); rebar3 $(rebar3 --version | head -1)"
mkdir -p "$WS" && rm -rf "$WS/compiler" && mkdir "$WS/compiler"
(cd "$REPO/compiler" && tar cf - --exclude=_build --exclude=rebar3.crashdump .) | (cd "$WS/compiler" && tar xf -)
(cd "$WS/compiler" && patch -p1 -s < "$HERE/otp25-and-probe-switches.patch") || { echo "PATCH FAILED"; exit 2; }
(cd "$WS/compiler" && rebar3 escriptize >"$WS/build.log" 2>&1) || { echo "BUILD FAILED"; tail -20 "$WS/build.log"; exit 2; }
BSC="$WS/compiler/_build/default/bin/bsc"
echo "scratch bsc: $BSC"

P="$WS/p"; rm -rf "$P"; mkdir -p "$P/src"
mod() { # mod DOTTED_NAME 'source'   -> src/A/B/B.bs
  local d="$P/src/$(echo "$1" | tr . /)"; mkdir -p "$d"; printf '%s\n' "$2" > "$d/${1##*.}.bs"; }
show() { sed 's/^/    | /'; }
# t LABEL DOTTED_MODULE FUNCTION ARGS...   (env switches are inherited)
t() { local label="$1" m="$2"; shift 2
  echo "--- $label"
  "$BSC" --src-root "$P/src" "$P/src/$(echo "$m" | tr . /)" "$@" 2>&1 | head -6 | sed 's/^/    > /'
  echo "    exit=${PIPESTATUS[0]}"; }
src() { printf '%s\n' "$2" | show; mod "$1" "$2"; }

echo; echo "################ A. TODAY: which names are taken, and in which namespace"
echo "[A1] a whole-name module named like a reserved qualifier"
for q in Map List Term Float; do src $q "module $q

public int Go(int n)
Go(n) -> n" >/dev/null; t "module $q" $q Go 1; done
echo "[A2] the same word as a path segment"
mod Shop.List "module Shop.List

public int Go(int n)
Go(n) -> n"; t "module Shop.List" Shop.List Go 1
echo "[A3] a protocol name (F64) as a module"
mod Enumerable "module Enumerable

public int Go(int n)
Go(n) -> n"; t "module Enumerable" Enumerable Go 1
echo "[A4] ticket 96's roster words, free today"
for q in Logger String Process Task Supervisor; do mod $q "module $q

public int Go(int n)
Go(n) -> n + 1"; t "module $q" $q Go 1; done
echo "[A5] unqualified PascalCase TYPES: the compiler-known ones are refused; Timeout is NOT a type (ticket 88 amended 14 s6: it is the atom :timeout)"
for r in ValidationError Down Exit Timeout; do mod R$r "module R$r

record $r { X: int }

public int Go(int n)
Go(n) -> n"; t "record $r" R$r Go 1; done
echo "[A6] a record named like a reserved qualifier; a function named like one or like an obligation"
mod Mix "module Mix

record Map { X: int }
record List { X: int }
record Task { X: int }

public int ValidateAs(int n)
ValidateAs(n) -> n + 100

public int Map(int n)
Map(n) -> n

public int Go(int n)
Go(n) -> ValidateAs(Map(n))"; t "record Map/List/Task + fn ValidateAs + fn Map" Mix Go 1
mod Atoe "module Atoe

public int ToExistingAtom(int n)
ToExistingAtom(n) -> n"; t "fn ToExistingAtom (called bare, so it is refused)" Atoe ToExistingAtom 1
echo "[A7] the lowercase namespace: can user syntax even spell a prelude type name?"
mod Low "module Low

record result { X: int }

public int Go(int n)
Go(n) -> n"; t "record result" Low Go 1

echo; echo "################ A+. the OTHER namespaces ticket 65 is cited by: identifiers (63), emitted names (87)"
echo "[A8] keywords already burned identifiers: a parameter named like each lexer keyword"
for w in raise fn and or where with switch var record; do
  mod Kw "module Kw

public int Go(int $w)
Go($w) -> 1"
  printf '    %-7s ' "$w"; "$BSC" --src-root "$P/src" "$P/src/Kw" Go 1 2>&1 | head -1
done
echo "[A9] ticket 63: 'not' is deliberately NOT a keyword (the one-line route to a sharp message was declined pending ticket 65)"
mod Nt "module Nt

public int Go(int not)
Go(not) when not > 100 -> 1
Go(not) -> 2"; t "parameter named not" Nt Go 7
echo "[A10] ticket 87: can user syntax spell an emitted bs@ name?"
mod Bs "module Bs

public int bs@x(int n)
bs@x(n) -> n"; t "function named bs@x" Bs Go 1

echo; echo "################ B. GROWTH, option 'reserve': BS_PROBE_EXTRA=Logger puts Logger in the set"
mod Logger "module Logger

public int Info(int n)
Info(n) -> n + 1"
mod Caller "module Caller

using Logger

public int Go(int n)
Go(n) -> Logger.Info(n)"
src Caller "module Caller

using Logger

public int Go(int n)
Go(n) -> Logger.Info(n)" >/dev/null
echo "[B0] before the release that adds Logger"; t "Caller -> user's Logger.Info" Caller Go 1
echo "[B1] after it"; BS_PROBE_EXTRA=Logger t "Caller (unchanged source)" Caller Go 1
BS_PROBE_EXTRA=Logger t "Logger itself (unchanged source)" Logger Info 1

echo; echo "################ C. option 'user names win' (approximation, see header)"
mod Map "module Map

public int Get(int n)
Get(n) -> n * 1000"
mod UsesMap "module UsesMap

using Map

public int Go(int n)
Go(n) -> Map.Get(n)"
mod Std "module Std

public int Go(int n)
Go(n) -> List.Sum([n, n])"
mod List "module List

public int Zero(int n)
Zero(n) -> 0"
mod UsesList "module UsesList

using List

public int Go(int n)
Go(n) -> List.Sum([n, n])"
echo "[C0] without the switch: the declaration is refused"; t "module Map" Map Get 2
echo "[C1] with BS_PROBE_USER_WINS=1"
export BS_PROBE_USER_WINS=1
t "module Map is accepted" Map Get 2
t "UsesMap: Map.Get means the user's" UsesMap Go 2
t "Std: no import of a user List, List.Sum is still the standard's" Std Go 2
t "UsesList: user List has no Sum; the standard Sum is now unreachable" UsesList Go 2
unset BS_PROBE_USER_WINS

echo; echo "################ D. does a PascalCase B# module collide with OTP's lowercase modules at the BEAM?"
rm -rf "$WS/out"; mkdir "$WS/out"
"$BSC" --src-root "$P/src" -o "$WS/out" "$P/src/Logger" >/dev/null 2>&1
ls "$WS/out" | sed 's/^/    out: /'
erl -noshell -pa "$WS/out" -eval '
  {module, L1} = code:ensure_loaded(logger),
  {module, L2} = code:ensure_loaded(list_to_atom("Logger")),
  io:format("    loaded ~p and ~p together; their file names differ only by case: ~s vs ~s~n",
            [L1, L2, filename:basename(code:which(L1)), filename:basename(code:which(L2))]),
  io:format("    OTP logger:info/1 exported? ~p; user Logger:Info/1 exported? ~p~n",
            [erlang:function_exported(logger, info, 1), erlang:function_exported(L2, '"'"'Info'"'"', 1)]),
  halt().'

echo; echo "################ E. CONTROL: the repo's own gate for exactly this surface, run against the scratch build with both switches off"
(cd "$WS/compiler" && bash bin/check-reserved-qualifiers.sh 2>&1 | tail -3; echo "gate exit=${PIPESTATUS[0]}")
