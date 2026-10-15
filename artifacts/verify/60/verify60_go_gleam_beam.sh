#!/usr/bin/env bash
# Verifier: (1) Go nested-internal rule, (2) Gleam unfiltered output / other commands, (3) brief's "Twice -> call_only Pub" claim.
. /home/user/beam-sharp/artifacts/probes/env.sh; H=/home/user/beam-sharp/artifacts/probes
export PATH=/usr/local/go/bin:$PATH GOFLAGS=-mod=mod GOTOOLCHAIN=local GOPROXY=off
S=$(mktemp -d /tmp/verify60go.XXXXXX); cd $S
printf 'module example.com/m\ngo 1.20\n' > go.mod
mkdir -p a/internal/other a/internal/b/internal/c
printf 'package c\nfunc C() int { return 1 }\n' > a/internal/b/internal/c/c.go
printf 'package other\nimport "example.com/m/a/internal/b/internal/c"\nfunc O() int { return c.C() }\n' > a/internal/other/o.go
echo "=== Go: a/internal/other imports a/internal/b/internal/c (prototype would ALLOW; Go rule is parent of LAST internal)"; go build ./a/internal/other 2>&1; echo "exit $?"
G=$(mktemp -d /tmp/verify60gleam.XXXXXX); cd $G
mkdir -p libpkg/src/libpkg/internal app/src
printf 'name = "libpkg"\nversion = "1.0.0"\ninternal_modules = ["libpkg/internal", "libpkg/internal/*"]\n[dependencies]\n' > libpkg/gleam.toml
printf 'pub fn open() -> Int { 1 }\n' > libpkg/src/libpkg.gleam
printf 'pub fn helper() -> Int { 41 }\n' > libpkg/src/libpkg/internal/secret.gleam
printf 'name = "app"\nversion = "1.0.0"\n[dependencies]\nlibpkg = { path = "../libpkg" }\n' > app/gleam.toml
printf 'import libpkg/internal/secret\npub fn main() -> Int { secret.helper() }\n' > app/src/app.gleam
echo "=== Gleam: path dep, FULL unfiltered output of gleam build / gleam check / gleam run"
(cd app && gleam build 2>&1; echo "build exit $?"; gleam check 2>&1; echo "check exit $?"; gleam run 2>&1 | tail -3; echo "run exit ${PIPESTATUS[0]}")
echo "=== Gleam: same package, internal module imported by a public module and a test"
mkdir -p libpkg/test; printf 'import libpkg/internal/secret\npub fn main() { let _ = secret.helper() }\n' > libpkg/test/libpkg_test.gleam
(cd libpkg && gleam build 2>&1; echo "exit $?")
echo "=== Gleam: warning text search in binary for 'internal' import diagnostics"
strings -n 8 "$(readlink -f $(which gleam))" | grep -iE 'internal (module|type|function).{0,80}(import|another package|outside)' | sort -u | head
echo "=== BEAM: Twice/1 disassembly (brief claims call_only to Pub guarded entry)"
B=$(mktemp -d /tmp/verify60beam.XXXXXX); mkdir -p $B/src/Guard $B/out
cat > $B/src/Guard/G.bs <<'B'
module Guard

public int Pub(int n)
Pub(n) -> Priv(n) + 1

private int Priv(int n)
Priv(n) -> n * 2

public int Twice(int n)
Twice(n) -> Pub(n)
B
$BSC --src-root $B/src -o $B/out $B/src/Guard >/dev/null
erl -noshell -eval '{beam_file,_,_,_,_,C}=beam_disasm:file("'$B'/out/Guard.beam"), [io:format("~s/~p~n  ~p~n",[N,A,Body]) || {function,N,A,_,Body} <- C, lists:member(N,[(list_to_atom("Pub")),(list_to_atom("Twice"))])], halt().'
