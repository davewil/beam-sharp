# Brief-author instructions (shared)

You are producing a DECISION BRIEF for one open beam-sharp design ticket. You must NOT resolve it,
edit the ticket file, change compiler source, or touch Linear (the parent does Linear). Write only
under /home/user/beam-sharp/artifacts/.

Environment: `export PATH=$HOME/.nix-profile/bin:$PATH` gives erl/elixir/gleam/elm (OTP 28, Elixir 1.18.5).
The B# compiler is prebuilt: /home/user/beam-sharp/compiler/_build/default/bin/bsc (do NOT rebuild or
modify compiler/; copy sources to your probe dir and run bsc from there; read compiler/README.md for CLI use).
Read /home/user/beam-sharp/CLAUDE.md first. Rules from it that bind you:
- grep wayfinder/issues/*.md (and CONTEXT.md) before claiming anything is "not decided".
- A design question is B# code plus the compiler delta. NO option matrices of coupled options; if one
  question gates another, state the gating one alone and let the other follow. Options are 2-3 concrete
  *programs* (compiles under one answer, refused under the other) plus concrete compiler work
  (symbol-table entry, emitted function, pass).
- Ask the gating question only.

Required work (all of it, no assertion without an executed probe):
1. Extract the sub-decisions the ticket implies; identify the gating one.
2. For every contested factual claim: write a real probe (script/escript/exs/gleam project/elm
   project/bsc invocation) in artifacts/probes/<NN>/ and RUN it. Save raw output next to it
   (<probe>.out). Probes must be re-runnable by a stranger with one command (put it in artifacts/probes/<NN>/run.sh).
   Never patch a probe to get the expected answer; if a result contradicts the ticket text or your
   hypothesis, report that prominently.
3. Survey how neighbouring languages solve it, citing file:line from real INSTALLED sources
   (find them under /nix/store, e.g. elixir lib, erlang lib, gleam/elm binaries' behaviours via probes;
   if source for a language is not installed, say so and use a behavioural probe instead of citing memory).
   Also cite the relevant repo lines (compiler/src/*.erl, LANGUAGE.md, tickets) with file:line.
4. Measure any measurable cost (BEAM term size via erts_debug:size / erlang:external_size, beam file byte size,
   compile time over N runs with spread, generated abstract format shape).
5. Write artifacts/<NN>-<slug>-brief.md with: Ticket & gating question; sub-decisions; Evidence table
   (claim | probe | result | verdict, each probe referenced by path); Neighbour survey (file:line);
   2-3 Options, each with a B# program, compiler delta, measured evidence, and STRONGEST COUNTERARGUMENT;
   Recommendation (one option, with reason); a "What I could not measure" section; status line
   "OPEN - for human review". Be honest about anything unverified.
Keep the brief tight (<= ~250 lines). Finally reply with: brief path, probes dir, one-paragraph summary
(<=150 words) including recommendation, and the list of probe commands to re-run.
