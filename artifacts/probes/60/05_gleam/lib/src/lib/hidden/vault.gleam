pub type Secret {
  Secret(Int)
}

pub fn make() -> Secret {
  Secret(1)
}

pub fn open(x: Int) -> Int {
  x + 1
}
