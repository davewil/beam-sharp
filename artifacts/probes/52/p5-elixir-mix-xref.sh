#!/usr/bin/env bash
# P5: what does Elixir's compiler do with an undeclared application dependency? (Elixir 1.14.0, executed)
# Cases: (a) call into :ssl, not declared -> warning; (b) same, :ssl added to extra_applications -> clean (control);
#        (c) call into an absent module -> warning (different text); (d) exit codes (warning != failure).
set -u
W=$(mktemp -d); cd "$W"; mix new demo >/dev/null 2>&1; cd demo
cat > lib/demo.ex <<'X'
defmodule Demo do
  def go, do: :ssl.start()
end
X
echo "=== (a) :ssl used, not declared"; mix compile 2>&1 | grep -v '^$' | head -4; echo "exit=${PIPESTATUS[0]}"
sed -i 's/extra_applications: \[:logger\]/extra_applications: [:logger, :ssl]/' mix.exs
touch lib/demo.ex; mix compile --force 2>&1 | grep -v '^$' | head -4; echo "=== (b) :ssl declared (control) exit=${PIPESTATUS[0]}"
cat > lib/demo.ex <<'X'
defmodule Demo do
  def go, do: Nope.Absent.f()
end
X
echo "=== (b2) SURPRISE above: declaring :ssl AFTER a first compile in the same dir still warned (state carried over). Fresh project, :ssl declared from the start:"
W2=$(mktemp -d); cd "$W2"; mix new demo >/dev/null 2>&1; cd demo
printf 'defmodule Demo do\n  def go, do: :ssl.start()\nend\n' > lib/demo.ex
sed -i 's/extra_applications: \[:logger\]/extra_applications: [:logger, :ssl]/' mix.exs
mix compile 2>&1 | grep -v '^$' | head -3; echo "(no warning line above = control is clean) exit=${PIPESTATUS[0]}"
cd "$W/demo"
cat > lib/demo.ex <<'X'
defmodule Demo do
  def go, do: Nope.Absent.f()
end
X
echo "=== (c) absent module"; mix compile --force 2>&1 | grep -v '^$' | head -4; echo "exit=${PIPESTATUS[0]}"
echo "=== (e) what the compiled .beam records (beam_lib imports) for case (c)"
erl -noshell -pa _build/dev/lib/demo/ebin -eval '{ok,{_,[{imports,I}]}}=beam_lib:chunks("_build/dev/lib/demo/ebin/Elixir.Demo.beam",[imports]), io:format("~p~n",[I]), halt().'
echo "=== (f) the generated demo.app"; cat _build/dev/lib/demo/ebin/demo.app
