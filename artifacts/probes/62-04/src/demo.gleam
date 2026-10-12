pub type Shape {
  Circle(radius: Int)
  RightTriangle(base: Int, height: Int)
  HTTPError
}

pub fn get_by_id(x: Int) -> Int { x }

pub fn make() -> Shape { RightTriangle(1, 2) }
pub fn err() -> Shape { HTTPError }
