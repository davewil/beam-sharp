# 32b — Can a mechanical name mapping reach the BEAM's exported surface?

Measured 2026-08-14. `local`, OTP 28.5, Elixir 1.19.5.
Sources: [`32b_name_census.erl`](32b_name_census.erl) (`erlc` + `erl -s names2 main`),
[`32b_name_census.exs`](32b_name_census.exs) (`elixir 32b_name_census.exs`).

Ticket 32 §3 asks whether a foreign declaration carries both spellings or a mechanical mapping is
imposed. That is answerable by counting. The mapping tested is the obvious one: `snake_case` ⇄
`PascalCase`, checked in **both** directions, so a name only passes if it survives the round trip.

## Erlang — stdlib + kernel (ticket 18's census scope)

| | |
|---|---|
| modules | 199 |
| exported functions (excluding `module_info`) | 4,204 |
| distinct function names | 1,924 |
| names outside `[a-z][a-z0-9_]*` | **2** — `$handle_undefined_function`, `@wait_response_recv_opt` |
| plain names failing the round trip | **4** — `bin_is_7bit`, `read_4`, `exro928_jump_2pow20`, `exro928_jump_2pow512` |
| module names outside `[a-z][a-z0-9_]*` | **0** |
| module names failing the round trip | **1** — `disk_log_1` |

**A mechanical mapping reaches 1,920 of 1,924 names** — 99.8%. The failure mode is single and
crisp: **a segment beginning with a digit**. `bin_is_7bit` → `BinIs7bit` → `bin_is7bit`, because
the mapping recovers word boundaries from capitals and `7bit` has none. Doubled and trailing
underscores fail the same way in the wider tree (`cache__new`, `child_test_`).

## Erlang — the whole loadable tree

The picture inverts once generated modules are included: **1,315 modules, 45,481 exported
functions, and 265 module names that are not plain lowercase at all** — `'PKCS-1'`, `'OTP-PKIX'`,
`'ELDAPv3'`, `'CryptographicMessageSyntax-2009'` and the rest of the ASN.1-generated set, plus
5,365 non-plain function names (`diameter`'s `'#get-diameter_base_ACA'` family). These are real,
loadable, callable modules. **No mapping can spell them**, so a mapping-only design cannot name
part of OTP, while a both-spellings design has no failure case anywhere.

## Elixir — the loadable `Elixir.*` surface

| | |
|---|---|
| modules | 412 |
| exported functions | 4,120 |
| distinct function names | 1,770 |
| plain `[a-z][a-z0-9_]*` | **1,328 (75.0%)** |
| ending in `!` | 105 — `fetch!`, `key!`, `compile_env!` |
| ending in `?` | 99 — `valid?`, `compatible_calendars?` |
| leading underscore | 55 — `__struct__`, `__protocol__`, `__impl__` |
| everything else | 191 — operators `&&&`, `<<<`, `\|\|\|`, `~~~`, and the `MACRO-` family |

**Elixir is the reverse of Erlang on both axes.** Its *module* atoms are already dotted PascalCase
(`'Elixir.List.Chars.Atom'`), so they map into beam-sharp losslessly and need no mapping at all —
easier than Erlang. Its *function* names are far harder: **a quarter of them cannot be spelled by
any identifier mapping**, because `!` and `?` are not identifier characters and operators are not
identifiers.

**One finding here reaches past ticket 32.** Elixir macros are exported as `MACRO-`-prefixed
functions — `MACRO-__using__`, `MACRO-defcallback`, `MACRO-assert`. They are compile-time
constructs of Elixir's own compiler and are **not callable as functions from another language**.
So an FFI to Elixir gets its functions and never its macros, and `use GenServer` is unreachable
across the boundary — which bears on the map's bootstrapping patch, axis (c).

## Arity fan-out (ticket 32 §4)

| | Erlang stdlib+kernel | Elixir |
|---|---|---|
| name/arity pairs carrying >1 arity | 756 of 3,251 (**23.3%**) | 795 of 3,212 (**24.8%**) |
| widest | `io_lib_pretty:print` (6 arities) | — |
| arity sets with **gaps** | **45 of 756** | e.g. `Agent.cast/2,4`, `Task.async/1,3` |

**The gaps are the finding.** `inet_udp:send/2` and `/4` exist with no `/3`; `gen:stop/1,3`;
`erpc:send_request/2,4,6`; `io_lib:write/1,2,3,5`. A default-argument reading generates a
*contiguous* ladder, so these arity families are **not** expressible as ticket 08's generated
arities. A foreign declaration naming one arity is not merely the safe answer — it is the only one
that describes the surface as it is.
