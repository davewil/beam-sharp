# Ticket 59 verification (independent)

## Step 1: rebuild + rerun
- Built C, D (and a second independent build C2 of the C patch) with build-variant.sh into /tmp/claude-0/verify59/{C,D,C2}. All patches applied cleanly. `git status compiler/` clean, so $BSC is unpatched.
- behave.sh unpatched/C/D, run twice (second time after coordinator added SumC): output IDENTICAL to behave_result.txt (labels aside). Includes SumC([300]) -> 301 in all three.
- cost.sh, 4 runs, compiler order shuffled each time (U C D C2 / D C2 U C / C U C2 D / C2 D C U):

| variant | Code bytes | rec-loop ns min / med / max | int-loop ns min / med / max |
|---|---|---|---|
| U (unpatched) | 360 | 10.92 / 11.06 / 11.27 | 8.82 / 8.84 / 8.87 |
| C | 324 | 8.97 / 9.05 / 9.10 | 8.81 / 8.88 / 8.98 |
| C2 (same patch, 2nd build) | 324 | 9.00 / 9.02 / 9.06 | 8.80 / 8.86 / 8.98 |
| D | 370 | 11.99 / 12.17 / 12.24 | 8.96 / 8.98 / 9.10 |

- Bytes: -36 (C), +10 (D) reproduce exactly and are deterministic (C and C2 identical).
- Noise floor (C vs C2, same source): rec-loop 0.03 ns on medians, int-loop 0.02; within-variant spread 0.1-0.35 ns.
- C rec delta -2.0 ns (claimed ~-2.2): real, ~60x the noise. D rec delta +1.1 (claimed ~+1.3): real. D int-loop delta +0.14 median (claimed ~+0.1): reproducible in direction (D min 8.96 > U max 8.87) but the same size as C's within-variant spread (0.17); call it "at the noise floor, probably real, ~1.5%". Do not cite it as a measured cost beyond "negligible".
- Caveat on attribution: the rec-loop deltas are NOT one tag test. Emitted code (show.sh): unpatched has the tag guard on both LoopRec (2 clauses) and InnerRec; C removes all of them (LoopRec/InnerRec lose guards, so ~3 tag tests/iter incl. clause 1 failing falls to clause 2). D's rec-loop increase also comes from added is_integer(N)/is_integer(Acc) guards on LoopRec, not from the record. So per-test cost is smaller than the headline; the bench measures a worst-case loop of private-to-private calls.
- D int loop does exercise private int guards: D's LoopInt has `is_integer(B), B>=0, B=<255, is_integer(Acc)` (+ is_integer(N) in clause 2) and InnerInt gets is_integer/range guards; unpatched/C emit `'InnerInt'(B) -> B + 1` and `'LoopInt'(N,B,Acc)` with no guard. (Note RunInt's own exported guard is in all variants.) Delta is small because BEAM guard bifs on small ints are cheap and JIT-inlined.

## Step 2: critical reading
- Patches are minimal and honest: C = `constrains_kind(Pat) orelse not Public` (skips tag test when private); D = drops the `Public` condition on the `none` branch. No test-specific special-casing, no arranged inputs. No circularity in the patches.
- Route is real: emitted Erlang for unpatched G59: `'SumAll'([O|T]) -> 'Inner'(O) + 'SumAll'(T)` (no guards at all on the exported function, list<Order> not walked), `'Inner'(O) when map_get('Kind',O) =:= 'G59.Order'`, `'SumB'([B|T]) -> 'Priv'(B)+...`, `'Priv'(N) -> N+1` unguarded. Compile gives no warning about this (only "function 'Id'/1 is unused"; exit 0). The B# author has no signal.
- Caveat on "forged": the probe builds a raw Erlang map, i.e. foreign code / BEAM interop is the only way to get it in. In pure B# a forged value cannot arise (type checker). So the claim is about the foreign boundary, and the unpatched compiler's boundary guard is shallow by design (top-level param only). That is what the probe shows; it does not overstate, but "private tag test is the only defence" is true only for the list<Order>-like routes; for a direct `public One(Order o)` the exported guard already catches it (probe shows this).
- SumC (coordinator's addition): nested list<Byte> element used directly in the exported body with NO private call -> 301 in all variants incl. D. Emitted `'SumC'([B|T]) -> B + 1 + 'SumC'(T)`. So yes: unguarded container elements are the root gap; D only converts failures that happen to pass through a private function into function_clause and leaves the same forged element accepted whenever it is used in the exported body (or returned, stored). D (and the existing private tag test) is a partial symptom patch: it gives incidental, route-dependent protection, not a guarantee. C removing the tag test removes only that incidental protection (Step 3 shows exactly the cases lost). A consistent fix would be deep boundary validation, which is out of the ticket's two candidate patches.
- Probe omissions I found: none that reverse a conclusion. One missing case: SumAll probe cannot distinguish "protected by tag test" from "protected by clause shape"; fine since emitted code confirms tag test is the sole guard. Opposite direction (probe shows rejection where unpatched lets through): none seen.

## Step 3: new probes (/tmp/claude-0/verify59/src/N59/n.bs, results new_probes.txt)
| probe | unpatched | C | D |
|---|---|---|---|
| ViaWrap: forged Order nested in record field Wrap.Inner -> private UseOrder | function_clause | **99 (forged accepted)** | function_clause |
| ViaTuple: `(:ok, Order)` param with forged member -> private | function_clause | **99** | function_clause |
| ViaCell: Cell{V: Byte} with V=300 -> private Byte param | 301 | 301 | function_clause |
| ViaCell V=2.5 | 3.5 | 3.5 | function_clause |
| Local(5): record built locally -> private | 5 | 5 | 5 |
| ViaFloats([2.5]) list<Byte> -> private | 3.5 | 3.5 | function_clause |
| ViaFloats([300]) | 301 | 301 | function_clause |
Emitted (unpatched): `ViaWrap(W) when map_get('Kind',W)=:='N59.Wrap'` (outer tag only), `ViaTuple({ok,O}) -> UseOrder(O)` unguarded, `Local(N) when is_integer(N)` building the map inline.
Reading: tag test on private functions really is the sole defence for nested records and tuple members (C loses it; confirms the asymmetry costs something in C). For Local, the private tag test is redundant (constructed locally, always correct) so C/D cost is pure overhead there; no behaviour change. Kind/range on private ints is likewise only incidental protection.

## Verdict
CIRCULAR: no. Stored results reproduce exactly (behaviour byte-for-byte, bytes exact, ns within noise except D's int-loop +0.1 which is at noise floor). Patches are straightforward scope changes; probes use forged values via foreign (Erlang) calls only, which is the actual threat model, and the emitted Erlang matches the claims. Caveats to carry: (1) ns deltas aggregate several tests per iteration, not one; (2) D int delta not distinguishable from noise with confidence; (3) forging requires foreign code, and the deeper issue (SumC, ViaCell) is unguarded container/record-field contents, which neither C nor D addresses.
