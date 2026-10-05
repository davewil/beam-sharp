#!/usr/bin/env bash
# CLAIM (neighbour survey): Gleam's `internal_modules` (gleam.toml) and `@internal` hide
# things from generated docs; they do NOT make a dependent's compile fail.
# No Gleam compiler source is installed; every statement below is only what this binary did.
# REFUTED IF: `gleam build` of the dependent package that imports `libpkg/internal` and calls
# the `@internal` fn fails or warns (then Gleam enforces, contrary to the claim).
. "$(dirname "$0")/lib.sh"
G="$WORK/gleam"; rm -rf "${G:?}"; mkdir -p "$G/libpkg/src/libpkg" "$G/app/src"
gleam --version
cat > "$G/libpkg/gleam.toml" <<'EOT'
name = "libpkg"
version = "1.0.0"
internal_modules = ["libpkg/internal", "libpkg/internal/*"]
EOT
cat > "$G/libpkg/src/libpkg.gleam" <<'EOT'
import libpkg/internal

pub fn total(xs: List(Int)) -> Int {
  internal.recompute(xs)
}

@internal
pub fn marked(x: Int) -> Int {
  x + 1
}

pub fn plain(x: Int) -> Int {
  x + 2
}
EOT
cat > "$G/libpkg/src/libpkg/internal.gleam" <<'EOT'
pub fn recompute(xs: List(Int)) -> Int {
  sum(xs, 0)
}

fn sum(xs: List(Int), acc: Int) -> Int {
  case xs {
    [] -> acc
    [x, ..rest] -> sum(rest, acc + x)
  }
}
EOT
cat > "$G/app/gleam.toml" <<'EOT'
name = "app"
version = "1.0.0"

[dependencies]
libpkg = { path = "../libpkg" }
EOT
cat > "$G/app/src/app.gleam" <<'EOT'
import libpkg
import libpkg/internal

pub fn main() {
  let a = internal.recompute([1, 2, 3])
  let b = libpkg.marked(1)
  let c = libpkg.plain(1)
  #(a, b, c)
}
EOT
echo '--- gleam build of the DEPENDENT package (separate package via path dependency; no hex needed)'
(cd "$G/app" && timeout 120 gleam build 2>&1); rc=$?; echo "exit=$rc"
(cd "$G/app" && timeout 120 gleam build 2>&1 | grep -ci -E 'warning|error|internal') ; echo "(count of warning/error/internal lines in build output; grep exit tells 0 = none)"
echo '--- gleam run (it really links and runs)'
(cd "$G/app" && timeout 60 gleam run 2>&1 | tail -3)
echo '--- docs of the library package: which names appear?'
(cd "$G/libpkg" && timeout 120 gleam docs build 2>&1 | tail -2)
for w in recompute marked plain total; do
  printf '%s in generated docs: ' "$w"; grep -l "$w" "$G"/libpkg/build/dev/docs/libpkg/*.html "$G"/libpkg/build/dev/docs/libpkg/package-interface.json 2>/dev/null | sed 's#.*/##' | tr '\n' ' '; echo
done
echo '--- modules listed in package-interface.json'
grep -o '"modules":{"[^"]*"' "$G/libpkg/build/dev/docs/libpkg/package-interface.json"
grep -o '"[a-z/]*":{"documentation"' "$G/libpkg/build/dev/docs/libpkg/package-interface.json"
[ $rc -eq 0 ]; verdict "gleam-does-not-enforce-internal-on-dependents" $?
