Ticket 59 probes (all MEASURED-HERE, OTP 25.x JIT x86_64, 4 vCPU noisy VM; Gleam 1.12.0; Elixir 1.14.0)
p1   claim: tag test is +N bytes flat in field count; is_integer +3-5 B           -> p1/gen.escript, out.txt, chunks.txt
p2   claim: runtime ns/op of tag test / is_integer, local vs remote, with control   -> p2/gen.sh bench.escript out.txt out_run2.txt
p2   claim: local and remote call share one entry label                              -> p2 (S output, see brief) + compiler/src/beam_asm.erl:115-120
p2b  claim: exported->private chain cost under exported-only vs every-function       -> p2b/gen.sh bench.escript out.txt out_run2.txt out_pattern_variant.txt
p2c  claim: erlc removes a redundant private-function guard when callers prove it    -> p2c/run.sh out.txt
p3   claim: forged value reaches private fn through an unguarded exported fn / escaped fun -> p3/forge.erl out.txt forge_fun.erl out_fun.txt
p4   claim: Gleam (no guards, public or private) -> p4/gl/src/probe.gleam probe_generated.erl gl_forge.erl out_gleam.txt
p4   claim: Elixir def/defp struct pattern behave identically; no compiler guards      -> p4/ex.exs out_elixir.txt
records.txt / corpus counts: grep heuristic over compiler/examples/*.bs (see brief)
