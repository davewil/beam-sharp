# 31b — ASP.NET Core assembles its pipeline at run time, out of function values

`local` — .NET SDK 9.0.306, `Microsoft.NET.Sdk.Web`, ASP.NET Core 9 shared framework. Source:
[`31b_aspnet_runtime_assembly.cs`](31b_aspnet_runtime_assembly.cs).

[`31a`](31a_plug_builder_lowering.md) measured the BEAM half of the audience and found the stage
set baked at compile time. **The C# half does it the other way**, and ticket 31 cannot be answered
from the BEAM precedent alone — the map's audience is C# *or* TypeScript developers, and both reach
for `app.Use`.

## The probe

A stage is a **value** of type `Func<HttpContext, RequestDelegate, Task>`, held in a dictionary. The
stage set is read from an environment variable — after compilation, invisible to any macro — and
applied in a loop:

```csharp
var configured = (Environment.GetEnvironmentVariable("STAGES") ?? "auth").Split(',');
foreach (var name in configured)
    app.Use(catalogue[name]);
```

## Result

```
STAGES=auth,quota,trace AUTHED=1 -> 200 ran: auth>quota>trace>router
STAGES=trace,auth       AUTHED=1 -> 200 ran: trace>auth>router
STAGES=trace,auth,quota AUTHED=0 -> 401 unauthorized
```

Three different pipelines out of one binary. The **set** changed, the **order** changed, and the
halt on line 3 stopped `quota` and the terminal handler from running. Nothing here is knowable at
compile time.

## Three ways to halt, in three frameworks

This is the part worth carrying into the ticket, because the map has been treating "halt" as one
idea:

| | halting is | can the compiler see it? |
|---|---|---|
| Plug | a **field** on the conn (`halted: true`), checked between stages | no — halted and live conn are one type |
| ASP.NET Core | **not calling `next`** — control flow, nothing returned | no — `next` is a value that may or may not be invoked |
| beam-sharp | a **member of the returned union** | **yes** — 09's discriminability rule decides it |

beam-sharp is the only one of the three where halting is data the type system can reason about, and
it gets there without adding a construct. Neither neighbour can say *"this stage always halts"*;
a beam-sharp stage declares it in its return type.

## The gap this file exists to name

**beam-sharp cannot express the shape on this page at all**, and the reason is not middleware —
it is that the map has never spelled a function as a value:

- ticket 17 §1: the pipe "never passes a function as a value… this ticket incurs no obligation to
  spell *the function `F` as a value*"
- ticket 11: foreign funs are holdable and returnable, **never callable**
- ticket 14: Pinto's closures-as-messages is inadmissible under that rule
- ticket 08: `=>` is *reserved* for lambdas — reserved, not defined

So `catalogue[name]` — a collection of stages, selected by a runtime key — has no beam-sharp
spelling, and `app.Use` in a loop has none either.

**The honest reading of the assembly-time question is two-to-one, not unanimous.** Plug and
Phoenix's `pipe_through` are both compile-time (`31a`); ASP.NET Core is run-time. A beam-sharp
pipeline written as a literal `|?>` chain matches what the BEAM's own frameworks emit, and the
thing it cannot do is the thing the C# audience would arrive expecting.

Whether a native lambda is callable at all is a **hole this ticket surfaces and does not fill** —
it is much larger than middleware, and it belongs to whichever ticket takes function values.
