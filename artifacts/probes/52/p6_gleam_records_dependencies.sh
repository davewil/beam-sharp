#!/usr/bin/env bash
# p6 — Gleam 1.18.1 (offline, path dependency only; hex.pm is unreachable and the gleam compiler's Rust sources are NOT installed,
# so no file:line is cited -- behaviour is shown by running it).
#   G1  gleam.toml [dependencies] -> generated ebin/<app>.app carries them in `applications`; [erlang] extra_applications appends
#   G2  CONTROL: delete the dependency -> the .app loses it (so G1 reads the manifest and not something incidental)
#   G3  `@external(erlang, "fakelib_mod", "hello")` -- the construct ticket 32 borrowed -- names a module in NO declared app and
#       Gleam compiles it with no diagnostic: provenance is not carried by the external declaration, it is carried by gleam.toml
#   G4  the compiled program fails at call time with undef (a value-level crash), exactly as B# does today
#   G5  gleam writes a manifest.toml next to gleam.toml (resolution output; the thing ticket 51 refused to build)
source "$(dirname "$0")/common.sh"; mk_fakelib
export HOME="$WORK/home"; mkdir -p "$HOME" "$WORK/dep/src" "$WORK/app/src"
printf 'name = "dep"\nversion = "1.0.0"\n' > "$WORK/dep/gleam.toml"
echo 'pub fn hi() -> Int { 1 }' > "$WORK/dep/src/dep.gleam"
printf 'name = "app"\nversion = "1.0.0"\n\n[dependencies]\ndep = { path = "../dep" }\n\n[erlang]\nextra_applications = ["inets"]\n' > "$WORK/app/gleam.toml"
cat > "$WORK/app/src/app.gleam" <<'EOT'
import dep

@external(erlang, "fakelib_mod", "hello")
pub fn hello() -> Int

pub fn main() -> Int { dep.hi() + hello() }
EOT
cd "$WORK/app"
o=$(gleam build 2>&1); echo "$o" | tail -4
expect_not "G3 no diagnostic about fakelib_mod" "fakelib" "$o"
echo "--- generated .app:"; tr -s ' \n' ' ' < build/dev/erlang/app/ebin/app.app; echo
expect "G1 .app lists the declared dep" "dep" "$(cat build/dev/erlang/app/ebin/app.app)"
expect "G1 .app lists extra_applications" "inets" "$(cat build/dev/erlang/app/ebin/app.app)"
expect_not "G3 .app does not list fakelib (it was never declared)" "fakelib" "$(cat build/dev/erlang/app/ebin/app.app)"
echo "--- G5 manifest.toml:"; cat manifest.toml
expect "G5 manifest exists" "dep" "$(cat manifest.toml)"
echo "--- G4 run with fakelib absent, then present"
a=$(erl -noshell -pa build/dev/erlang/*/ebin -eval 'io:format("~p",[catch app:hello()]),halt().' 2>&1 | head -c 200); echo "absent : $a"
b=$(erl -noshell -pa build/dev/erlang/*/ebin -pa "$WORK/libs/fakelib-1.0/ebin" -eval 'io:format("~p",[catch app:hello()]),halt().' 2>&1 | head -c 200); echo "present: $b"
expect "G4 absent -> undef" "undef" "$a"; expect "G4 control: present -> 42" "42" "$b"
echo "== G2 control: remove the dependency"
printf 'name = "app"\nversion = "1.0.0"\n' > gleam.toml
printf '@external(erlang, "fakelib_mod", "hello")\npub fn hello() -> Int\n' > src/app.gleam
rm -rf build manifest.toml; gleam build >/dev/null 2>&1
echo "--- .app now:"; tr -s ' \n' ' ' < build/dev/erlang/app/ebin/app.app; echo
expect "G2 dependency gone from .app" "{applications, []}" "$(cat build/dev/erlang/app/ebin/app.app)"
finish
