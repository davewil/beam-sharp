pub type Order {
  Order(id: Int, total: Int)
}

pub opaque type Sealed {
  Sealed(n: Int)
}

fn inner(o: Order) -> Int {
  o.total + 1
}

pub fn outer(o: Order) -> Int {
  inner(o)
}

fn inner_int(n: Int) -> Int {
  n + 1
}

pub fn outer_int(n: Int) -> Int {
  inner_int(n)
}

pub fn make(n: Int) -> Sealed {
  Sealed(n)
}

pub fn read(s: Sealed) -> Int {
  s.n
}
