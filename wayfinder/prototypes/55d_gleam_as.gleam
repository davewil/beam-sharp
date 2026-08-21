// 55d — Gleam: the BEAM neighbour that spells pattern-aliasing with a keyword.
//
// Measured, not assumed:
//   1. Does `as` bind the whole value beside a destructuring pattern?
//   2. Does the constructor name sit in FRONT (Gleam has no bare record pattern)?
//   3. Does labelled-field syntax `Frame(type: Method)` work in pattern position,
//      i.e. is the separator `:` as in beam-sharp's `pat_field`?
//   4. Can `as` bind a sub-pattern as well as the whole, or is it whole-only?
//
// Run:  gleam run   (inside a gleam project with this as src/<name>.gleam)

import gleam/io
import gleam/int

pub type FrameType {
  Method
  Header
  Body
}

pub type Frame {
  Frame(type_: FrameType, channel: Int, payload: String)
}

// (1)+(2)+(3) constructor name in front, labelled fields with `:`, `as` after.
pub fn dispatch(f: Frame) -> String {
  case f {
    Frame(type_: Method, ..) as whole -> "method ch=" <> int.to_string(whole.channel)
    Frame(type_: Header, ..) as whole -> "header ch=" <> int.to_string(whole.channel)
    _ -> "other"
  }
}

// (4) `as` on a SUB-pattern rather than the whole one.
pub fn sub_alias(pair: #(Frame, Int)) -> String {
  case pair {
    #(Frame(type_: Body, ..) as f, rest) ->
      "body ch=" <> int.to_string(f.channel) <> " rest=" <> int.to_string(rest)
    _ -> "other"
  }
}

pub fn main() {
  let m = Frame(type_: Method, channel: 7, payload: "hello")
  let h = Frame(type_: Header, channel: 9, payload: "")
  let b = Frame(type_: Body, channel: 11, payload: "x")

  io.println("1-3 ctor-prefix + labels + as : " <> dispatch(m))
  io.println("1-3 ctor-prefix + labels + as : " <> dispatch(h))
  io.println("4   as on a sub-pattern       : " <> sub_alias(#(b, 42)))
}
