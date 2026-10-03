#!/bin/sh
# (Attempt 2: fetch_docs returns the docs_v1 tuple itself, not {:ok, _}; I had wrapped it. Attempt 1, run.first-attempt.out: section D used `for ... label:`, which Elixir rejects; rewritten without it.)
# Probe 60/07: does Elixir 1.20.4 restrict WHO may call a module/function marked @moduledoc false / @doc false?
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu"
cd "$(dirname "$0")"; rm -rf ebin; mkdir ebin
echo "== A. outsider calls @moduledoc false module and @doc false function (warnings-as-errors on)"
elixirc --warnings-as-errors -o ebin lib/billing.ex lib/orders.ex; echo "exit=$?"
echo "== B. runs"
elixir -pa ebin -e 'IO.inspect(Acme.Orders.total(1))'
echo "== C. outsider calls a defp"
elixirc -o ebin lib/billing.ex lib/orders_private.ex; echo "exit=$?"
echo "== D. what the marks DO: the Docs chunk (hidden = documentation only)"
elixir -pa ebin -e '
  {:docs_v1, _, _, _, led, _, _} = Code.fetch_docs(Acme.Billing.Internal.Ledger)
  IO.inspect(led, label: "Ledger moduledoc (:hidden means @moduledoc false)")
  {:docs_v1, _, _, _, _, _, fdocs} = Code.fetch_docs(Acme.Billing)
  IO.inspect(Enum.map(fdocs, fn {{:function, n, a}, _, _, d, _} -> {n, a, d} end), label: "Billing function docs {name, arity, doc}")
'
echo "== E. is anything else exported/enforced? Module.get_attribute / tracer hooks exist, but the default compiler:"
elixir -pa ebin -e 'IO.inspect(Acme.Billing.module_info(:exports) |> Enum.sort(), label: "Billing exports (sneaky is exported; round_ is not)")'
echo "== F. the installed Elixir's own words on @moduledoc false / @doc false (Module docs chunk; text only)"
elixir -e '
  {:docs_v1, _, _, _, %{"en" => md}, _, _} = Code.fetch_docs(Module)
  md |> String.split("\n") |> Enum.with_index(1) |> Enum.filter(fn {l, _} -> String.contains?(l, "hide") or String.contains?(l, "false") end)
     |> Enum.take(8) |> Enum.each(fn {l, i} -> IO.puts("  Module moduledoc line #{i}: #{String.trim(l)}") end)
'
echo "== G. defmodule nesting: an outsider names Acme.Pay.Store (nested, @moduledoc false)"
elixirc --warnings-as-errors -o ebin lib/nested.ex; echo "exit=$?"
elixir -pa ebin -e 'IO.inspect(Acme.Outsider.go(1), label: "Outsider.go(1)")'
rm -rf ebin
