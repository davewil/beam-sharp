pub type Order {
  Order(id: Int, total: Int)
}

pub type Doc {
  Invoice(id: Int, total: Int)
  Receipt(id: Int, total: Int)
}

pub fn pub_amount(o: Order) -> Int {
  o.total
}

fn priv_amount(o: Order) -> Int {
  o.total
}

pub fn pub_double(n: Int) -> Int {
  n * 2
}

fn priv_double(n: Int) -> Int {
  n * 2
}

pub fn total_of(xs: List(Order)) -> Int {
  sum(xs, 0)
}

fn sum(xs: List(Order), acc: Int) -> Int {
  case xs {
    [] -> acc
    [x, ..rest] -> sum(rest, acc + priv_amount(x))
  }
}

pub fn use_double(n: Int) -> Int {
  priv_double(n)
}

// a private fn whose param is a custom type with two variants: does it check the tag?
fn priv_doc(d: Doc) -> Int {
  case d {
    Invoice(_, t) -> t
    Receipt(_, t) -> t
  }
}

pub fn doc_total(d: Doc) -> Int {
  priv_doc(d)
}
