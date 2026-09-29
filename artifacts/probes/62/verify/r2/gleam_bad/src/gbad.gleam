// PROBE 4b — EXPECTED: compile ERROR, function names must be snake_case (so a Gleam author
// can never have a PascalCase function, and Gleam's `pub fn` needs no downcasing rule).
pub fn GetX(x: Int) -> Int { x + 1 }
