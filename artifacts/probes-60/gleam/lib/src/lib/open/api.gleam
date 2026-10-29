@internal
pub fn secret(x: Int) -> Int {
  x * 2
}

pub fn open(x: Int) -> Int {
  secret(x)
}

fn hidden(x: Int) -> Int {
  x
}
