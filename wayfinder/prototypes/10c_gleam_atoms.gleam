//// 10c — How Gleam represents atoms, booleans and Nil
////
//// Evidence for ticket 10 §7. Observed locally on Gleam 1.18.1 / OTP 28
//// (2026-08-12), installed via `mise use -g gleam@1.18.1`. This closes the map's
//// standing provenance gap — Gleam claims in tickets 03 and 06 were `doc` or
//// inferred until this file was run.
////
////   gleam new gleamprobe --skip-git --skip-github
////   cp 10c_gleam_atoms.gleam gleamprobe/src/gleamprobe.gleam
////   cd gleamprobe && gleam build
////   cat build/dev/erlang/gleamprobe/_gleam_artefacts/gleamprobe.erl
////
//// Then run 10c_gleam_forge.erl against the compiled beam.
////
//// FIRST: Gleam has no atom literal. `pub fn f() { :ok }` is a syntax error —
//// "Found `:`, expected one of: `}`". Atoms exist only as fieldless variants of
//// a custom type, i.e. declare-before-use, with a carve-out for `ok`, `error`
//// and booleans because they are too pervasive to make you declare.

pub type Colour {
  Red
  Green
  Blue
}

pub type Shape {
  Circle(Float)
  Rect(Float, Float)
}

pub fn describe(c: Colour) -> String {
  case c {
    Red -> "r"
    Green -> "g"
    Blue -> "b"
  }
}

pub fn flag() -> Bool {
  True
}

pub fn nothing() -> Nil {
  Nil
}

pub fn res() -> Result(Int, String) {
  Ok(1)
}

pub fn area(s: Shape) -> Float {
  case s {
    Circle(r) -> r
    Rect(w, h) -> w *. h
  }
}
// Generated Erlang, verbatim (gleamprobe.erl):
//
//   -type colour() :: red | green | blue.
//   -type shape()  :: {circle, float()} | {rect, float(), float()}.
//
//   -spec describe(colour()) -> binary().
//   describe(C) -> case C of red -> ~"r"; green -> ~"g"; blue -> ~"b" end.
//
//   -spec flag()    -> boolean().                        flag()    -> true.
//   -spec nothing() -> nil.                              nothing() -> nil.
//   -spec res()     -> {ok, integer()} | {error, binary()}.  res() -> {ok, 1}.
//
//   -spec area(shape()) -> float().
//   area(S) -> case S of {circle, R} -> R; {rect, W, H} -> W * H end.
//
// Three things this settles:
//
//   1. Fieldless variants ARE bare atoms; variants with fields are tagged
//      tuples; PascalCase becomes snake_case.
//
//   2. `Nil` is the Erlang atom `nil`, and `True` is the atom `true`. Gleam
//      libraries will therefore hand beam-sharp the atom `nil` as an ordinary
//      value — see ticket 10 §5.
//
//   3. `colour()` erases to `red | green | blue` — a structural union of atom
//      singletons with NO runtime witness of having been constructed. That is
//      ticket 09 §6's derived claim ("erased nominality IS an alias") with a
//      shipped proof. See 10c_gleam_forge.erl for what follows from it.
