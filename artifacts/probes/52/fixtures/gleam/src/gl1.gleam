@external(erlang, "Elixir.MyLib", "new")
fn new(opts: List(Int)) -> Dynamic

pub type Dynamic

pub fn main() {
  new([])
}
