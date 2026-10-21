#!/bin/sh
export BSC=/home/user/beam-sharp/compiler/_build/default/bin/bsc; . /home/user/beam-sharp/artifacts/probes/env.sh
W=$(mktemp -d)
mk() { # modname
  d=$W/src/$(echo $1 | tr . /); mkdir -p $d; printf 'module %s\n\npublic int Go(int x)\nGo(x) -> x\n' $1 > $d/m.bs
  printf '== module %s\n' $1; rm -rf $W/out_$1; $BSC --src-root $W/src -o $W/out_$1 $d 2>&1 | head -4; echo "bsc-exit=${PIPESTATUS:-n/a}"; ls $W/out_$1 2>&1 | tr '\n' ' '; echo
}
for m in Elixir.Enum Erlang.Lists erlang.lists lists Elixir Erlang Gleam.List kernel Enum.Elixir 'Elixir.Enum.Foo'; do mk $m; done
# does the emitted Elixir.Enum.beam have the right module name?
erl -noshell -eval "{ok,{M,_}} = beam_lib:chunks(\"$W/out_Elixir.Enum/Elixir.Enum.beam\", []), io:format(\"beam module name: ~p~n\",[M]), halt()."
