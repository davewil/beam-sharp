#!/bin/sh
# PROBE 4b — the apt Elixir 1.14 install ships NO .ex source (only ebin), so Mix.Tasks.Compile.App cannot be cited by file:line.
# This lists the functions the installed beam defines via its debug_info chunk (what the compiler task contains), nothing more.
# PREDICTION: names include something that selects runtime prod deps (dep inference) and handles extra_applications.
elixir -e 'm = Mix.Tasks.Compile.App
{:ok, {_, [debug_info: {:debug_info_v1, backend, data}]}} = :beam_lib.chunks(:code.which(m), [:debug_info])
{:ok, %{definitions: defs}} = backend.debug_info(:elixir_v1, m, data, [])
for {{n,a},_,_,_} <- defs, do: IO.inspect({n,a})'
