//// 17c — Gleam's branching surface, measured. Companion to 17c_else_in_the_neighbourhood.md.
////
//// Gleam 1.18.1 (installed via `mise use -g gleam@1.18.1`).
////
//// To reproduce: `gleam new probe --name probe`, drop this in as `src/probe.gleam`,
//// `gleam build`. The two REJECTED cases below are commented out because a file
//// containing either does not compile — uncomment one at a time to reproduce its error.

// ---------------------------------------------------------------------------
// COMPILES — `case` on a boolean is Gleam's replacement for a two-armed `if`.
// ---------------------------------------------------------------------------

pub fn label(total: Int) -> String {
  case total > 100 {
    True -> "large"
    False -> "small"
  }
}

// ---------------------------------------------------------------------------
// COMPILES — the MULTI-SUBJECT case: Gleam's answer to a ladder of unrelated
// boolean tests, and the construct beam-sharp ticket 17 §6 borrowed as a tuple
// subject. Note it is the same shape as a multi-clause function head.
// ---------------------------------------------------------------------------

pub fn ladder(admin: Bool, total: Int) -> String {
  case admin, total > 100 {
    True, True -> "priority"
    _, True -> "large"
    _, _ -> "normal"
  }
}

// ---------------------------------------------------------------------------
// REJECTED 1 — there is no `if` in Gleam, and the diagnostic is written for
// this exact case rather than being a generic parse failure.
//
//   pub fn label_with_if(total: Int) -> String {
//     if total > 100 { "large" } else { "small" }
//   }
//
// error: Syntax error
//   2 │   if total > 100 { "large" } else { "small" }
//     │   ^^ Gleam doesn't have if expressions
//
// If you want to write a conditional expression you can use a `case`:
//
//     case condition {
//       True -> todo
//       False -> todo
//     }
//
// Since there is no `if`, there is no `else` anywhere in the language.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// REJECTED 2 — a non-exhaustive `case` is a hard error, and the diagnostic
// NAMES THE MISSING PATTERN. This is ticket 04's "the residual IS the missing
// case" observed in a shipping BEAM compiler. → ticket 23.
//
//   pub fn one_armed(total: Int) -> String {
//     case total > 100 {
//       True -> "large"
//     }
//   }
//
// error: Inexhaustive patterns
//   This case expression does not have a pattern for all possible values. If it
//   is run on one of the values without a pattern then it will crash.
//
//   The missing patterns are:
//
//       False
// ---------------------------------------------------------------------------
