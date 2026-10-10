pub type Order {
  Order(id: Int, total: Int)
}

pub opaque type Money {
  Money(cents: Int)
}

pub fn new_money(c: Int) -> Money {
  Money(c)
}

fn priv_cents(o: Order) -> Int {
  o.total * 100
}

pub fn pub_cents(o: Order) -> Int {
  o.total * 100
}

pub fn via_priv(o: Order) -> Int {
  priv_cents(o)
}

fn priv_inc(n: Int) -> Int {
  n + 1
}

pub fn pub_inc(n: Int) -> Int {
  n + 1
}

pub fn run_inc(n: Int) -> Int {
  priv_inc(n)
}

pub fn money_cents(m: Money) -> Int {
  m.cents
}
