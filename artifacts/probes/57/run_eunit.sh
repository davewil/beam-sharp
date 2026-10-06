#!/usr/bin/env bash
# run_eunit.sh VARIANT_COMPILER_DIR OUTFILE
# VARIANT_COMPILER_DIR is a COPY of compiler/ (src possibly patched). rebar3 is not installed, so this
# reproduces what `rebar3 eunit` does: ebin at _build/test/lib/bsc/ebin, escript at _build/test/bin/bsc
# (bs_test_support finds the project by walking back from a cwd containing `_build`), eunit per module.
set -eu
d=$(cd "$1" && pwd); out=$2
lib=$d/_build/test/lib/bsc; rm -rf "$d/_build"; mkdir -p "$lib" "$d/_build/test/bin"
"$(dirname "$0")/build_variant.sh" "$d/src" "$lib/ebin"
cp "$d/src/bsc.app.src" "$lib/ebin/bsc.app"
# escript = header + zip of ebin
erl -noshell -eval "
  {ok,Fs}=file:list_dir(\"$lib/ebin\"),
  Beams=[F||F<-Fs,filename:extension(F)==\".beam\"]++[\"bsc.app\"],
  Ents=[{\"bsc/ebin/\"++F,element(2,file:read_file(\"$lib/ebin/\"++F))}||F<-Beams],
  {ok,{_,Z}}=zip:create(\"x.zip\",Ents,[memory]),
  file:write_file(\"$d/_build/test/bin/bsc\",[<<\"#!/usr/bin/env escript\n%%! -escript main bsc\n\">>,Z]),halt()." 
chmod +x "$d/_build/test/bin/bsc"
mkdir -p "$d/_build/test/t"; erlc -o "$d/_build/test/t" -I "$d/test" -pa "$lib/ebin" "$d"/test/*.erl >/dev/null 2>&1
mods=$(ls "$d"/test/*_tests.erl | xargs -n1 basename | sed 's/\.erl$//' | paste -sd, -)
cd "$lib"
erl -noshell -pa "$lib/ebin" -pa "$d/_build/test/t" -eval "
  Mods=[list_to_atom(M)||M<-string:tokens(\"$mods\",\",\")],
  R=[{M,(catch eunit:test(M,[]))}||M<-Mods],
  Bad=[M||{M,X}<-R,X=/=ok],
  io:format(\"modules=~p failing_modules=~p~n~p~n\",[length(Mods),length(Bad),Bad]), halt()." > "$out" 2>&1
