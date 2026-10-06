#!/usr/bin/env bash
# PROBE 62-02 — Claim (ticket 62 candidate 2, citing ticket 10 §7): "Gleam downcases when it
# emits to the BEAM: PascalCase becomes snake_case", offered as precedent for emitting snake_case
# function aliases.
# TESTS: (a) what Gleam emits for FUNCTION names, (b) for CONSTRUCTOR tags (acronyms, digits),
#        (c) module path a/b -> a@b, (d) whether Gleam accepts a PascalCase fn name at all,
#        (e) whether a Gleam caller can actually RUN @external(erlang,"Shop","New") (ticket: not run).
# CONTROLS: (d) is the control for (a): if Gleam allowed `pub fn New`, "no downcasing of fns" would
#        be unfalsifiable; (e) fails loudly (runtime error) if the call did not happen — we also call a
#        nonexistent 'Nope' and require it to crash.
# Gleam compiler source is NOT installed here; this probe reads the emitted .erl instead.
set -uo pipefail
source /tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
echo "gleam: $(gleam --version)"
P="$W/pkg"; mkdir -p "$P/src/a"
printf 'name = "pkg"\nversion = "1.0.0"\n' > "$P/gleam.toml"
cat > "$P/src/pkg.gleam" <<'GL'
pub type Order {
  Order(id: Int, total: Int)
  HTTPGetError
  Md5Sum
  New2(Int)
  Pending
  ABc
  AbC
  XMLHttp(Int)
}
pub fn new(id: Int) -> Order { Order(id, 0) }
pub fn http_get(x: Int) -> Order { Order(x, x) }
pub fn md5_sum() -> Order { Md5Sum }
pub fn new2(x: Int) -> Order { New2(x) }
pub fn tags() -> List(Order) { [HTTPGetError, Md5Sum, New2(1), Pending, Order(1,2), ABc, AbC, XMLHttp(1)] }
GL
echo 'pub fn hello() { 1 }' > "$P/src/a/b.gleam"
(cd "$P" && gleam build 2>&1 | tail -2)
E="$P/build/dev/erlang/pkg/_gleam_artefacts"
echo "--- (a)(b) emitted pkg.erl: exports, type, constructor atoms"
grep -n -- '^-export(\|^-type' "$E/pkg.erl"; sed -n '/^tags()/,/^$/p' "$E/pkg.erl"
echo "--- (c) module path a/b"
ls "$E" | grep -v main; grep -n -- '-module' "$E/a@b.erl"
echo "--- (d) CONTROL: does Gleam accept a PascalCase function name?"
echo 'pub fn New(id: Int) -> Int { id }' > "$P/src/bad.gleam"
(cd "$P" && gleam build 2>&1 | grep -m2 -i 'expecting\|error'); rm "$P/src/bad.gleam"
echo "--- (e) run a Gleam caller of PascalCase B# exports (stdlib is not installed, so no gleam/io)"
OUT="$W/ebin"; mkdir -p "$OUT"
$BSC --src-root compiler/examples -o "$OUT" compiler/examples/Shop >/dev/null 2>&1
C="$W/caller"; mkdir -p "$C/src"
printf 'name = "caller"\nversion = "1.0.0"\n' > "$C/gleam.toml"
cat > "$C/src/caller.gleam" <<'GL'
@external(erlang, "Shop", "New")
fn shop_new(id: Int) -> a
@external(erlang, "Shop", "Nope")
fn shop_nope(id: Int) -> a
@external(erlang, "erlang", "display")
fn display(x: a) -> b
pub fn main() {
  display(shop_new(3))
  display(shop_nope(3))
}
GL
(cd "$C" && gleam build 2>&1 | tail -1)
cd "$W"
erl -noshell -pa "$C/build/dev/erlang/caller/ebin" -pa "$OUT" -eval 'try caller:main() catch C:R -> io:format("CONTROL (Shop:Nope must crash): ~p~n",[{C,R}]) end, halt().' 2>&1 | head -6
