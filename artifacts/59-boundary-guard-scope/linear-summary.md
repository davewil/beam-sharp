**Ticket 59 research brief (recommendation only; ticket left open).**

Question: should boundary guards (record tag, int/float kind, range) be emitted on exported functions only, or on every function?

Options, one line each:
1. Exported only for every guard (18 §4 as written): drop the private tag test, one line in `guard_one`.
2. Every function for every guard: remove `when Public`; reverses F24.6 and F37.5.
3. Keep the split and document it.

**Recommendation (revised after independent verification): keep the split for now (option 3) and raise one ticket, then take option 1.** Option 1 matches 18 §4, F24, F37 and erlc's exported-versus-local discriminator, but its premise, "a private function inherits its callers' proofs", is false when the exported parameter is a union: `public int Entry(Order | :nothing m)` forwarding to private `Inner(Order o)` has no guard on `Entry`, so dropping the private tag test turns today's `function_clause` into a silent `9` (same for `int | :nothing`: 1.5 -> 2.5). The ticket to raise: exported union-typed and container parameters are unchecked (`Sum(list<int>)` returns `4.5` for `[1, 1.5]` today). Cost of the private tag test meanwhile: about 12 Code bytes and roughly 2-5 ns per private record call.

**Most surprising finding:** the ticket's forgery route is refused by bsc for `term`, `map` and `{Kind:..}` values, but works for union-typed exported parameters, an ordinary shape. A verifier found this with programs the author had not tried.

Brief: `artifacts/59-boundary-guard-scope/brief.md` (probes in `probes/`).
