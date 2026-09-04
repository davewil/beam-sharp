# Elixir visibility probe

`orders.ex` defines `Orders` with a `defp` (module-private) function and a `Billing` module that
tries to call it directly (`Orders.internal_helper()` — there is no other spelling that would
reach a `defp` function from outside the module; Elixir has no `Orders.Internal.internal_helper`
or similar "reach past privacy" escape hatch).

Command: `elixirc orders.ex -o /tmp/elixir_out`
Output: `compile_output_defp_cross_module.txt` — a **warning**, not a hard compile error:

    warning: Orders.internal_helper/0 is undefined or private

Then actually running it (`elixir -pa /tmp/elixir_out -e "Billing.call_orders_private()"`,
`run_output_defp_cross_module.txt`) raises at **run time**:

    ** (UndefinedFunctionError) function Orders.internal_helper/0 is undefined or private

So `defp`'s enforcement is real (the call never reaches the function) but it is binary and
module-wide — private to *this compilation unit*, not to some callers and not others — and the
compiler's own defence against violating it is a warning plus a runtime crash, not a compile-time
refusal the way beam-sharp's own `no_clauses` or a Rust `E0603` is. There is no second Elixir
keyword, attribute, or convention anywhere in the language for "private to this module, but this
specific other module may still call it."

`@moduledoc false` (used in `orders.ex`) is unrelated to this: it hides the module from generated
ExDoc documentation only, exactly the same job Gleam's `@internal` does for docs (see the Gleam
probe) — neither is a compiler-enforced call boundary.

Boundary-enforced module grouping in the Elixir ecosystem (Phoenix contexts, the `boundary` Hex
package) is real and well documented, but this session could not verify it by execution: `mix
deps.get` requires `repo.hex.pm`, which the sandboxed network denies (`curl` to `repo.hex.pm`
returns `403` via the proxy, confirmed while probing Gleam's dependency resolution — see
`../gleam_internal_probe`). So the claim "Elixir's answer beyond the compiler is
convention/linter, not the compiler itself" is asserted from documented public knowledge of how
`boundary` works (a Mix compiler *tracer* plugin, not part of `elixir`/`erlc` itself), not from a
local run, and is flagged as such in the brief.
