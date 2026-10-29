import widget
@external(erlang, "ghost_mod", "f")
fn ghost() -> Int
pub fn main() -> Int { widget.answer() + ghost() }
