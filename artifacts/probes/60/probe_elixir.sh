#!/usr/bin/env bash
# ticket 60: Elixir's "internal" is documentation only.
set -u; cd "$(dirname "$0")"; mkdir -p ex/out
elixirc -o ex/out ex/hidden.ex
elixir -pa ex/out -e 'IO.inspect(Lib.Internal.helper(), label: "call a @moduledoc false / @doc false function")
{:docs_v1, _, _, _, moddoc, _, _} = Code.fetch_docs(Lib.Internal); IO.inspect(moddoc, label: "moduledoc chunk")'
