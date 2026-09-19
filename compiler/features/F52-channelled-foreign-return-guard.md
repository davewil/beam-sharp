# F52 — the boundary guard on a channelled foreign return

**Status**      **done 2026-09-19** — 3 tests in `foreign_guard_tests` (F52.1–F52.3); three
                abstract-code assertions in `foreign_wrapper_tests` expected the wrapper's
                `try` as the body's outermost node and now expect the guard's `case`, with a
                header note that the read no longer separates a channelled call from an
                unchannelled one and which behavioural tests do; 1011 in the suite, up from
                1008. No new gate: no gate reads a
                program's runtime output, the same limit F42 recorded, so the crash is
                asserted at the loaded module and through the CLI and `check-language.sh`
                compiles the `Reader` block §11 gained. `./bin/verify.sh` green **twice from
                a clean clone**
**Implements**  [ticket 74](../../wayfinder/issues/74-a-failed-guard-under-a-declared-channel.md)
                / [ENG-362](https://linear.app/davewil/issue/ENG-362), resolved 2026-09-19;
                the arm [F42](F42-foreign-return-guard.md) shipped unbuilt and
                [ENG-357](https://linear.app/davewil/issue/ENG-357) named as its one open
                question
**Closes**      [ENG-390](https://linear.app/davewil/issue/ENG-390)
**Decides**     nothing. Ticket 74 decided the nesting; this emits it
**Depends on**  F19, whose wrapper this now sits outside of; F42, whose `return_guard/3` is
                reused unchanged; F40, whose admissibility predicate makes the guard total

## What was there

F42 emitted ticket 18 §2's boundary guard on every foreign return whose declaration named **no**
failure channel, and skipped the channelled one because what a failed guard becomes under a
declared `result<T, foreign_error>` was undecided. So a wrong declaration over a function that
never raises compiled clean and answered with a value outside its own declared type:

```csharp
module Reader

using :file {
    result<binary, foreign_error> read_file(binary path)
}

public result<binary, foreign_error> Slurp(binary path)

Slurp(path) -> :file.read_file(path)
```

```
$ bsc Reader.bs Slurp '<<"/etc/hosts">>'
(:ok, "##\n# Host Database\n...")
$ echo $?
0
```

`(:ok, binary)` inhabits neither `binary` nor `(:error, foreign_error)`. Ticket 06's outcome 3, at
every channelled foreign declaration in the language.

## The program

The same one, after:

```
$ bsc Reader.bs Slurp '<<"/etc/hosts">>'
crashed: case_clause (:ok, "##\n# Host Database\n...")
$ echo $?
1
```

## The delta

One clause in `bs_emit`'s `e_foreign_call`:

```erlang
{ok, #{wrapped := true, ret := Ty}} ->
    return_guard(L, foreign_wrapper(L, Call), Ty);
```

`bs_check` already wrote `ret => Ty` on every foreign entry, wrapped or not, so nothing upstream
moved and `return_guard/3` is reused exactly as F42 built it.

## Why the guard is OUTSIDE the wrapper

Both orders compile, and both return the same thing when the call succeeds. The difference is
what a refused value becomes, and ticket 74 decided it on prior art after finding 18 §1 rule C
does not reach the case — rule C guarantees *"outcome 1-or-2, never outcome 3"*, and a channelled
value is visible either way.

- **OTP** separates a mechanism's own failure from the callee's by the reason's shape: `erpc`
  raises `{erpc, _}` beside `{exception, _, _}`, and its value-returning predecessor `rpc` is the
  collapsed form its own `-moduledoc` calls unrepairable.
- **.NET** separates them by subtyping: `catch (ExternalException)` takes a native `SEHException`
  and not the marshaller's own `MarshalDirectiveException`. Measured on SDK `9.0.306`.

In B# the F19 wrapper *is* that catch, so the refusal stays outside it. Nesting them the other way
makes the two indistinguishable — `examples/Foreign`'s `Diagnose` answers `:not_a_number` for a
value nothing threw, measured before the build.

## What did NOT change

The channel still carries what it was declared for. The catch's `(:error, (Class, Reason))`
inhabits the declared type, so it passes the guard:

```
$ bsc examples/Foreign Parse '<<"notanumber">>'
(:error, (:error, :badarg))
$ bsc examples/Foreign Parse '<<"41">>'
41
```

F52.2 pins this at the loaded module. It was green before the implementation and had to stay green
after, so it guards the channel against the guard rather than asserting the new behaviour.

## Notes

**No gate can go red for this feature on its own.** `check-language.sh` compiles §11's new
`Reader` block, which proves the code in the document is real B#, but the program compiled before
this change too — it simply answered wrongly. No gate reads a program's runtime output, the limit
F42 recorded, so the behavioural check is F52.3 through the CLI.

**Found while building, and not this feature's to fix**: a stray `Json.beam` — a compiled B#
module named `Json`, dated 2026-08-21 and matched by `.gitignore`'s `compiler/*.beam` — sat in
`compiler/` and shadowed stdlib's `json` on macOS's case-insensitive filesystem, so
`json:encode/1` was undefined and 11 `diagnostic_json_tests` failed on a clean tree at master.
Invisible to git and to Linux CI. The same shape has bitten once before — `C.beam` shadowing
stdlib's `c` when `erl` is run from `compiler/` — which is why it is filed rather than noted:
[ENG-391](https://linear.app/davewil/issue/ENG-391).
