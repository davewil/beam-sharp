# Probes for ticket 39 (ENG-211) -- all MEASURED-HERE on OTP 25 (compiler-8.2.6.3), emu_flavor=jit, Gleam 1.12.0, Elixir 1.14.0
Input: a/input.txt is SYNTHETIC (4732 rotations, sum|d| = 673364, seeded; the real AoC input is not in the repo). Answer 6725, not 6770.

| dir | claim it supports |
|---|---|
| a/   | (a) stripping `{tr,..}` from otherwise instruction-identical code: same instrs (cmp.out), +5.5..8% time vs copy-controls <1% (run1/run2.out); the Type chunk is where `{tr}` lives, `var_info` comments are not encoded (cmp.out strip_vi) |
| a2/  | the emitter's plausible abstract-form shapes (remote-call `rem`, widened -spec, F42 return-guard) give instruction lists IDENTICAL, WITH annotations, to Erlang's (cmp_fn.out) and identical time (time_shapes.out). Stand-ins: bsc cannot run here |
| a3/  | `compile:file(.abstr,[from_abstr,debug_info])` (bsc.erl:845 path) == `compile:forms` for the same forms |
| b/   | range reaching the optimiser: relational guard does not restore `{tr}` (ann_spin.out); `band` carrier does; timing time1/time2.out |
| b2/  | which source constructs give `{t_integer,{Lo,Hi}}` in OTP 25: band, rem, `=:=` literals yes; -spec range, relational guards no (ranges_ann.out) |
| c/   | survey: c/gl Gleam 1.12 output (`-compile([..inline])`, wide specs, `rem` operator); c/gl3 Gleam `%`/`/`; c/ex Elixir abstract code (no specs on defp, operator `rem`) |
| d/   | cross-language timing: Gleam (inline) ~0.6x of Erlang/Elixir; erlc +inline 0.57x; stripping `{tr}` after inlining +25% (time_langs.out, time_inline_strip.out) |
| e/   | emitted guards on a private hot function: free when redundant (folded away), ~free when real; never add types |
| f/   | cost of `inline`: stack trace loses the inlined callee's frame |
