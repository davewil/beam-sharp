#!/bin/bash
# Probe 03 (c): BEAM code-size delta of each guard scope, measured as the difference in the Code
# chunk (and instruction count) of the SAME source compiled by the three compiler variants
# (base = current, narrow = tag test exported-only, wide = int/float/range tests on private too, proj = narrow + one-level projection tests at the exported entry).
# Method follows prototypes/18a: one source, only the compiler differs, so the delta is exactly the
# guards (+ whatever the Erlang optimiser does with them - reported, not hidden).
# Cases:
#  rec3 / rec8 : private Inner(Order) with 3 / 8 fields, called from an exported Outer(Order)  [tag test; flat in fields?]
#  intP        : private Scale(int) called ONLY with a proven integer (exported ViaInt(int) guards first)
#  intU        : private Scale(int) called with an UNPROVEN value (projected record field) -> guard is not elidable
#  oct         : private Scale(Octet) (kind + 2 range comparisons) behind a guarded exported caller
#  big2        : the intU shape with TWO int params on the private function
cd "$(dirname "$0")"; . ./lib.sh
W=$(mktemp -d)
mk() { # name, source
  for v in base narrow wide proj; do mkdir -p $W/$v/$1 $W/$v/o; printf '%s\n' "$2" > $W/$v/$1/$1.bs; done; }
mk Rec3 'module Rec3
record Order { Id: int, Total: int, A: int }
int Inner(Order o)
Inner(o) -> o.Total
public int Outer(Order o)
Outer(o) -> Inner(o)'
mk Rec8 'module Rec8
record Order { Id: int, Total: int, A: int, B: int, C: int, D: int, E: int, F: int }
int Inner(Order o)
Inner(o) -> o.Total
public int Outer(Order o)
Outer(o) -> Inner(o)'
mk IntP 'module IntP
int Scale(int n)
Scale(n) -> n * 2
public int ViaInt(int n)
ViaInt(n) -> Scale(n)'
mk IntU 'module IntU
record Cart { Qty: int }
int Scale(int n)
Scale(n) -> n * 2
public int Field(Cart c)
Field(c) -> Scale(c.Qty)'
mk Oct 'module Oct
type Octet = int where value >= 0 and value <= 255
int Scale(Octet n)
Scale(n) -> n * 2
public int ViaOct(Octet n)
ViaOct(n) -> Scale(n)'
mk Big2 'module Big2
record Cart { Qty: int, Pr: int }
int Mul(int a, int b)
Mul(a, b) -> a * b
public int Field(Cart c)
Field(c) -> Mul(c.Qty, c.Pr)'
printf "%-6s %-7s %10s %10s %8s   %s\n" case variant Code_bytes file_bytes instrs "delta vs base (Code bytes / instrs)"
for c in Rec3 Rec8 IntP IntU Oct Big2; do
  for v in base narrow wide proj; do
    /tmp/p59/bin/bsc-$v -o $W/$v/o $W/$v/$c >/dev/null 2>&1 || { echo "compile failed $c $v"; continue; }
  done
  erl -noshell -eval '
    [W,C]=[hd(init:get_plain_arguments()), lists:nth(2,init:get_plain_arguments())],
    SgF=fun(X) when X>0 -> "+"++integer_to_list(X); (X) -> integer_to_list(X) end,
    M = fun(V) -> B = W++"/"++V++"/o/"++C++".beam", {ok,_,Cs}=beam_lib:all_chunks(B),
              {"Code",Code}=lists:keyfind("Code",1,Cs),
              {beam_file,_,_,_,_,Fs}=beam_disasm:file(B),
              N = lists:sum([length([I || I <- Is, element(1,I)=/=label, element(1,I)=/=line]) || {function,Nm,_,_,Is}<-Fs, Nm=/=module_info]),
              {byte_size(Code), filelib:file_size(B), N} end,
    {B0,F0,N0}=M("base"),
    [begin {B,F,N}=M(V), io:format("~-6s ~-7s ~10w ~10w ~8w   ~s~n",[C,V,B,F,N, if V=:="base"->""; true-> io_lib:format("~s B / ~s instrs (file ~s; the file delta includes the debug_info chunk, i.e. the abstract code, which keeps guards the optimiser elided)",[SgF(B-B0),SgF(N-N0),SgF(F-F0)]) end]) end || V<-["base","narrow","wide","proj"]], halt().' -extra $W $c
done
echo
echo "=== the emitted guards for the cases, per variant (private function only) ==="
for c in Rec3 IntU; do for v in base narrow wide proj; do echo "--- $c / $v"; abstr $W/$v/o/$c.beam | grep -A2 "^'Inner'\|^'Scale'"; done; done
