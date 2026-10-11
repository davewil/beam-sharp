**Ticket 59 research brief (recommendation only; ticket left open).**

Question: should boundary guards (record tag, int/float kind, range) be emitted on exported functions only, or on every function?

Options, one line each:
1. Exported only for every guard (18 §4 as written): drop the private tag test, one line in `guard_one`.
2. Every function for every guard: remove `when Public`; reverses F24.6 and F37.5.
3. Keep the split and document it.

**Recommendation: option 1.** It matches 18 §4, 46, 58, F24, F37 and erlc's own exported-versus-local discriminator. Dropping the private tag test breaks no existing test (10 base-green modules run) and changes nothing in the example corpus (0 private tag tests). Cost of keeping it: 12 Code bytes and about 2-4 ns per private record call. `is_integer` on a private function costs 0 bytes when erlc can prove the argument, 5 when it cannot.

**Most surprising finding:** the forgery route in the ticket is refused by bsc (a `term`, `map` or `{Kind:..}` value cannot be handed to a record-typed function). The real route is values nested inside a typed exported parameter. There the private tag test fires only if the value is passed to a function. The same forged value projected inline already returns a wrong answer today, and `Sum(list<int>)` returns `4.5` for `[1, 1.5]` under today's emitter. That hole is the same under every scope, so it needs its own ticket.

Brief: `artifacts/59-boundary-guard-scope/brief.md` (probes in `probes/`).
