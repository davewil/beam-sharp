pub type Order { OrderCreated(id: Int) OrderShipped }
pub fn new_order(id: Int) -> Order { OrderCreated(id) }
pub fn total(o: Order) -> Int { case o { OrderCreated(i) -> i OrderShipped -> 0 } }
@external(erlang, "Shop", "New")
pub fn shop_new(id: Int) -> a
