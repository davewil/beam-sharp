// Ticket 22 probe. The question is NOT what the marker is called; it is
// WHERE it goes. Gleam is the one surveyed language whose "unfinished"
// marker is a keyword rather than a library call, so if any language puts
// the marker on the declaration, it is this one.
//
// Q1: is `todo` accepted as a whole function body, and is it an error or a
//     warning? (23 §7 needs the stub to COMPILE, and CI to refuse it.)
// Q2: does the same token typecheck at two unrelated return types? If it
//     does, the marker is a bottom-typed EXPRESSION in the body, not a
//     declaration-level annotation.

pub fn apply(order: Int) -> Int {
  todo
}

pub fn classify(n: Int) -> String {
  todo
}

pub fn main() {
  apply(1)
}
