#!/usr/bin/env bash
# CLAIM (mine): Gleam's `@external(erlang, "Elixir.MyLib", "new")` names a MODULE and no application; the
# application provenance lives in gleam.toml (`[erlang] extra_applications` and `[dependencies]`), and
# the compiler checks neither against the code: an absent module builds clean and fails at run time.
# REFUTED IF: `gleam build` fails or warns for the absent module; or `applications` in the generated .app
#   ever differs from what gleam.toml says; or `[dependencies]` resolution works offline here (then not blocked).
. "$(dirname "$0")/lib.sh"
G=$WORK/gl1; rm -rf "$G"; mkdir -p "$G"; cp -r "$ROOT/fixtures/gleam/src" "$G/src"; cd "$G"
gleam --version
cat > gleam.toml <<'T'
name = "gl1"
version = "1.0.0"
target = "erlang"

[dependencies]
T
clean() { sed 's/\x1b\[[0-9;]*m//g'; }
echo "### G1: @external to a module that is nowhere; no manifest mention at all"
gleam build 2>&1 | clean; echo "[build exit=${PIPESTATUS[0]}]"
echo "-- generated .app:"; cat build/dev/erlang/gl1/ebin/gl1.app
echo "-- run, ERL_LIBS unset:"; env -u ERL_LIBS gleam run 2>&1 | clean | head -8
echo "### G2: gleam.toml gains [erlang] extra_applications = [\"mylib\"]"
printf '\n[erlang]\nextra_applications = ["mylib"]\n' >> gleam.toml
rm -rf build; gleam build 2>&1 | clean | tail -2; echo "-- generated .app:"; cat build/dev/erlang/gl1/ebin/gl1.app
echo "-- run, ERL_LIBS unset: failure moves to start-up and names the application"
env -u ERL_LIBS gleam run 2>&1 | clean | sed -n 4,8p
echo "-- run, ERL_LIBS = mix-built dep + Elixir lib dir"
ERL_LIBS=$MYLIBS:$SCRATCH/env/lib/elixir/lib gleam run 2>&1 | clean | head -8
echo "### G3: a [dependencies] entry (Hex package) offline"
sed -i 's/^\[dependencies\]/[dependencies]\ngleam_stdlib = ">= 0.34.0 and < 2.0.0"/' gleam.toml
rm -rf build; gleam build 2>&1 | clean | head -8; echo "[exit=${PIPESTATUS[0]}]"
