@external(erlang, "libdep_not_there", "hello")
pub fn hello(name: String) -> String

pub fn main() {
  hello("x")
}
