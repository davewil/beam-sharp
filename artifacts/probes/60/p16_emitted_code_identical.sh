#!/usr/bin/env bash
# CLAIM: a module-level who-may-name rule (A, B) and the visibility marker (C) change NOTHING in emitted code
# for programs that do not use them: the rule is a compile-time check only, so the BEAM output for the 27-module
# corpus is the same as base.
# REFUTED IF: any module's beam_lib:md5/1 differs between base and a patched compiler.
. "$(dirname "$0")/lib.sh"
C="$REPO/compiler/examples"; fail=0
find "$C" -path "$C/exemplars" -prune -o -name '*.bs' -print0 | while IFS= read -r -d '' f; do dirname "$f"; done | sort -u > "$WORK/p16_dirs"
for v in base pA pB pC; do
  case $v in base) p="";; pA) p=A.patch;; pB) p=B.patch;; pC) p=C.patch;; esac
  build_variant $v $p >/dev/null || exit 1
  o="$WORK/p16_$v"; rm -rf "${o:?}"; mkdir -p "$o"
  n=0; rm -f "$o/manifest"
  while IFS= read -r d; do n=$((n+1)); mkdir -p "$o/o$n"; { printf 'entry e%d\n' $n; printf 'arg %s\n' --src-root "$C" -o "$o/o$n" "$d"; printf 'end\n\n'; } >> "$o/manifest"; done < "$WORK/p16_dirs"
  "$(bsc_of $v)" --batch "$o/manifest" "$o/results" >/dev/null 2>&1
  erl -noshell -eval '
     Fs = filelib:wildcard("'"$o"'/o*/*.beam"),
     L = lists:sort([begin {ok,{M,Md5}} = beam_lib:md5(F), {M,Md5} end || F <- Fs]),
     io:format("~s~n", [lists:flatten([io_lib:format("~p ~s~n",[M,binary:encode_hex(Md5)]) || {M,Md5} <- L])]).' -s init stop > "$o/md5.txt"
  echo "$v: $(wc -l < "$o/md5.txt") modules, md5-of-md5s $(sha256sum "$o/md5.txt" | cut -c1-16)"
done
for v in pA pB pC; do cmp -s "$WORK/p16_base/md5.txt" "$WORK/p16_$v/md5.txt" && echo "$v: identical to base" || { echo "$v: DIFFERS from base"; diff "$WORK/p16_base/md5.txt" "$WORK/p16_$v/md5.txt" | head; fail=1; }; done
[ $fail -eq 0 ]; verdict "emitted-code-unchanged-for-programs-not-using-the-rule" $?
