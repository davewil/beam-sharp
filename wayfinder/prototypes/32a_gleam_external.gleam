// A foreign declaration: Gleam name differs from the Erlang name, and the
// Gleam type is a claim nothing checks (ticket 18 measured that).
@external(erlang, "lists", "keyfind")
pub fn key_find(key: a, n: Int, list: List(b)) -> b

// Same foreign function, a SECOND Gleam name and a DIFFERENT claimed type.
@external(erlang, "lists", "keyfind")
pub fn key_find_as_int(key: a, n: Int, list: List(b)) -> Int

// A foreign function used only inside this module, never exported.
@external(erlang, "erlang", "byte_size")
fn size_of(b: BitArray) -> Int

pub fn main() {
  let l = [#(1, "one"), #(2, "two")]
  let _ = key_find(2, 1, l)
  size_of(<<"abc":utf8>>)
}
