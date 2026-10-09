#!/usr/bin/env bash
# P8: prototype 52x (patches/52x-app-clause-and-check.diff): `using :Mod in :app { }` + presence/ownership check + bs@needs/0.
# Needs the patched build at /tmp/bsb_52_x/ebin; stock build is /tmp/bsbuild/ebin.
# Dependency stand-in: Elixir's own lib dir (Req cannot be fetched here). ERL_LIBS=/usr/lib/elixir/lib puts 'Elixir.Enum' (app elixir) on the path.
HERE=$(cd "$(dirname "$0")" && pwd)
PROTO=/tmp/bsb_52_x/ebin; STOCK=/tmp/bsbuild/ebin; LIBS=/usr/lib/elixir/lib
W=$(mktemp -d); cd "$W"
mk() { mkdir -p "$1"; printf 'module %s\n%s {\n    int count(list<term> xs)\n}\npublic int Go(list<term> xs)\nGo(xs) -> :%s.count(xs)\n' "$1" "$2" "'Elixir.Enum'" > "$1/a.bs"; }
# try LABEL EBIN LIBSVAL DIR [extra VAR=val]
try() {
  local label=$1 ebin=$2 libs=$3 dir=$4; shift 4
  local out; out=$(env ERL_LIBS="$libs" "$@" erl -noshell -pa "$ebin" -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra -o "out_$dir" "$dir/a.bs" 2>&1)
  if [ -z "$out" ]; then echo "$label => accepted"; else echo "$label => refused: $(echo "$out" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-190)"; fi
}
mk Withapp "using :'Elixir.Enum' in :elixir"
mk Noapp   "using :'Elixir.Enum'"
mk Wrongapp "using :'Elixir.Enum' in :stdlib"
for D in Withapp Noapp Wrongapp; do
  echo "### $D: $(sed -n 2p $D/a.bs) {"
  try "  proto, ERL_LIBS=elixir lib          " $PROTO $LIBS $D
  try "  proto, ERL_LIBS unset               " $PROTO ""    $D
  try "  proto, unset, BSB_DEP_CHECK=off     " $PROTO ""    $D BSB_DEP_CHECK=off
done
echo "### severity: the same missing dependency as a WARNING (BSB_DEP_CHECK=warn): rc and beam emitted?"
for m in warn error; do
  out=$(ERL_LIBS= BSB_DEP_CHECK=$m erl -noshell -pa $PROTO -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra -o sev_$m Withapp/a.bs 2>&1 | head -1)
  echo "  mode=$m -> ${out}  beams_emitted=$(ls sev_$m/*.beam 2>/dev/null | wc -l)"
done
echo "### CONTROL: stock compiler, Noapp, ERL_LIBS unset (today's behaviour = P1: accepted)"
try "  stock, ERL_LIBS unset               " $STOCK "" Noapp
echo "### CONTROL: stdlib module, app named correctly, no ERL_LIBS (expect accepted)"
mkdir -p Ctl; printf 'module Ctl\nusing :lists in :stdlib {\n    int sum(list<int> xs)\n}\npublic int Go(list<int> xs)\nGo(xs) -> :lists.sum(xs)\n' > Ctl/a.bs
try "  proto, lists in stdlib              " $PROTO "" Ctl
echo "### stock compiler on the new syntax (expect refused: syntax error)"
try "  stock, Withapp                      " $STOCK $LIBS Withapp
echo "### bs@needs/0 and imports chunk of Withapp.beam (proto, ERL_LIBS set)"
ERL_LIBS=$LIBS erl -noshell -pa out_Withapp -eval 'io:format("bs@needs() = ~p~n",[(list_to_atom("Withapp")):(list_to_atom("bs@needs"))()]), {ok,{_,[{imports,I}]}}=beam_lib:chunks("out_Withapp/Withapp.beam",[imports]), io:format("imports = ~p~n",[I]), halt().'
echo "### run Go([:a,:b,:c]) through the prototype with the dependency present"
ERL_LIBS=$LIBS erl -noshell -pa $PROTO -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra Withapp/a.bs Go "[:a, :b, :c]"
