// Gleam's answer: no bare-success union exists. Option/Result are always tagged, at every a.
pub type Maybe(a) { Some(a) None }
pub fn find_any(x: a) -> Maybe(a) { Some(x) }
pub fn find_none() -> Maybe(a) { None }
pub fn res(x: a) -> Result(a, e) { Ok(x) }
pub fn nested(x: a) -> Maybe(Maybe(a)) { Some(Some(x)) }
