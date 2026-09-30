p2 v1 wrote the private helper's head as `InRec(Order o) -> :order`. A record pattern
in a head tests `Kind` itself (F22), so the `function_clause` it reported came from the
clause head, not from the emitter's boundary guard, and the probe could not tell the two
apart. Changed to a bare variable, `InRec(o)`, which leaves the tag test to the boundary
guard alone. Changed after seeing output, for that reason only; both outputs kept.
(The first attempt with `InRec(_)` was refused by the compiler: a catch-all over a
declared type, and never ran.)
