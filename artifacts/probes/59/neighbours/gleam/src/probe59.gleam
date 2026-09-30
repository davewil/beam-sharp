// Probe 59: does Gleam emit any runtime type test on a function parameter, exported or private?
pub opaque type Order {
  Order(id: Int, total: Int)
}

pub type Invoice {
  Invoice(id: Int, total: Int)
}

pub fn new(id: Int) -> Order {
  Order(id, 0)
}

pub fn pub_total(o: Order) -> Int {
  o.total
}

fn priv_total(o: Order) -> Int {
  o.total
}

pub fn use_it(o: Order) -> Int {
  priv_total(o)
}

pub fn pub_inv(i: Invoice) -> Int {
  i.total
}

pub fn pub_int(n: Int) -> Int {
  n + 1
}

fn priv_int(n: Int) -> Int {
  n + 1
}

pub fn use_int(n: Int) -> Int {
  priv_int(n)
}
