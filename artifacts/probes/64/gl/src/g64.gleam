pub type Option(a) { Some(a) None }
pub fn some() -> Option(Int) { Some(5) }
pub fn none() -> Option(Int) { None }
pub fn ok() -> Result(Int, String) { Ok(5) }
pub fn err() -> Result(Int, String) { Error("x") }
pub fn nested() -> Option(Option(Int)) { Some(None) }
