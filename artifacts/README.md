# Decision briefs for the five oldest open map tickets (run of 2026-10-16)

| ticket | Linear | brief | verifier |
|---|---|---|---|
| 57 negative literals in refinements | ENG-239 | `57-negative-literals-in-refinements-brief.md` | `verification/57-verifier.md` |
| 59 boundary guard scope | ENG-241 | `59-boundary-guard-scope-brief.md` | `verification/59-verifier.md` |
| 60 which modules may name this one | ENG-242 | `60-which-modules-may-name-this-one-brief.md` | `verification/60-verifier.md` |
| 62 the outbound ABI | ENG-252 | `62-the-outbound-abi-brief.md` | `verification/62-verifier.md` |
| 64 failure types collapse at term | ENG-254 | `64-failure-types-collapse-at-term-brief.md` | `verification/64-verifier.md` |

No ticket was resolved or its state changed. "Oldest" = lowest Linear creation date among open map tickets titled `NN —`
(ENG-239, 241, 242, 252, 254); non-map defects (ENG-238, 244, 248, 250, 258, 271) were not counted as decision tickets.

## Reproducing

- `env.sh` — PATH for the toolchain used: OTP 28.0 built from source under `/tmp/claude-0/otp28` (repo pins 28.5; apt only offers 25 and `bsc` needs 28),
  rebar3 3.27.0, gleam 1.12.0, Elixir 1.19.5/OTP 28 and Elixir 1.14/OTP 25 (the latter only with `PATH=/usr/bin:/bin`), Go 1.24.7, rustc 1.97.0. Elm 0.19.1 installs but cannot resolve packages (registry blocked), so **no Elm behaviour was executed**.
  `/tmp` toolchains do not survive the container; rebuild per the versions above.
- `patches/*.diff` — every prototype compiler, as a diff against `compiler/`. `build-variant.sh PATCH OUTDIR` builds one. Nothing under `compiler/` was modified.
- `probes/NN/` — probe sources and their stored outputs. Some need the compilers above; read each script's header.
- Neighbour sources cited by file:line were read from shallow clones of gleam v1.12.0, elixir v1.18.4, elm 0.19.1 and the OTP 28.0 source tarball.

## Known limits of this run

Single machine, OTP 28.0 not 28.5; timings on x86-64 not arm64; timing deltas under about 0.2 ns are inside the noise floor and are labelled as such.
