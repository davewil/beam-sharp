# Probes for ticket 59 (boundary guard scope)

Setup (once): `./build-variants.sh` builds three scratch compilers from a COPY of compiler/src
(base = HEAD, notag = no record tag test on private fns, widen = int/float kind test on private fns too).
The copy diff is in `variants.patch`. compiler/src is never edited. `./bsc.sh` runs a compiler (BSC_EBIN=dir selects the variant).

| probe | one command | answers |
|---|---|---|
| a | `./probe_a_asymmetry.sh` | which function carries which guard, in all three compilers (+ negative control PrivInt) |
| b | `./probe_b_forged.sh` | does bsc accept handing an unchecked value to a private record fn; what a forged value does with/without the private tag test; the inline-projection control; the int mirror |
| c | `./probe_c_cost.sh` | bytes (Code chunk, stripped) and ns/call, 15 interleaved runs, noise floor |
| e | `./probe_e_corpus.sh` | private tag tests / would-be private kind tests in compiler/examples (+ positive control) |
| f | `neighbours/probe_f_erlang_entry.sh` | Erlang: one entry label for local and remote calls; when erlc elides a local guard |
| g | `neighbours/probe_g_elixir.sh` | Elixir: a guard on defp still runs |
| h | `neighbours/probe_h_gleam.sh` | Gleam: emitted Erlang for private/public fns over custom types and Int |

Each prints its observations; the `.out` next to it is the captured run. Paths assume the session scratchpad toolchain (OTP 29, Elixir 1.20.4, Gleam 1.19.1).
