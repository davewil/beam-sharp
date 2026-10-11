**Ticket 60 (ENG-242): decision brief attached. This is a recommendation; the ticket stays open.**

Brief: `artifacts/60-who-may-name-this-module/brief.md` (probes and prototype patches beside it).

Question gating the rest: does a public function ever need an audience narrower than "every module"?

Options, one line each:
- **0. No new construct.** F12's private-by-default already serves ticket 24's helper case. Optionally make behaviour callbacks unnameable from other modules (10 lines) and reword the F12 refusal.
- **A. Callee lists friends** (`friend Shop.Reports`): 64 non-blank lines, one new keyword.
- **B. `Internal` directory wall** (Go's rule): 57 non-blank lines, no grammar change.

Recommendation: answer "not yet" and take Option 0's two small changes. If the answer is yes, build B, and add A's explicit list only on a second occurrence of a sibling needing it. The corpus has 8 `using <Module>` lines across 75 example files and none wants a narrower audience.

Most surprising measured finding: the F12 refusal tells the author "Mark it `public` in Cart, or move the call inside it". Following the first half makes the test compile. And a test file inside the module's directory is the module (F15): it reaches private functions and ships in the production `.beam`. Where tests live has no owner, and it decides whether any option here matters.

Also wrong in the ticket: `add_module_import` is now `/3` at `bs_check.erl:512-525`, and it is one of four doors (namespace `using`, qualified call, type position are the others). Whole-compile timings were noise (sign flipped between runs); the predicate itself costs ns per `using` but the gate is O(modules in the build). Independently verified. Gleam's `@internal` and `internal_modules` are not enforced at compile time (checked with gleam 1.19.1).
