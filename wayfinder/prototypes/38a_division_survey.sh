#!/usr/bin/env bash
# 38a — the divide-and-remainder survey, re-run rather than cited.
#
#     wayfinder/prototypes/38a_division_survey.sh
#
# Ticket 38 was raised 2026-08-15 with a four-language table taken that day, and
# its own Notes demand the table be re-measured before the ticket is resolved.
# This is that measurement, kept as a script so the next reader re-runs it
# instead of trusting a paste. Re-run 2026-08-23 against OTP 28 / erts-16.4,
# node, dotnet 9.0.306 and Python 3.
#
# THE ROW THE ORIGINAL TABLE GOT WRONG is JavaScript's. `-7 / 2` in JS is
# `-3.5` because `/` on Numbers is FLOAT division, and beam-sharp has no float.
# The honest comparison for a language whose only numeric type is an integer is
# BigInt — and BigInt truncates and THROWS on zero, which moves JavaScript from
# the "diverges" column into the "agrees" one.
set -euo pipefail

echo "== Erlang (OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')) =="
erl -noshell -eval '
  io:format("  -7 div 2 = ~p   -7 rem 2 = ~p~n", [-7 div 2, -7 rem 2]),
  io:format("  -7 / 2   = ~p   (float division -- NOT what beam-sharp / will mean)~n", [-7 / 2]),
  {'"'"'EXIT'"'"', {Why, _}} = (catch (7 div 0)),
  io:format("  7 div 0  -> ~p~n", [Why]),
  halt().'

echo "== JavaScript (node $(node --version)) =="
node -e '
  console.log("  Number: -7/2 =", -7/2, "  -7%2 =", -7%2, "  7/0 =", 7/0, "  0/0 =", 0/0);
  console.log("  BigInt: -7n/2n =", String(-7n/2n), "  -7n%2n =", String(-7n%2n));
  try { void (7n/0n); } catch (e) { console.log("  BigInt: 7n/0n ->", e.constructor.name); }
'

echo "== Python 3 (the outlier, and not an audience) =="
python3 -c 'print("  -7//2 =", -7//2, "  -7%2 =", -7%2, "  (floored, not truncated)")'

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "== Erlang: what erlc catches at COMPILE time =="
cat > "$work/divzero.erl" <<'EOF'
-module(divzero).
-export([literal/0, variable/1]).
literal() -> 7 div 0.
variable(X) -> X div 0.
EOF
( cd "$work" && erlc -W divzero.erl 2>&1 | sed 's/^/  /' )
echo "  NOTE: only literal/0 warns. variable/1 -- a LITERAL zero divisor with a"
echo "  variable dividend -- passes erlc silently. beam-sharp's intervals catch it."

echo "== C#: what csc catches at COMPILE time =="
mkdir -p "$work/cs"
cat > "$work/cs/p.csproj" <<'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net9.0</TargetFramework></PropertyGroup>
</Project>
EOF
cat > "$work/cs/Program.cs" <<'EOF'
class P { static void Main() { System.Console.WriteLine(7/0); } }
EOF
( cd "$work/cs" && dotnet build 2>&1 | grep -oE 'error CS[0-9]+: .*' | head -1 | sed 's/^/  /' ) || true
echo "  NOTE: C# makes division by CONSTANT zero a compile ERROR, not merely a"
echo "  runtime DivideByZeroException. The ticket recorded only the exception."
