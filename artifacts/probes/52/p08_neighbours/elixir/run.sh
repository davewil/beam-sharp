#!/bin/sh
# p08/elixir: what does a .ex SOURCE say about the apps it needs, and what do `elixir`/`mix` check?
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu" MIX_HOME=$(mktemp -d) HEX_OFFLINE=1
T=$(mktemp -d); cd $T
echo "## 1. real 'mix new demo' -> where the manifest says it (mix.exs lines)"
mix new demo >/dev/null 2>&1; grep -n "deps\|extra_applications\|app:" demo/mix.exs
cat > demo/lib/demo.ex <<'X'
defmodule Demo do
  def a(x), do: :crypto.hash(:sha, x)          # OTP app :crypto, NOT in extra_applications
  def b, do: Req.get!("http://x")              # module in no available app, NOT in deps
  def c(x), do: String.upcase(x)               # elixir itself
end
X
echo "## 2. elixirc on the SAME source with no manifest (what the compiler alone says)"
( cd demo && elixirc -o /tmp/ex_out_$$ lib/demo.ex 2>&1; echo "elixirc rc=$?" )
echo "## 3. mix compile: the manifest is checked against the source's remote calls"
( cd demo && mix compile </dev/null 2>&1; echo "mix rc=$?" )
echo "## 4. after adding :crypto to extra_applications"
( cd demo && sed -i 's/extra_applications: \[:logger\]/extra_applications: [:logger, :crypto]/' mix.exs && rm -rf _build && mix compile </dev/null 2>&1; echo "mix rc=$?" )
echo "## 5. a dep declared in mix.exs but absent on disk (path dep; Hex itself is unreachable here - see Limits)"
( cd demo && sed -i 's|# {:dep_from_hexpm, "~> 0.3.0"},|{:req, path: "../req_missing"},|' mix.exs && rm -rf _build && timeout 60 mix compile </dev/null 2>&1 | head -12 )
