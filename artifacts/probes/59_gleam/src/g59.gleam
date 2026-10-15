// Gleam survey for ticket 59: does Gleam emit ANY runtime guard on a typed parameter,
// exported (pub fn) or private (fn)?
pub type Order {
  Order(id: Int, total: Int)
}

pub type Invoice {
  Invoice(id: Int, total: Int)
}

pub opaque type Sealed {
  Sealed(id: Int, total: Int)
}

fn priv(o: Order) -> Int {
  o.total
}

pub fn direct(o: Order) -> Int {
  priv(o)
}

pub fn pub_total(o: Order) -> Int {
  o.total
}

pub fn pub_case(o: Order) -> Int {
  case o {
    Order(_, t) -> t
  }
}

pub fn add(a: Int, b: Int) -> Int {
  a + b
}

fn priv_add(a: Int, b: Int) -> Int {
  a + b
}

pub fn via_list(xs: List(Int)) -> Int {
  case xs {
    [x, ..] -> priv_add(x, 1)
    [] -> 0
  }
}

pub fn sealed_total(s: Sealed) -> Int {
  s.total
}

pub fn seal(id: Int, total: Int) -> Sealed {
  Sealed(id, total)
}
