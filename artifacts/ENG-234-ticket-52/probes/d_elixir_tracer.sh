#!/bin/bash
# H1 mix warns at compile time when code calls a module belonging to an application the project does NOT declare
#    (deps or extra_applications). Message names the module's application.
# H2 declaring it (extra_applications: [:eex]) silences the warning.
# H3 the warning is a name-level check: it is the same with no version information anywhere.
# H4 a call to an entirely absent module gives the different "is not available" warning (module-level, no app).
W=$(mktemp -d); cd $W
mk() { # $1 dir, $2 extra_applications
 mkdir -p $1/lib; cat > $1/mix.exs <<EOF
defmodule P.MixProject do
  use Mix.Project
  def project, do: [app: :p, version: "0.1.0", deps: []]
  def application, do: [extra_applications: $2]
end
EOF
 cat > $1/lib/p.ex <<'EOF'
defmodule P do
  def render, do: EEx.eval_string("hi <%= 1 %>")
  def gone, do: Absent.Thing.run(1)
end
EOF
}
mk undeclared '[]'; mk declared '[:eex]'
for d in undeclared declared; do echo "### $d: mix $(mix --version | tail -1)"; (cd $d && mix compile 2>&1 | grep -v '^$'; grep -o 'applications,\[[^]]*\]' _build/dev/lib/p/ebin/p.app); done
