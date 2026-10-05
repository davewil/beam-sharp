#!/usr/bin/env bash
# CLAIM (mine): Elixir ties "what this code may call" to what the manifest DECLARES: an undeclared dependency
# (or undeclared OTP app) makes the call site a compile-time warning ("module X is not available") and the
# same call compiles clean once the app is declared; and the manifest, not the source file, is the home.
# REFUTED IF: V1 or V2-ssl compile with no warning; or V2 (declared) still warns; or the mix docs chunk does not
# describe `extra_applications`/dependency inference as the .app source.
. "$(dirname "$0")/lib.sh"
C=$WORK/mixconsumer; rm -rf "$C"; cp -r "$ROOT/fixtures/mixconsumer" "$C"; cd "$C"
w() { sed 's/^/    /'; }
echo "### V1: mix.exs declares nothing; code calls MyLib.new/1 and :ssl.versions/0"
cat > mix.exs <<'X'
defmodule C.MixProject do
  use Mix.Project
  def project, do: [app: :c, version: "0.1.0", deps: []]
  def application, do: [extra_applications: []]
end
X
rm -rf _build; mix compile 2>&1 | w
echo "### V2: declare the dependency (path dep, no network) and the OTP app"
sed -i 's|deps: \[\]|deps: [{:mylib, path: "'"$WORK/mixlib/mylib"'"}]|; s|extra_applications: \[\]|extra_applications: [:ssl]|' mix.exs
rm -rf _build; mix compile 2>&1 | w
echo "### V3: declare only the dependency, not :ssl"
sed -i 's|extra_applications: \[:ssl\]|extra_applications: []|' mix.exs
rm -rf _build; mix compile --force 2>&1 | w
echo "### what the generated .app of the consumer says (inferred from the manifest, not from the code)"
cat _build/dev/lib/c/ebin/c.app; echo
echo "### runtime counterparts (ERL_LIBS unset): Application.ensure_all_started / Code.ensure_compiled"
env -u ERL_LIBS elixir -e 'IO.inspect(Application.ensure_all_started(:nosuch)); IO.inspect(Code.ensure_compiled(NoSuch)); IO.inspect(Code.ensure_loaded?(NoSuch))' 2>&1
echo "### the docs chunk of Mix.Tasks.Compile.App (installed beam), lines about the application list"
elixir -e '{:docs_v1,_,_,_,%{"en"=>d},_,_}=Code.fetch_docs(Mix.Tasks.Compile.App); d |> String.split("\n") |> Enum.with_index(1) |> Enum.filter(fn {_,i} -> i in 13..18 or i in 44..52 end) |> Enum.each(fn {l,i} -> IO.puts("  doc line #{i}: #{l}") end)'
