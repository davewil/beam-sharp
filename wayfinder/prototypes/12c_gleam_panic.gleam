//// PROTOTYPE 12c -- Gleam's crash construct is a KEYWORD, and it is bottom-typed.
////
//// Ticket 12. Evidence that the nearest neighbour chose a keyword over an
//// ordinary function typed `-> none`. Provenance: local, Gleam 1.18.1.
////
//// Reproduce:
////   gleam new gpanic --name gpanic
////   cp 12c_gleam_panic.gleam gpanic/src/gpanic.gleam
////   cd gpanic && gleam build && gleam run
////
//// Observed: this COMPILES. The `panic` arm sits alongside arms returning
//// String, so `panic` unifies with String -- i.e. it is bottom-typed exactly
//// as beam-sharp's `raise` must be.
////
//// Why it matters: Gleam is a statically typed BEAM language with a real type
//// system, so it had the option of making this an ordinary function typed to
//// the empty type and declined. Elixir spells it `raise`; Gleam spells it
//// `panic`; both are keywords. That is the closest available evidence, and it
//// points away from the function form -- which was rejected on read cost
//// (a crash body lexically identical to a call, callee signature in another
//// file under one-function-per-file, no single token finding every crash site).
////
//// beam-sharp takes Elixir's `raise` over Gleam's `panic`: `panic` connotes an
//// impossible state, where the common case here is an ordinary foreign term
//// arriving, and Elixir is the larger interop surface (ticket 06).

pub fn classify(n: Int) -> String {
  case n {
    0 -> "zero"
    1 -> "one"
    _ -> panic as "unexpected"
  }
}

pub fn main() {
  echo classify(0)
}
