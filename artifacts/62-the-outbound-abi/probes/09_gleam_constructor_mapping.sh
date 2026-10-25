#!/usr/bin/env bash
# Probe 09: ground truth for Gleam's PascalCase->snake_case rule (it applies to CONSTRUCTORS, i.e. data atoms),
# on exactly the names the ticket lists (ToJson, HTTPGet, IOError, Take2) plus collision pairs.
# Usage: 09_gleam_constructor_mapping.sh <scratch-dir>
set -u
G=${1:?}; rm -rf "$G"; mkdir -p "$G/src"
printf 'name = "caller"\nversion = "1.0.0"\n[dependencies]\n' > "$G/gleam.toml"
cat > "$G/src/caller.gleam" <<'T'
pub type Names {
  ToJson HTTPGet IOError Take2 GetID GetId Foo A AB URLs Ver1Beta ParseURL ParseUrl
}
pub fn all() -> List(Names) {
  [ToJson, HTTPGet, IOError, Take2, GetID, GetId, Foo, A, AB, URLs, Ver1Beta, ParseURL, ParseUrl]
}
T
(cd "$G" && gleam build 2>&1 | tail -2)
erl -noshell -pa "$G/build/dev/erlang/caller/ebin" -eval 'io:format("~p~n",[caller:all()]), halt().'
echo "=== NEGATIVE: gleam refuses an underscore in a constructor name (so Get_Id has no Gleam analogue)"
printf 'pub type N { Get_Id }\n' > "$G/src/caller.gleam"
(cd "$G" && gleam build 2>&1 | head -8)
