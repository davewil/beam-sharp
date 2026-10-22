pub type Order { Order(id: Int, total: Int) }

pub fn outer(o: Order) -> Int { inner(o) }

fn inner(o: Order) -> Int { o.total }

pub fn bump_pub(n: Int) -> Int { bump(n) }

fn bump(n: Int) -> Int { n + 1 }
