// PROBE 4 — what does Gleam 1.12 emit for pub fn names and for type-constructor names?
//
// EXPECTED (stated before the first run):
//  * functions are written snake_case and emitted UNCHANGED: `pub fn get_x` -> `get_x/1`
//    (so ticket 10 §7's "PascalCase becomes snake_case" is about CONSTRUCTORS, not functions).
//  * constructors: `Ok2` -> `ok2`; `MyVariant(Int)` -> tagged tuple {my_variant, _};
//    `GetX` -> `get_x`; `Parse2Ints` -> `parse2_ints`;
//    `HTTPGet` -> `h_t_t_p_get` (every capital splits: Gleam does NOT keep acronyms together).
//  * `GetX` and `Get_X`-style collisions are not expressible; but `GetX` and a constructor
//    `Get_x` is a Gleam compile error (constructors must be PascalCase without underscore).
pub type T {
  Ok2
  MyVariant(Int)
  GetX
  Parse2Ints(Int)
  HTTPGet
  HTTPGet2(Int)
  ABC
  AbcDef
  X1Y
}

pub fn get_x(x: Int) -> Int { x + 1 }
pub fn http_get(x: Int) -> T { HTTPGet2(x) }
pub fn all() -> List(T) { [Ok2, MyVariant(1), GetX, Parse2Ints(2), HTTPGet, HTTPGet2(3), ABC, AbcDef, X1Y] }
