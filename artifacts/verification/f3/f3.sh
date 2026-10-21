#!/bin/sh
export BSC=/home/user/beam-sharp/compiler/_build/default/bin/bsc; . /home/user/beam-sharp/artifacts/probes/env.sh
W=$(mktemp -d)
row() { # name ret [decl] [fieldrecord]
  mkdir -p $W/$1; { printf 'module %s\n\n' $1; [ -n "${3:-}" ] && printf '%s\n\n' "$3"; printf 'public %s Go(int id)\nGo(id) -> :nothing\n' "$2"; } > $W/$1/$1.bs
  printf '%-4s %-34s -> ' "$1" "$2"; $BSC --api $W/$1/$1.bs 2>&1 | head -${L:-3} | tr '\n' '|' | cut -c1-260; echo
}
row A1 'option<term>'
row A2 'result<term, binary>'
row B1 'result<int, term>'
row B2 'result<binary, term>'
row C2 'option<map<string, term>>'
# own cases
row X1 'Box' 'record Box { Items: option<list<term>> }'
row X2 'Maybe<term>' 'type Maybe<T> = (:just, T) | :nothing'
row X3 'Maybe<int>' 'type Maybe<T> = (:just, T) | :nothing'
row X4 'option<Maybe<term>>' 'type Maybe<T> = (:just, T) | :nothing'
row X5 'Box' 'record Box { Items: list<option<term>> }'
row X6 'Box' 'record Box { V: option<term> }'
row X7 'Box' 'record Box { V: option<int> }'
row X8 'option<option<term>>'
row X9 'option<(int, term)>'
row Y1 'result<option<term>, binary>'
row Y2 'Wrap<term>' 'type Wrap<T> = option<T>'
row Y3 'Wrap2<term>' 'type Wrap2<T> = (:w, option<T>)'
