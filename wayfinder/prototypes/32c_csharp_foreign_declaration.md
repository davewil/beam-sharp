# 32c — C#'s own foreign declaration, run rather than cited

Measured 2026-08-14. `local`, .NET SDK 9.0.306, macOS/arm64.
Source: [`32c_csharp_foreign_declaration.cs`](32c_csharp_foreign_declaration.cs).
Requires `<AllowUnsafeBlocks>true</AllowUnsafeBlocks>` for the `LibraryImport` half.

Ticket 32 names `[DllImport]` a tier-1 borrow. The map's standard is to measure the borrow rather
than cite it, so all four declarations were compiled and run against `libc`:

```
getpid  via EntryPoint   : 33442
getppid via name         : 33439
getuid  via LibraryImport: 501
getpid  declared long    : 33442
```

## Findings

**1. The construct is exactly a signature with no body plus an attribute naming the foreign
entity.** `[DllImport("libc", EntryPoint = "getpid")] internal static extern int GetProcessId();`
— no braces, no clauses. This is ticket 23 §7's clauseless signature with a different marker,
confirmed against the language beam-sharp borrows from.

**2. Both spellings are carried, but only when they differ.** `EntryPoint` names the foreign symbol
when the C# name is not it; omit `EntryPoint` and **the C# name is the foreign symbol verbatim** —
`getppid()` is a legal C# method name and resolves directly. So C#'s answer to ticket 32 §3 is
neither "mapping" nor "always both": it is **identity by default with an explicit override**, and
the override is a named property rather than a second positional argument.

**3. The modern form is literally "the compiler writes the body".** `[LibraryImport]` requires
`partial`, not `extern`, and a source generator supplies the implementation — which is beam-sharp's
**codegen obligation** shape under a different name, and the natural home for ticket 15's wrapper
and ticket 18's guard.

**4. C# trusts the declaration exactly as Gleam does.** Two C# names over the same foreign symbol
with different return types (`int` and `long`) both compiled and both ran, returning the same
value. **This matters for the borrow heuristic**: ticket 32's framing treats unchecked FFI as
Gleam's flaw and C# as the clean borrow, but the tier-1 source has the same hole. beam-sharp's
guard (ticket 18) diverges from **both** of its audiences, not just from Gleam — and that is a
divergence the spec must state, because a C# reader will expect `extern` to be unchecked.

**5. One thing does not transplant.** `LibraryImport` requiring `unsafe` is a CLR marshalling
artefact with no BEAM analogue, in the same family as the reified-generics and nominal-identity
rocks ticket 07 found behind C#'s rejected union designs.
