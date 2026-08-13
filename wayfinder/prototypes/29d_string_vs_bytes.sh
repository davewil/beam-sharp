#!/usr/bin/env bash
# 29d — what C# and TypeScript do when bytes are *not* valid text.
#
# Ticket 20 §4 decided `string = binary where valid_utf8` on the `json:encode/1` evidence
# alone. Ticket 29 §5 asks whether the borrow heuristic supports it independently — C# has
# `string` and `byte[]`, TypeScript has `string` and `Uint8Array` — and what each does in
# the case ticket 20's generated entry check exists for.
#
# Measured rather than cited, because the interesting half is the *default*, and the
# default is not what a reader of either standard library would guess.
#
# Usage:  ./29d_string_vs_bytes.sh
# Needs:  node; dotnet SDK optional (its section is skipped if absent).

set -u
cd "$(dirname "$0")"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/t.mjs" <<'JS'
const bad = new Uint8Array([0xff, 0xfe, 0x00, 0x01]);   // not valid UTF-8

const show = (label, f) => {
  try { console.log(label.padEnd(44), "->", JSON.stringify(f())); }
  catch (e) { console.log(label.padEnd(44), "-> THREW", e.constructor.name + ": " + e.message); }
};

show("TextDecoder() default",                 () => new TextDecoder().decode(bad));
show("TextDecoder('utf-8', {fatal:true})",    () => new TextDecoder('utf-8', {fatal:true}).decode(bad));
show("Buffer.from(bad).toString('utf8')",     () => Buffer.from(bad).toString('utf8'));
show("JSON.stringify(decoded)",               () => JSON.stringify(new TextDecoder().decode(bad)));
show("JSON.stringify(lone surrogate)",        () => JSON.stringify("\uD800"));
show("JSON.stringify(Uint8Array)",            () => JSON.stringify(bad));
show("the Uint8Array itself, untouched",      () => Array.from(bad));
console.log("node", process.version);
JS

echo "=== TypeScript / JavaScript ==="
node "$WORK/t.mjs"

if ! command -v dotnet >/dev/null 2>&1; then
  echo
  echo "=== C# === (skipped: no dotnet on PATH)"
  exit 0
fi

mkdir -p "$WORK/cs"
cat > "$WORK/cs/Program.cs" <<'CS'
using System.Text;
using System.Text.Json;

byte[] bad = { 0xff, 0xfe, 0x00, 0x01 };   // not valid UTF-8

void Show(string label, Func<string> f) {
    try { Console.WriteLine($"{label,-44} -> {JsonSerializer.Serialize(f())}"); }
    catch (Exception e) { Console.WriteLine($"{label,-44} -> THREW {e.GetType().Name}: {e.Message}"); }
}

Show("Encoding.UTF8.GetString (default)",       () => Encoding.UTF8.GetString(bad));
Show("new UTF8Encoding(false, true).GetString", () => new UTF8Encoding(false, true).GetString(bad));
Show("GetEncoding(\"utf-8\", ExceptionFallback)", () => Encoding.GetEncoding("utf-8",
        EncoderFallback.ExceptionFallback, DecoderFallback.ExceptionFallback).GetString(bad));
Show("JsonSerializer.Serialize(lone surrogate)", () => JsonSerializer.Serialize("\ud800"));
Show("JsonSerializer.Serialize(byte[])",         () => JsonSerializer.Serialize(bad));
Console.WriteLine($"the byte[] itself, untouched                 -> [{string.Join(",", bad)}]");
Console.WriteLine($".NET {Environment.Version}");
CS
cat > "$WORK/cs/p.csproj" <<'PROJ'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
</Project>
PROJ

echo
echo "=== C# ==="
dotnet run --project "$WORK/cs" 2>&1 | grep -v '^ *$' | tail -8
