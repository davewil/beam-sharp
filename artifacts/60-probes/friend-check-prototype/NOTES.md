# Real compiler prototype: sub-decision 4, "what does it cost the checker"

A full copy of `compiler/src/` at `1a86b0b`, patched to add a `friend` directory-level declaration
and enforce it in `add_module_import/3`, rebuilt with the project's own `rebar3 escriptize`
(`warnings_as_errors` is on in `rebar.config`, unmodified — the patch had to build clean under the
same flags the real compiler does), and exercised against a copy of the real `examples/Shop` tree.

**This is one concrete spelling among the options in the brief (Option C there), not a claim that
this is the only or the recommended shape** — it exists to make sub-decision 4 ("what does the
checker cost") a measured number instead of an estimate, per this run's ground rules.

## What changed, and how much

`diff/*.diff` are real unified diffs against the untouched `compiler/src/` at the same commit.
Counting only lines that are not blank and not a `%%` comment: **29 lines across 5 files**.

| File | + lines (code only) | What |
|---|---|---|
| `bs_lexer.xrl` | 1 | one keyword token, `friend` |
| `bs_parser.yrl` | 4 | `friend` terminal, `friend_decl` nonterminal, one `decl` alternative, one production (`friend_decl -> 'friend' modpath`) — same shape as `using_decl` one line above it |
| `bs_check.erl` | 15 | `friends_of/1` (mirrors `private_of/1`); threading `Self`/`L` one parameter further into `add_module_import`, which already had `Self` available one frame up at `add_import/6`; the membership check itself (`open` short-circuits, `lists:member/2` otherwise); `-export` line |
| `bsc.erl` | 1 | one new key in the `World1` map literal that already builds `exports`/`private`/`behaviours` this same way |
| `bs_diag.erl` | 8 | one `descriptor/2` clause, one `message/1` clause — same shape as the existing `unknown_module` pair beside them |

The real diffs are in `diff/`. `add_module_import` is the exact site the ticket names
(`bs_check.erl:407-425` at `0b761f6` per the ticket; **re-measured this run at `1a86b0b`: it is now
`add_module_import/3` at `bs_check.erl:468-477`** — the arity and line numbers have both drifted
since the ticket was filed, confirmed by reading the current file rather than trusting the citation).

## What state gets threaded through, concretely

One field, `friends`, added to the same per-module map `World` already carries `exports`,
`private`, and `behaviours` in (`bs_check.erl:66-70`'s own doc comment; `bsc.erl:249`'s literal).
Its value is either the atom `open` (no `friend` line written — the default, and what every
existing `.bs` file gets) or a list of module atoms. The check reads it with a default
(`maps:get(friends, ..., open)`), so nothing that builds a `World` map without this key breaks.

**Zero `.bs` files in the repo need to change.** `grep -rn '\bfriend\b' examples --include='*.bs'`
finds zero hits today, the same measurement ticket 40 §3 made for `public`/`private` before F12
shipped — this is opt-in and backward compatible by construction, unlike §3's marker (which was
briefly going to be mandatory and would have needed all 29 files rewritten).

## The real compile, three ways

`examples_probe/Shop/` is a copy of the real `examples/Shop` tree (`Shop.Reports.Totals` calling
`Shop.Collections.Ints` via `using`, exactly ticket 40/41's own worked example).

**1. No `friend` line at all (today's behaviour, unpatched-equivalent) — must still work:**

    $ ./_build/default/bin/bsc --src-root examples_probe examples_probe/Shop/Reports Restate 3
    9

Identical to running the *unpatched* `compiler/_build/default/bin/bsc` against the real
`examples/Shop/Reports` (`9`, confirmed separately). The patch is inert until a module opts in.

**2. `Shop.Collections.Ints` writes `friend Shop.Billing` only — `Shop.Reports` is excluded:**

    $ ./_build/default/bin/bsc --src-root examples_probe examples_probe/Shop/Reports Restate 3
    examples_probe/Shop/Reports/Totals.bs:15: error: `using Shop.Collections.Ints` is refused — Shop.Collections.Ints does not name Shop.Reports as a friend
      Shop.Collections.Ints only takes calls from a module it names with `friend Shop.Reports`

(`friend_probe_output_1_blocked.txt`)

**3. `Shop.Collections.Ints` adds `friend Shop.Reports` — the same call now compiles and runs:**

    $ ./_build/default/bin/bsc --src-root examples_probe examples_probe/Shop/Reports Restate 3
    9

(`friend_probe_output_2_allowed.txt`)

## What this does and doesn't prove

It proves the mechanism is cheap **at this one call site**, for **module-to-module** granularity,
with **no per-function cost** (the check runs once per `using` line, not once per call). It does
**not** demonstrate a real multi-friend list (only one friend module was named in the positive
case), and it exposed a real gap rather than a hypothetical one: `add_namespace_import/3` is
untouched, so the check is bypassable through the *other* import tier. Measured in
`namespace_bypass_check/` — same `Ints` module, `friend Shop.Billing` only (`Shop.Reports`
excluded), but `Shop.Reports` reaches `Ints.Length` through `using Shop.Collections` (the
NAMESPACE tier, resolved by `add_namespace_import/3`, ticket 41 §5) instead of `using
Shop.Collections.Ints` (the module tier this patch checks):

    $ ./_build/default/bin/bsc --src-root namespace_bypass_check namespace_bypass_check/Shop/Reports Counted 3
    2

No error — the excluded caller reaches the function anyway (`namespace_bypass_output.txt`). Closing
that hole means teaching `add_namespace_import/3` the same check, which is more than 29 lines and
is exactly the kind of follow-on cost a real ticket would need to size, not this prototype. It also
does not demonstrate a path-scoped (Rust-shaped) rather than named-list spelling, which would
replace `lists:member(Self, Friends)` with a prefix-match over `Self`'s dotted path instead — a
different, not obviously larger, check at the same call site, but the SAME bypass through the
namespace tier would need the same second fix either way.
