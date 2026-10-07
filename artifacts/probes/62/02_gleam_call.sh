#!/usr/bin/env bash
# Actually RUN a Gleam call into a B# PascalCase export (62a only compiled the declaration,
# and its `gleam new` pulls gleam_stdlib from hex which fails offline). This project has NO deps.
export PATH=$HOME/.nix-profile/bin:$PATH
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../../.."
BSC="$ROOT/compiler/_build/default/bin/bsc"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/ebin" "$W/caller/src"
"$BSC" --src-root "$ROOT/compiler/examples" -o "$W/ebin" "$ROOT/compiler/examples/Shop" >/dev/null 2>&1
gleam --version
cat > "$W/caller/gleam.toml" <<'T'
name = "caller"
version = "1.0.0"
T
cat > "$W/caller/src/caller.gleam" <<'G'
@external(erlang, "Shop", "New")
pub fn shop_new(id: Int) -> a

@external(erlang, "Shop", "Which")
pub fn shop_which(o: a) -> b

pub fn main() {
  shop_which(shop_new(3))
}
G
(cd "$W/caller" && gleam build 2>&1 | sed 's/^/gleam build: /')
echo "--- run the compiled Gleam module against B# beams:"
erl -noshell -pa "$W/ebin" -pa "$W/caller/build/dev/erlang/caller/ebin" \
  -eval 'io:format("caller:main() -> ~p~n",[caller:main()]), halt().'
echo "--- gleam-emitted export table of caller:"
erl -noshell -pa "$W/caller/build/dev/erlang/caller/ebin" -eval 'io:format("~p~n",[caller:module_info(exports)]),halt().'
