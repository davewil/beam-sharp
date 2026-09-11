# 72 — An open map type has no spelling, and a foreign fixed-field return needs one

Type: decision
Status: open — [ENG-358](https://linear.app/davewil/issue/ENG-358). Raised 2026-09-11 by the
ENG-351 grill, round 4 Q10
Blocked by: —

## Why this is raised now

The ENG-351 grill decided (Q8) that a fixed field set is admissible as a foreign return under
[ticket 18](18-boundary-defence.md) §2: an inline map type is decided by a guard sequence sized by
the declaration, the same shape as `(:ok, int)` and `pid | port | :undefined`. It also found (Q9)
that no guard runs on any foreign return today, and filed ENG-357 to emit one.

Put together, this program compiles and runs today and will fail on every call once ENG-357 lands:

```csharp
module Web

using :cowboy_req {
    { Method: binary, Path: binary } req(term r)
}

public binary Route(term r)

Route(r) -> :cowboy_req.req(r) switch {
    { Method: "GET", Path: p } => p,
    { Method: m }              => m
}
```

A cowboy request map carries a dozen keys beyond the two declared. The written type resolves
closed (`bs_check:resolve/3` on `{t_map, Fields}` calls `bs_types:map_closed/1`), and a closed
member's guard is `map_size(R) =:= 2` (`bs_emit`, the closed-member case). Measured on `afdbde0`
with no guard, a three-key map passes a two-field inline type:

```csharp
module Extra

using :maps {
    { Method: binary, Path: binary } from_list(list<term> pairs)
}

public binary PathOf()

PathOf() -> :maps.from_list([(:'Method', "GET"), (:'Path', "/x"), (:'Host', "h")]) switch {
    { Method: "GET", Path: p } => p,
    { Method: m }              => m
}
```

```
$ bsc Extra.bs PathOf
"/x"
```

## The question

[Ticket 26](26-data-modelling.md) says types are *"structural and open"*. The grammar has one map
type form, `'{' field_decls '}'` (`bs_parser.yrl`, `type_prim`), and it resolves closed. Property
*patterns* are open (`{ Method: m }` matches a map with other keys); *types* are not. The algebra
already has the member kind — `{open, Fs}` sits beside `{closed, Fs}` and `{dom, K, V}` in
`bs_types` — so nothing is missing below the surface. What is missing is a way to write it.

**Does B# get an open map type spelling, and what is it?**

The program that must compile, and keep compiling once ENG-357's guard runs, is `Web` above with
whatever spelling this ticket settles in place of `{ Method: binary, Path: binary }`. The compiler
delta is the grammar rule, `resolve/3` producing `{open, Fs}` for it, and the guard ENG-357 emits
for an open member: `is_map_key` per declared field and no `map_size`.

What this ticket does not decide: whether a *record* is open. A record carries a minted `Kind` and
is constructed only by the compiler, so its field set is exact by construction; 26 §1 owns that.

## Constraints

- Ticket 26: structural and open, as the philosophy; the algebra's `{open, Fs}` member; 26 §2's
  rule that spread (`...`) is refused in construction, so a spelling that reuses `...` in type
  position has to be told apart from that refusal.
- Ticket 48: bare braces name atom keys only. An open inline type is still atom-keyed; it is not a
  `map<K, V>`.
- Ticket 18 §2 as confirmed by the ENG-351 grill Q8: admissible at a foreign boundary only if one
  guard sequence, sized by the declaration, decides it. An open member with `is_map_key` per field
  satisfies that.
- ENG-357 (the guard) must not wait on this: it emits `map_size` for the closed member it is handed,
  and `Web` failing under it is correct for the type as written.

## Decisions entry

*Open.*
