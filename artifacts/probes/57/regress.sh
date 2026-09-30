#!/usr/bin/env bash
# Runs the repo's own eunit suite (compiler/test/*_tests.erl) against each compiler variant's ebin,
# from a COPY of compiler/ (cwd matters to some tests). Prints passed/failed per variant.
# Failing-test SETS (not counts) land in $W/reg_<v>.failset; diff them against base with comm. OTP 25 lacks maps:iterator/2 and json:decode/1, so ~hundreds fail in EVERY variant.
here=$(cd "$(dirname "$0")" && pwd); repo=$(cd "$here/../../.." && pwd)
W=${W:-/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad/work/57}
for v in ${@:-base A Aprod B0 Bn Ba}; do
  t=$W/tst-$v; rm -rf "$t"; mkdir -p "$t"
  (cd "$repo/compiler" && tar cf - --exclude=_build --exclude='*.beam' .) | (cd "$t" && tar xf -)
  [ $v = base ] || (cd "$t" && patch -s -p1 < "$here/patches/$v.patch") || exit 1
  mkdir -p "$t/tbin"; erlc -o "$t/tbin" +debug_info -I "$t/src" "$t"/test/*.erl >/dev/null 2>&1
  mkdir -p "$t/_build/default/bin"
  erl -noshell -eval "Fs = filelib:wildcard(\"$W/$v/ebin/*.beam\"), Ar = [{\"bsc/ebin/\" ++ filename:basename(F), element(2, file:read_file(F))} || F <- Fs], ok = escript:create(\"$t/_build/default/bin/bsc\", [shebang, {emu_args, \"-escript main bsc\"}, {archive, Ar, []}]), halt()." && chmod +x "$t/_build/default/bin/bsc"
  mods=$(cd "$t/test" && ls *_tests.erl | sed 's/\.erl//' | tr '\n' ',' | sed 's/,$//')
  log=$W/reg_$v.log
  (cd "$t" && timeout 1500 erl -noshell -pa "$W/$v/ebin" -pa "$t/tbin" -eval "R = eunit:test([$mods], [verbose]), io:format(\"RESULT ~p~n\", [R]), halt()." > "$log" 2>&1)
  # failing-test SET (module: name), sorted; compare sets across variants with `comm`, not counts
  grep -E '\*failed\*' "$log" | sed -E 's/\.\.\.\*failed\*.*//; s/^ *//' | sort -u > "$W/reg_$v.failset"
  res=$(grep -E "^(  Failed:|  Passed|All [0-9]+ tests passed)|Failed: " "$log" | tail -2 | tr '\n' ' ')
  printf '%-6s %s failset=%s\n' $v "$res" "$(wc -l < "$W/reg_$v.failset")"
done
