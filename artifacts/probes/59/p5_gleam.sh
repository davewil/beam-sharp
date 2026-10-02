#!/usr/bin/env bash
# P5 - Gleam 1.12: do pub and private functions get guards? (expected: neither) and what does a
# forged sub-term do when it reaches the private function through the public one?
# Needs GLEAM=/path/to/gleam (default: the sandbox copy). Skips with exit 0 + SKIP line if absent.
set -eu
GLEAM="${GLEAM:-/tmp/claude-0/-home-user-beam-sharp/a3310f8a-c503-5acc-8cf0-37e76fb5554b/scratchpad/tc/gleam}"
[ -x "$GLEAM" ] || { echo "SKIP: gleam not found at $GLEAM"; exit 0; }
W="${1:-$(mktemp -d)}/p5"; rm -rf "$W"; mkdir -p "$W/src"; cd "$W"
printf 'name = "probe59"\nversion = "1.0.0"\n' > gleam.toml
cat > src/probe59.gleam <<'X'
pub type Customer {
  Customer(email: String)
}

pub type Order {
  Order(id: Int, customer: Customer)
}

pub fn ship(o: Order) -> String {
  notify(o.customer)
}

fn notify(c: Customer) -> String {
  c.email
}

pub fn add(a: Int, b: Int) -> Int {
  inc(a) + b
}

fn inc(a: Int) -> Int {
  a + 1
}
X
"$GLEAM" --version
"$GLEAM" build 2>&1 | tail -2
ERL=build/dev/erlang/probe59/_gleam_artefacts/probe59.erl
echo "---- generated $ERL (functions only)"; sed -n '/^-spec/,$p' "$ERL"
n=$(grep -c ' when ' "$ERL" || true)
echo "guards ('when') in generated Erlang: $n"
[ "$n" = 0 ] || { echo "FAIL: Gleam emitted a guard"; exit 1; }
echo "---- run: forged sub-term reaches private notify/1 through public ship/1"
erl -noshell -pa build/dev/erlang/probe59/ebin -eval '
  R1 = (catch probe59:ship({order, 1, {customer, <<"a">>}})),
  R2 = (catch probe59:ship({order, 1, {vendor, <<"v">>}})),
  R3 = (catch probe59:add(1.5, 2.5)),
  io:format("ship(right)=~p~nship(Vendor-shaped customer)=~p~nadd(1.5,2.5)=~p~n", [R1, R2, R3]),
  case {R1, R2, R3} of {<<"a">>, <<"v">>, 5.0} -> io:format("ASSERT ok~n"), halt(0);
                       _ -> io:format("FAIL~n"), halt(1) end.'
