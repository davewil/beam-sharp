// Calls B#-emitted PascalCase exports from Gleam via @external(erlang, "Shop", "New").
// No gleam_stdlib: use erlang's io:format through another @external.

pub type Dyn

@external(erlang, "Shop", "New")
pub fn shop_new(id: Int) -> Dyn

@external(erlang, "Shop", "Which")
pub fn shop_which(o: Dyn) -> Dyn

@external(erlang, "Shop", "Total")
pub fn shop_total(n: Int) -> Int

@external(erlang, "erlang", "display")
fn display(x: a) -> Bool

pub fn main() {
  let o = shop_new(3)
  display(o)
  display(shop_which(o))
  display(shop_total(41))
}
