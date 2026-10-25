# Probes behind the five decision briefs (ENG-211, ENG-234, ENG-239, ENG-241, ENG-242)

Every number in `../briefs/` comes from a script here. Nothing is quoted from the tickets' own tables.

## Setup

```
export SCRATCH=<an empty directory>
./setup.sh                                  # micromamba -> erlang 28 (erts 16.4), elixir 1.20.4, gleam 1.19.1; builds bsc into $SCRATCH/ebin
./build_variant.sh v57-A $SCRATCH/v57/A/ebin  # one prototype = one patch in patches/, applied to compiler/src, built the same way
```

The probes find compilers at fixed places: `$SCRATCH/ebin` (unpatched) and `$SCRATCH/vNN/<X>/ebin` for patch `vNN-<X>.patch`.
`39/build_bench.sh` builds everything ticket 39 times. `eunit_variant.sh LABEL EBIN` runs `compiler/test` against a build
(rebar3 is not installed; it builds the escript the tests shell out to with `escript:create`, and runs each variant from a copy).

## Not executed, and why

- **Elm**: `package.elm-lang.org` is blocked, so `elm 0.19.3` (installed from npm) cannot compile any module. No claim about Elm's behaviour rests on a probe.
- **Hex**: blocked. Req 0.7.3, the dependency ticket 52 names, was not fetched; a stand-in Elixir application is laid out the way rebar3/mix leave one.
- **Apple Silicon**: ticket 39's numbers came from one. These are an x86-64 Xeon @ 2.1 GHz (4 vCPU, a VM). Absolute times differ; ratios are what to read.
- **leex `error_location`** is passed exactly as `compiler/rebar.config` does. OTP 25 (the distro package) lacks it; OTP 28 from conda-forge has it.

## Baseline of the test instrument

`compiler/test` against the unpatched tree, here: **1494 passed, 4 failed** (`body_check_tests:every_aoc_program_still_compiles_test`
and three in `corrected_signature_tests`). Those four are environmental and recur in every variant; a prototype's result is read as
the set of failures it adds to those four. Variants must be run one at a time: three concurrent runs truncated each other's logs.

## Map

| ticket | scripts |
|---|---|
| 57 (ENG-239) | `57/p57_fold.sh` `p57_guard.sh` `p57_semantics.sh` `p57_exprtype.sh` `p57_delta.sh` `p57_neighbours.sh`; patches `v57-A`, `v57-B1`, `v57-B2` |
| 39 (ENG-211) | `39/build_bench.sh` `p39_four.sh` `p39_inline.sh` `p39_emitter.sh` `p39_ceiling.sh` `p39_cost.sh` `p39_trace.sh`; `asm_of.escript` `asm_fn.escript`; patches `v39-I1`, `v39-I2` |
| 59 (ENG-241) | `59/p59_scope.sh` `p59_cost.sh`; patches `v59-G1`, `v59-G2` |
| 60 (ENG-242) | `60/p60_who.sh` `p60_scale.sh` `p60_neighbours.sh`; patch `v60-P` |
| 52 (ENG-234) | `52/p52_provenance.sh` `p52_neighbours.sh` `p52_cost.sh`; patch `v52-Q` |
