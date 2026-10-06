pub type Order {
  Order(id: Int, total: Int)
}

pub type Invoice {
  Invoice(id: Int, total: Int)
}

fn inner_total(o: Order) -> Int {
  o.total
}

fn inner_int(n: Int) -> Int {
  n + 1
}

fn inner_match(o: Order) -> Int {
  case o {
    Order(_, t) -> t
  }
}

pub fn outer_total(o: Order) -> Int {
  inner_total(o) + inner_match(o)
}

pub fn outer_int(n: Int) -> Int {
  inner_int(n)
}

pub fn public_total(o: Order) -> Int {
  o.total
}
