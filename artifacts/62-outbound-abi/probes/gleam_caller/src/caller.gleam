// Calls into B# (module Abi, compiled by bsc) with @external(erlang, "Mod", "Fn").
// Return types are type variables: Gleam trusts the declaration, so the
// declaration is where a Gleam author states what the B# erasure table says.

@external(erlang, "Abi", "MakePoint")
pub fn make_point(x: Int) -> point

@external(erlang, "Abi", "NewHTTP")
pub fn new_http(x: Int) -> Int

@external(erlang, "Abi", "ParseURL")
pub fn parse_url(x: Int) -> Int

@external(erlang, "Abi", "MaybeInt")
pub fn maybe_int(b: Bool) -> Result(Int, Nil)

@external(erlang, "Abi", "Res")
pub fn res(b: Bool) -> Result(Int, atom)

@external(erlang, "Abi", "Pair")
pub fn pair(x: Int) -> #(Int, String)

@external(erlang, "Abi", "IsBig")
pub fn is_big(x: Int) -> Bool

@external(erlang, "erlang", "display")
pub fn display(a: a) -> a

pub fn main() {
  display(make_point(3))
  display(new_http(41))
  display(parse_url(7))
  display(pair(2))
  display(is_big(10))
  // The next two are the interesting ones: the B# erasure is NOT Gleam's Result/Option
  // shape. Gleam believes these are Result(..), the BEAM disagrees.
  display(maybe_int(True))
  display(maybe_int(False))
  display(res(True))
  display(res(False))
}
