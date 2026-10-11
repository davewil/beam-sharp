pub type Order {
  Order(id: Int, total: Int)
}

pub type Batch {
  Batch(name: Int, first: Order)
}

pub opaque type Money {
  Money(cents: Int)
}

pub fn entry(b: Batch) -> Int {
  inner(b.first)
}

fn inner(o: Order) -> Int {
  o.total
}

pub fn pub_int(n: Int) -> Int {
  priv_int(n)
}

fn priv_int(n: Int) -> Int {
  n + 1
}

pub fn money(c: Int) -> Money {
  Money(c)
}

pub fn cents(m: Money) -> Int {
  m.cents
}

// control for the guard counter: a user-written guard IS emitted as a `when`
pub fn pos(n: Int) -> Int {
  case n {
    x if x > 0 -> x
    _ -> 0
  }
}
