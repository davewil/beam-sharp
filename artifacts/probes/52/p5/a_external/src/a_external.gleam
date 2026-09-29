@external(erlang, "Elixir.Nope", "count")
fn count(xs: List(Int)) -> Int

pub fn main() -> Int {
  count([1, 2, 3])
}
