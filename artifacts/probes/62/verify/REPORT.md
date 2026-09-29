# Verifier report: brief 62 (2026-09-29)
Recorded by the parent session from the verifier agent's returned text (the verifier's Write was refused).

Headline REPRODUCED: `:Api."New"(1)` works on Elixir 1.14.0 (own beam, real B# module, ticket's Shop table; direct, piped, captured, aliased); the ticket's SYNTAX_ERROR rows also reproduce; `Code.format_string!` keeps the quoted form. Gleam claims REPRODUCED. Corpus counts REPRODUCED. `remote_names` claim confirmed (bs_check.erl:572-580, bs_emit.erl:115-122; also bs_emit.erl:1070).
Probes: p1,p1b,p1c,p2,p3b,p3c,p4,p5,p6b,p7,p8 PASS 3/3; p3 PASS/PASS/FAIL (E4 load-time flaky, passed 3 of 7); p6 FAIL 3/3 as designed (no acronym names in corpus).
Circularity: p3 E4b post-hoc/descriptive only (does not feed the verdict); p3 E2 and E5 too loose to fail; p2 correction legitimate ('$X' sorts before '$_'; expected set unchanged); p6 R1 was fitted on 9 constructors (held-out ones also match); p6b alias half tautological; p1 expected file contains unpredicted rows. Nothing was patched red->green.
Cost re-measurement: bytes/exports match; load ratio 0.98-1.25 (n=100), 1.33-1.62 (n=1000); alias call overhead under 1 ns (author 0.0, verifier +0.6); call_only tail call confirmed by disassembly.
Citation errors (corrected in brief): LANGUAGE.md quote uses `Shop` not `Api`; ticket 87 lines 83-86.
Not verified: Elixir newer than 1.14; Elm.
