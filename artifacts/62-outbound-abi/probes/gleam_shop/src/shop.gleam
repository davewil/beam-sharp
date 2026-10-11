pub type Doc {
  Order(id: Int, total: Int)
  Invoice(id: Int)
  PaidInFull
  HttpError(code: Int)
  NewHTTPThing
}

pub fn new_order(id: Int) -> Doc {
  Order(id, 0)
}

pub fn parse_url(_s: String) -> Result(Int, String) {
  Ok(1)
}

pub fn maybe(x: Bool) -> Result(Int, String) {
  case x {
    True -> Ok(1)
    False -> Error("no")
  }
}
