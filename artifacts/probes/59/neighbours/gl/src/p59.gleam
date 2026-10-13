pub type Inner { Inner(n: Int) }
pub type Outer { Outer(id: Int, inner: Inner) }
pub fn via_private(o: Outer) -> Int { helper(o.inner) }
fn helper(i: Inner) -> Int { i.n }
pub fn add(a: Int, b: Int) -> Int { a + b }
