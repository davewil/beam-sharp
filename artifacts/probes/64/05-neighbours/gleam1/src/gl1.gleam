// Dependency-free: Result and Nil are in the Gleam compiler's built-in prelude.
pub type Term {
  Atom(String)
  Int(Int)
}

pub fn find(xs: List(#(String, v)), key: String) -> Result(v, Nil) {
  case xs {
    [] -> Error(Nil)
    [#(k, v), ..] if k == key -> Ok(v)
    [_, ..rest] -> find(rest, key)
  }
}

pub fn describe(xs: List(#(String, Result(Int, Nil))), key: String) -> String {
  case find(xs, key) {
    Error(Nil) -> "absent"
    Ok(Error(Nil)) -> "present, value is itself Error(Nil)"
    Ok(Ok(_)) -> "present, Ok"
  }
}

pub fn main() {
  let present_error = [#("k", Error(Nil))]
  describe(present_error, "k")
}
