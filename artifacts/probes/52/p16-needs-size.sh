#!/usr/bin/env bash
# P16: bytes the declared-application record adds to a .beam (prototype 52x, bs@needs/0), for 0..3 distinct apps.
# 0 apps is the control (no bs@needs emitted, size must equal the same program without `in`).
PROTO=/tmp/bsb_52_x/ebin; LIBS=/usr/lib/elixir/lib
W=$(mktemp -d); cd "$W"
gen() { # gen NAME in1 in2 in3  (use "" for no app)
  local n=$1; mkdir -p $n
  { echo "module $n"
    echo "using :'Elixir.Enum'${2:+ in :$2} {"; echo "    int count(list<term> xs)"; echo "}"
    echo "using :lists${3:+ in :$3} {"; echo "    int sum(list<int> xs)"; echo "}"
    echo "using :file${4:+ in :$4} {"; echo "    int delete(binary p)"; echo "}"
    echo "public int Go(list<term> xs)"; echo "Go(xs) -> :'Elixir.Enum'.count(xs) + :lists.sum([1]) + :file.delete(\"x\")"
  } > $n/a.bs; }
gen N0 "" "" ""; gen N1 elixir "" ""; gen N2 elixir stdlib ""; gen N3 elixir stdlib kernel
for n in N0 N1 N2 N3; do
  ERL_LIBS=$LIBS erl -noshell -pa $PROTO -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra -o o_$n $n/a.bs 2>&1 | head -2
  printf '%s  apps=%s  beam=%s bytes\n' $n "${n#N}" "$(stat -c %s o_$n/$n.beam 2>/dev/null)"
done
