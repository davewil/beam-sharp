pub opaque type Order {
  Order(total: Int)
}

@external(erlang, "probe_ffi", "forged_int")
fn forged_int() -> Int

@external(erlang, "probe_ffi", "forged_order")
fn forged_order() -> Order

fn private_inc(n: Int) -> Int {
  n + 1
}

pub fn outer(n: Int) -> Int {
  private_inc(n)
}

fn private_total(o: Order) -> Int {
  o.total
}

pub fn outer_order(o: Order) -> Int {
  private_total(o)
}

pub fn float_through_public() -> Int {
  outer(forged_int())
}

pub fn forged_order_through_public() -> Int {
  outer_order(forged_order())
}
