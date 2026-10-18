pub type Order {
  Order(id: Int, total: Int)
}

pub fn pub_total(o: Order) -> Int {
  priv_total(o)
}

fn priv_total(o: Order) -> Int {
  o.total
}

pub fn double(n: Int) -> Int {
  priv_double(n)
}

fn priv_double(n: Int) -> Int {
  n + n
}
