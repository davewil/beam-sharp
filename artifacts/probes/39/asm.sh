#!/bin/bash
# Ticket 39 §3.2/§3.3: is the emitted instruction stream — INCLUDING the type annotations the JIT reads — the same?
# Compiles bench_erl.erl (erlc) and Day01.abstr (bsc's .abstr via compile:file from_abstr) to assembly on
# OTP 28 (the ticket's version) and OTP 29, normalises names/labels/lines, and diffs.
. "$(dirname "$0")/../env.sh"
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
work 39a
bsc -o . $ROOT/aoc/bench/Day01 >/dev/null 2>&1      # Day01.abstr (written by the OTP-29 build of bsc; the .abstr is plain text)
cp $ROOT/aoc/bench/bench_erl.erl .
for otp in otp28 beam; do
  E=$S/mamba/envs/$otp/bin
  echo "=== $otp: $($E/erl -noshell -eval 'io:format("OTP ~s erts-~s",[erlang:system_info(otp_release),erlang:system_info(version)]),halt().')"
  mkdir -p $otp
  $E/erlc -S -o $otp bench_erl.erl
  $E/erl -noshell -eval 'compile:file("Day01.abstr",[from_abstr,'"'"'S'"'"',{outdir,"'$otp'"}]),halt().'
  python3 -I - $otp <<'B'
import re,sys
d=sys.argv[1]
ren={"Wrap":"wrap","Hit":"hit","Spin":"spin"}
def funs(path):
    t=open(path,encoding='latin-1').read()
    out={}
    for blk in re.split(r"\n(?=\{function, )",t):
        m=re.match(r"\{function, '?(\w+)'?, (\d+),",blk)
        if not m: continue
        name=ren.get(m.group(1),m.group(1)); body=blk.split("\n",1)[1]
        body=re.sub(r"\{line,\[.*?\]\}\.","",body,flags=re.S)       # source positions
        body=re.sub(r"%[^\n]*","",body)                                # trailing comments
        body=re.sub(r"\{label,\d+\}\.","",body)                       # label numbering
        body=re.sub(r"\{func_info,[^}]*\}[^.]*\.","",body)           # names
        body=re.sub(r"\{f,[1-9]\d*\}","{f,L}",body)                   # jump targets
        body=re.sub(r"\s+"," ",body).strip()
        out[name]=body
    return out
a=funs(d+"/bench_erl.S"); b=funs(d+"/Day01.S")
for f in ["wrap","hit","spin"]:
    print("  %-5s instruction stream identical incl. {tr,..}/var_info type facts: %s  (%d vs %d chars; {tr,} erlc=%d bsc=%d)"%(f, a[f]==b[f], len(a[f]), len(b[f]), a[f].count("{tr,"), b[f].count("{tr,")))
print("  (sign/size_/clicks differ because the two SOURCES differ: Erlang guards D>0 / D<0, B# orders d<0 first)")
B
done
