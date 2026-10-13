pub type Shape { MyCircle(radius: Int) HTTPServer }
pub fn make() -> Shape { MyCircle(3) }
pub fn srv() -> Shape { HTTPServer }
@external(erlang, "Shop", "New")
pub fn shop_new(id: Int) -> a
