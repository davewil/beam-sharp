#!/usr/bin/env bash
# Probe 03: can a scoped marker be spelled on the signature without a grammar conflict?
# Runs yecc (OTP 25 parsetools) with {report,true} on the repo's UNMODIFIED bs_parser.yrl, then on
# copies with three candidate spellings added.  Prints yecc's conflict report verbatim.
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
T=$(mktemp -d)
try() { # name, extra-rule-text, extra-terminal
  cp "$REPO/compiler/src/bs_parser.yrl" "$T/$1.yrl"
  if [ -n "$2" ]; then
    # replace the 'public' visibility production by the scoped form (keeping bare 'public' too)
    sed -i "s/^visibility -> 'public'  : public\./visibility -> 'public'  : public.\n$2/" "$T/$1.yrl"
  fi
  [ -n "$3" ] && sed -i "0,/^Terminals/s//Terminals $3/" "$T/$1.yrl"
  echo "=== $1"
  erl -noshell -eval "R = yecc:file(\"$T/$1.yrl\", [{report,true},{verbose,false},{parserfile,\"$T/$1.erl\"}]), io:format(\"result: ~p~n\", [R]), halt()." 2>&1
}
try baseline "" ""
try parens   "visibility -> 'public' '(' modpath ')' : {public, '\$3'}." ""
try brackets "visibility -> 'public' '[' modpath ']' : {public, '\$3'}." ""
try to_kw    "visibility -> 'public' 'to' modpath : {public, '\$3'}." "'to'"

# What does the `public(` spelling do to a tuple-returning signature?  Lex with the (OTP-25-ported)
# real lexer, parse with the baseline parser and with the parens-variant parser.
EBIN=$("$HERE/../common/build-bsc.sh" /tmp/claude-0/ws60base 2>/dev/null | tail -1 | xargs dirname | xargs dirname)/lib/bsc/ebin
for v in baseline parens brackets; do
  case $v in parens) SC='public(Shop.Orders)';; brackets) SC='public[Shop.Orders]';; *) SC='public(Shop.Orders)';; esac
  SRC="module M
public (int, int) Pair(int n)
Pair(n) -> (n, n)
$SC int Helper(int n)
Helper(n) -> n
"
  erlc -o "$T" "$T/$v.erl" 2>/dev/null
  echo "=== parse with $v parser; source line 2 is a tuple-returning signature, line 4 is '$SC int Helper':"
  erl -noshell -pa "$EBIN" -pa "$T" -eval "
    {ok, Toks, _} = bs_lexer:string(\"$(printf '%s' "$SRC" | sed ':a;N;$!ba;s/\n/\\n/g')\"),
    io:format(\"~p~n\", [catch $v:parse(Toks)]), halt()." 2>&1 | head -12
done
