#!/usr/bin/env bash
# Probe 62-09: OTP ships PascalCase exports today (diameter_types). How does Elixir call them?
elixir -e '
IO.inspect(Enum.filter(:diameter_types.module_info(:exports), fn {n,_} -> n |> Atom.to_string() |> String.first() |> String.match?(~r/[A-Z]/) end), label: "PascalCase exports in OTP diameter_types")
IO.inspect(:diameter_types."Unsigned32"(:encode, 7, %{}), label: ~S|:diameter_types."Unsigned32"(:encode, 7, %{})|)
IO.inspect(Code.string_to_quoted(":diameter_types.Unsigned32(:encode, 7, %{})") |> elem(0), label: "unquoted spelling parses?")
'
