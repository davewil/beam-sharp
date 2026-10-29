pub type Order {
  Order(id: Int, amount: Int)
}

pub opaque type Secret {
  Secret(amount: Int)
}

pub fn pub_total(o: Order) -> Int {
  priv_total(o)
}

fn priv_total(o: Order) -> Int {
  o.amount
}

pub fn pub_secret(s: Secret) -> Int {
  priv_secret(s)
}

fn priv_secret(s: Secret) -> Int {
  s.amount
}

pub fn pub_int(n: Int) -> Int {
  priv_int(n)
}

fn priv_int(n: Int) -> Int {
  n + 1
}

pub fn first(os: List(Order)) -> Int {
  case os {
    [h, ..] -> priv_total(h)
    [] -> 0
  }
}
