#!/usr/bin/env bash
# Probe (c), Gleam 1.19.1: what does gleam.toml record, and what does the build say when
# @external(erlang, "nonexistent_mod", "f") names a module that exists nowhere?
# Run: ./p3c_gleam.sh
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
W="$FX/gleam"; rm -rf "$W"; mkdir -p "$W"; cd "$W"
gleam --version
echo "== 1. a project with NO dependencies and an @external to a module that exists nowhere"
mkdir app1 && cd app1
cat > gleam.toml <<'T'
name = "app1"
version = "1.0.0"
target = "erlang"

[dependencies]
T
mkdir src && cat > src/app1.gleam <<'G'
@external(erlang, "nonexistent_mod", "f")
fn f(x: Int) -> Int

pub fn main() -> Int {
  f(1)
}
G
gleam build 2>&1 | sed 's/^/   /'; echo "   gleam build exit=${PIPESTATUS[0]}"
echo "-- run it"
erl -noshell -pa build/dev/erlang/app1/ebin -eval 'try app1:main() catch C:E:S -> io:format("   ~p:~p ~p~n",[C,E,hd(S)]) end, halt().'
echo "-- the .app gleam wrote (what the build records about dependencies):"
cat build/dev/erlang/app1/ebin/app1.app | sed 's/^/   /'
echo
echo "== 2. NEGATIVE CONTROL: same shape, @external to a module that exists (erlang:abs)"
cd "$W" && mkdir app2 && cd app2
cp ../app1/gleam.toml gleam.toml && sed -i 's/app1/app2/' gleam.toml
mkdir src && cat > src/app2.gleam <<'G'
@external(erlang, "erlang", "abs")
fn f(x: Int) -> Int

pub fn main() -> Int {
  f(-1)
}
G
gleam build 2>&1 | sed 's/^/   /'; echo "   gleam build exit=${PIPESTATUS[0]}"
echo
echo "== 3. a LOCAL path dependency (hex is unreachable): gleam.toml [dependencies] and what the .app gets"
cd "$W" && mkdir -p dep3/src app3/src
cat > dep3/gleam.toml <<'T'
name = "dep3"
version = "0.1.0"
target = "erlang"
[dependencies]
T
echo 'pub fn id(x: Int) -> Int { x }' > dep3/src/dep3.gleam
cat > app3/gleam.toml <<'T'
name = "app3"
version = "1.0.0"
target = "erlang"
[dependencies]
dep3 = { path = "../dep3" }
T
cat > app3/src/app3.gleam <<'G'
import dep3
pub fn main() -> Int { dep3.id(7) }
G
( cd app3 && gleam build 2>&1 | sed 's/^/   /'; echo "   exit=${PIPESTATUS[0]}"; cat build/dev/erlang/app3/ebin/app3.app | sed 's/^/   /' )
echo
echo "== 4. importing a Gleam module whose package is NOT in [dependencies]"
cd "$W" && mkdir -p app4/src && cat > app4/gleam.toml <<'T'
name = "app4"
version = "1.0.0"
target = "erlang"
[dependencies]
T
cat > app4/src/app4.gleam <<'G'
import dep3
pub fn main() -> Int { dep3.id(7) }
G
( cd app4 && gleam build 2>&1 | sed 's/^/   /'; echo "   exit=${PIPESTATUS[0]}" )
echo
echo "== 5. a hex version constraint, network blocked here: what does the toml accept and where does it fail?"
cd "$W" && mkdir -p app5/src && cat > app5/gleam.toml <<'T'
name = "app5"
version = "1.0.0"
target = "erlang"
[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
T
echo 'pub fn main() { 1 }' > app5/src/app5.gleam
( cd app5 && timeout 60 gleam build 2>&1 | head -8 | sed 's/^/   /'; echo "   exit=${PIPESTATUS[0]}" )
