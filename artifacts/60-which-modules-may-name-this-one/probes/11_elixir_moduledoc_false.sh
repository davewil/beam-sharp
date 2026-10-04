#!/bin/bash
# Elixir 1.14.0 on OTP 24 (the OTP-28 build of the toolchain crashes at boot: Kernel.CLI undef -- see ENVIRONMENT.md).
# Only /usr/lib/elixir/lib/*/ebin is installed: NO .ex sources, so nothing below is "read from the source".
export PATH=/usr/bin:/bin
HERE=$(cd "$(dirname "$0")" && pwd)
rm -rf /tmp/exo && mkdir /tmp/exo && cd "$HERE/exs"
elixir --version | tail -1
echo "## compile: a @moduledoc false helper named by a sibling, plus a defp called from outside"
elixirc -o /tmp/exo acme.ex 2>&1 | head -12; echo "exit=${PIPESTATUS[0]}"
echo
echo "## remove the outside defp call and compile again: does @moduledoc false restrict anything?"
grep -v 'def peek' acme.ex > /tmp/acme2.ex
elixirc -o /tmp/exo /tmp/acme2.ex 2>&1 | head; echo "exit=${PIPESTATUS[0]}"
echo
echo "## what @moduledoc false DID change: the docs chunk says hidden; the function is a normal export"
elixir -pa /tmp/exo -e '
 {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(Acme.Orders.Rules)
 IO.inspect(moduledoc, label: "moduledoc of Acme.Orders.Rules")
 IO.inspect(Acme.Billing.invoice([1,2,3]), label: "Acme.Billing.invoice")
 IO.inspect(Acme.Orders.Rules.module_info(:exports), label: "exports")
'
echo
echo "## the stdlib itself: how many installed Elixir modules are @moduledoc false (docs :hidden)?"
elixir -e '
 mods = for {:ok, m} <- [Application.spec(:elixir, :modules) |> List.wrap |> Enum.map(&{:ok,&1})] |> List.flatten, do: m
 hidden = Enum.count(mods, fn m -> case Code.fetch_docs(m) do {:docs_v1,_,_,_,:hidden,_,_} -> true; _ -> false end end)
 IO.puts("elixir app modules: #{length(mods)}, hidden: #{hidden}")
 IO.inspect(Elixir.Module.ParallelChecker.module_info(:exports) |> length, label: "Module.ParallelChecker (hidden) exports a callable surface of")
'
