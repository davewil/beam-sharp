# Decision briefs, 2026-10-11

Five open decision tickets, each with a brief (options as code, measured evidence, strongest counterargument, recommendation), runnable probes, and an independent verification. **No ticket was resolved.** Toolchain: OTP 29, Elixir 1.20.4, Gleam 1.19.1, Elm 0.19.0 (Elm could not fetch packages here).

| Ticket | Linear | Brief | Verdict |
|---|---|---|---|
| 52 dependency provenance | ENG-234 | `52-dependency-provenance/` | verified with corrections |
| 57 negative literals in refinements | ENG-239 | `57-negative-literals-in-refinements/` | verified with corrections |
| 59 boundary guard scope | ENG-241 | `59-boundary-guard-scope/` | verified with corrections (recommendation revised) |
| 60 who may name this module | ENG-242 | `60-who-may-name-this-module/` | verified with corrections |
| 62 outbound ABI | ENG-252 | `62-outbound-abi/` | verified with corrections |

Ticket 25 (ENG-191, exemplar programs) is older and open but is a catalogue, not a decision, so it was skipped. Generated `.beam`/`.abstr` files are git-ignored; each probe directory's README says how to rebuild.
