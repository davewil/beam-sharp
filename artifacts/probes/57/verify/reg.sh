#!/usr/bin/env bash
# usage: reg.sh V   (V=A uses A.patch; V=Amut uses A.patch, ebin from Amut)
W=/tmp/v57/w; repo=/home/user/beam-sharp; here=$repo/artifacts/probes/57
v=$1; pv=${v/Amut/A}
t=$W/tst-$v; rm -rf "$t"; mkdir -p "$t"
(cd "$repo/compiler" && tar cf - --exclude=_build --exclude='*.beam' .) | (cd "$t" && tar xf -)
[ $pv = base ] || (cd "$t" && patch -s -p1 < "$here/patches/$pv.patch") || exit 1
mkdir -p "$t/tbin"; erlc -o "$t/tbin" +debug_info -I "$t/src" "$t"/test/*.erl >/dev/null 2>&1
mkdir -p "$t/_build/default/bin"
erl -noshell -eval "Fs = filelib:wildcard(\"$W/$v/ebin/*.beam\"), Ar = [{\"bsc/ebin/\" ++ filename:basename(F), element(2, file:read_file(F))} || F <- Fs], ok = escript:create(\"$t/_build/default/bin/bsc\", [shebang, {emu_args, \"-escript main bsc\"}, {archive, Ar, []}]), halt()." && chmod +x "$t/_build/default/bin/bsc"
mods=$(cd "$t/test" && ls *_tests.erl | sed 's/\.erl//' | tr '\n' ',' | sed 's/,$//')
(cd "$t" && timeout 1500 erl -noshell -pa "$W/$v/ebin" -pa "$t/tbin" -eval "R = eunit:test([$mods], [verbose]), io:format(\"RESULT ~p~n\", [R]), halt()." > $W/reg_$v.log 2>&1)
grep -E '\*failed\*' $W/reg_$v.log | sed -E 's/\.\.\.\*failed\*.*//; s/^ *//' | sort -u > $W/reg_$v.failset
echo "$v: $(grep -E 'Failed: |All [0-9]+ tests passed' $W/reg_$v.log | tail -1) set=$(wc -l < $W/reg_$v.failset)"
