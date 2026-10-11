@external(erlang, "nonexistent_mod", "f")
fn f(x: Int) -> Int

pub fn main() -> Int {
  f(1)
}
