// Survey probe: does Gleam treat a private function differently from a public one at the BEAM
// boundary, and can a private function leave the module as a value?
pub type Order {
  Order(id: Int, total: Int)
}

fn keep(n: Int) -> Int {
  n
}

fn total(o: Order) -> Int {
  o.total
}

pub fn rule() -> fn(Int) -> Int {
  keep
}

pub fn reader() -> fn(Order) -> Int {
  total
}

pub fn out_int(n: Int) -> Int {
  keep(n)
}
