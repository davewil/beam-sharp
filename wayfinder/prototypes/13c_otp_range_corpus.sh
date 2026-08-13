#!/usr/bin/env bash
# 13c — does the abstract format `bsc` emits build on the whole pinned OTP range?
#
# Ticket 13 §5 pinned the supported range at "current and previous two majors" and recorded it as
# PROVISIONAL: `+from_abstr` was confirmed on OTP 28.5 only, because that is what was installed.
# §2's guarantee — that the frontend never depends on in-process compiler state, which is what
# freed the compiler's host language — rests entirely on `erlc +from_abstr` existing and behaving
# across the range. This measures it.
#
# Three questions, and the third is the one nobody had asked:
#   1. Does `erlc +from_abstr` exist on OTP 26 and 27 at all?
#   2. Do the forms *this compiler* emits build there unchanged, and are the modules callable?
#   3. Does the emitted `-spec` survive the older path intact? Ticket 13 found the `.core` path
#      silently drops it; backwards compatibility had never been checked.
#
# Two corpora, deliberately:
#   * the committed examples, which is what the compiler actually produces today; and
#   * a **synthetic vocabulary module**, because the examples turn out to exercise only six of
#     `bs_emit`'s type branches and seven of its operators. Testing only the examples would have
#     called the range proved while five type forms and four operators went unvisited.
#
# Uses arm64-native images. That is not incidental: `research/29` gap [g3] found amd64 emulation
# on this machine is unreliable to the point that debian:13 containers will not start at all.
#
# Usage:  ./13c_otp_range_corpus.sh [OTP ...]      default: 26 27
# Needs:  docker with arm64 images, and a built compiler (rebar3 compile in compiler/).

set -u
cd "$(dirname "$0")/../.."                      # repo root

VERSIONS=${*:-26 27}
EBIN=compiler/_build/default/lib/bsc/ebin
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ ! -d "$EBIN" ]; then
  echo "building the compiler first"
  ( cd compiler && rebar3 compile >/dev/null ) || exit 1
fi

echo "=== host OTP (where the .abstr is generated) ==="
erl -noshell -eval 'io:format("  OTP ~s, erts ~s~n",
  [erlang:system_info(otp_release), erlang:system_info(version)]), halt(0).'

# ---------------------------------------------------------------------------------------
# Corpus 1 — the committed examples, via the compiler itself.
#
# NOTE: driven through `bsc:main/1` rather than the escript, because rebar.config sets
# `{escript_emu_args, "%%! -escript main bsc_cli\n"}` while the module is `bsc`, so the built
# escript dies with `undefined function bsc_cli:main/1`. That is a compiler bug and fixing it is
# outside this probe's write_scope; it is reported in research/13-otp-range-corpus.md.
# ---------------------------------------------------------------------------------------
( cd compiler && erl -pa _build/default/lib/bsc/ebin -noshell -eval "
    bsc:main([\"-o\", \"$WORK\", \"examples/readings.bs\", \"examples/math.bs\"]), halt(0)." ) \
  || { echo "could not generate .abstr from the examples"; exit 1; }
rm -f "$WORK"/*.beam                            # keep only the .abstr; the older runtimes rebuild

# ---------------------------------------------------------------------------------------
# Corpus 2 — every form `bs_emit` can produce.
#
# Derived by reading src/bs_emit.erl: `int_part/1` has range / neg_integer / non_neg_integer /
# pos_integer branches and `spec_type/1` has a `none` branch, none of which the examples reach,
# and `erl_op/1` maps four operators the examples never emit. Hand-written rather than generated,
# because several branches are not reachable from the surface language this slice implements —
# which is itself recorded as a finding.
# ---------------------------------------------------------------------------------------
cat > "$WORK/Coverage.abstr" <<'ABSTR'
{attribute,0,module,'Coverage'}.
{attribute,0,export,[{'Rng',1},{'Neg',1},{'NonNeg',1},{'Pos',1},{'AtomTop',1},{'Nested',1},{'Ops',2},{'Never',1}]}.
{attribute,0,spec,{{'Rng',1},[{type,0,'fun',[{type,0,product,[{type,0,integer,[]}]},{type,0,range,[{integer,0,5},{integer,0,20}]}]}]}}.
{attribute,0,spec,{{'Neg',1},[{type,0,'fun',[{type,0,product,[{type,0,integer,[]}]},{type,0,neg_integer,[]}]}]}}.
{attribute,0,spec,{{'NonNeg',1},[{type,0,'fun',[{type,0,product,[{type,0,integer,[]}]},{type,0,non_neg_integer,[]}]}]}}.
{attribute,0,spec,{{'Pos',1},[{type,0,'fun',[{type,0,product,[{type,0,integer,[]}]},{type,0,pos_integer,[]}]}]}}.
{attribute,0,spec,{{'AtomTop',1},[{type,0,'fun',[{type,0,product,[{type,0,atom,[]}]},{type,0,atom,[]}]}]}}.
{attribute,0,spec,{{'Nested',1},[{type,0,'fun',[{type,0,product,[{type,0,tuple,[{atom,0,ok},{type,0,tuple,[{type,0,integer,[]},{type,0,union,[{atom,0,a},{atom,0,b}]}]}]}]},{type,0,integer,[]}]}]}}.
{attribute,0,spec,{{'Ops',2},[{type,0,'fun',[{type,0,product,[{type,0,integer,[]},{type,0,integer,[]}]},{type,0,union,[{atom,0,yes},{atom,0,no}]}]}]}}.
{attribute,0,spec,{{'Never',1},[{type,0,'fun',[{type,0,product,[{type,0,integer,[]}]},{type,0,none,[]}]}]}}.
{function,0,'Rng',1,[{clause,1,[{var,1,'N'}],[[{op,1,'>',{var,1,'N'},{integer,1,0}}]],[{integer,1,7}]},{clause,2,[{var,2,'_N'}],[],[{integer,2,5}]}]}.
{function,0,'Neg',1,[{clause,3,[{var,3,'_N'}],[],[{op,3,'-',{integer,3,0},{integer,3,1}}]}]}.
{function,0,'NonNeg',1,[{clause,4,[{var,4,'_N'}],[],[{integer,4,0}]}]}.
{function,0,'Pos',1,[{clause,5,[{var,5,'_N'}],[],[{integer,5,1}]}]}.
{function,0,'AtomTop',1,[{clause,6,[{var,6,'A'}],[],[{var,6,'A'}]}]}.
{function,0,'Nested',1,[{clause,7,[{tuple,7,[{atom,7,ok},{tuple,7,[{var,7,'N'},{atom,7,a}]}]}],[],[{var,7,'N'}]},{clause,8,[{tuple,8,[{atom,8,ok},{tuple,8,[{var,8,'N'},{atom,8,b}]}]}],[],[{op,8,'*',{var,8,'N'},{integer,8,2}}]}]}.
{function,0,'Ops',2,[{clause,9,[{var,9,'A'},{var,9,'B'}],[[{op,9,'orelse',{op,9,'=:=',{var,9,'A'},{var,9,'B'}},{op,9,'=/=',{var,9,'A'},{integer,9,0}}}]],[{atom,9,yes}]},{clause,10,[{var,10,'_A'},{var,10,'_B'}],[],[{atom,10,no}]}]}.
{function,0,'Never',1,[{clause,11,[{var,11,'_N'}],[],[{call,11,{remote,11,{atom,11,erlang},{atom,11,error}},[{atom,11,nope}]}]}]}.
ABSTR

echo
echo "=== what each corpus exercises ==="
printf '  examples  type forms: '; grep -oh "{type,0,[a-z_']*" "$WORK"/Readings.abstr "$WORK"/Math.abstr | sed 's/.*,//' | sort -u | tr '\n' ' '; echo
printf '  coverage  type forms: '; grep -oh "{type,0,[a-z_']*" "$WORK"/Coverage.abstr | sed 's/.*,//' | sort -u | tr '\n' ' '; echo
printf '  examples  operators : '; grep -oh "{op,[0-9]*,'[^']*'" "$WORK"/Readings.abstr "$WORK"/Math.abstr | sed "s/.*,'/'/" | sort -u | tr '\n' ' '; echo
printf '  coverage  operators : '; grep -oh "{op,[0-9]*,'[^']*'" "$WORK"/Coverage.abstr | sed "s/.*,'/'/" | sort -u | tr '\n' ' '; echo

# ---------------------------------------------------------------------------------------
# Helper scripts go in files rather than inline `-eval` strings: passing Erlang through bash,
# then docker, then `erl -eval` mangled the format string and produced a boot crash that looked
# like a compatibility failure and was not one.
# ---------------------------------------------------------------------------------------
cat > "$WORK/spec_hash.escript" <<'ESCRIPT'
#!/usr/bin/env escript
%% Print each module's emitted -spec attributes as a hash, so equality across releases is
%% checkable at a glance. Equal hashes mean the spec survived byte-identically.
main([Beam]) ->
    {ok, {M, [{abstract_code, {raw_abstract_v1, Forms}}]}} =
        beam_lib:chunks(Beam, [abstract_code]),
    Specs = [S || S = {attribute, _, spec, _} <- Forms],
    io:format("~-10s ~2w spec(s)  phash2=~p~n", [M, length(Specs), erlang:phash2(Specs)]).
ESCRIPT

cat > "$WORK/call.escript" <<'ESCRIPT'
#!/usr/bin/env escript
%%! -pa /tmp/o
main(_) ->
    Show = fun(Label, F) -> io:format("      ~-28s = ~p~n", [Label, (catch F())]) end,
    Show("Readings:Classify({ok,5})",   fun() -> 'Readings':'Classify'({ok, 5}) end),
    Show("Math:Fib(10)",                fun() -> 'Math':'Fib'(10) end),
    Show("Coverage:Ops(1,1)",           fun() -> 'Coverage':'Ops'(1, 1) end),
    Show("Coverage:Nested({ok,{3,b}})", fun() -> 'Coverage':'Nested'({ok, {3, b}}) end),
    Show("Coverage:Rng(9)",             fun() -> 'Coverage':'Rng'(9) end).
ESCRIPT

RUNNER='
set -u
mkdir -p /tmp/o
for f in Readings Math Coverage; do
  printf "  %-18s " "$f.abstr"
  if erlc +from_abstr +debug_info -o /tmp/o "$W/$f.abstr" 2>/tmp/err; then echo "BUILT"
  else echo "FAILED:"; sed "s/^/      /" /tmp/err; fi
done
echo "  --- callable:"
escript "$W/call.escript"
echo "  --- emitted -spec per module:"
for m in Readings Math Coverage; do
  printf "      "
  escript "$W/spec_hash.escript" "/tmp/o/$m.beam"
done'

run_on() {                                       # run_on <label> <docker-image-or-empty>
  local label=$1 img=${2:-}
  echo
  echo "=== $label ==="
  if [ -z "$img" ]; then
    W="$WORK" bash -c "$RUNNER"
  else
    docker run --rm --platform linux/arm64 -v "$WORK:/w" -w /w -e W=/w "$img" bash -c "$RUNNER"
  fi
}

for v in $VERSIONS; do
  run_on "OTP $v (docker erlang:$v, arm64)" "erlang:$v"
done
run_on "OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt(0).') (host, reference)" ""

echo
echo "The -spec hashes are erlang:phash2 over each module's spec attributes. Equal hashes across"
echo "releases mean the emitted spec survived the older path byte-identically."

# ---------------------------------------------------------------------------------------
# Which artefact is actually portable?
#
# The `.abstr` travels. The `.beam` does not, and neither does the compiler's own `.beam`.
# That is a different axis from ticket 13 §5's range and is easy to conflate with it: the pinned
# range constrains the *target runtime that runs erlc +from_abstr*, not the build host, and not
# the binaries either one produces.
# ---------------------------------------------------------------------------------------
echo
echo "=== which artefact is portable? ==="
HOSTBUILT=$(mktemp -d)
( cd compiler && erl -pa _build/default/lib/bsc/ebin -noshell \
    -eval "bsc:main([\"-o\", \"$HOSTBUILT\", \"examples/readings.bs\"]), halt(0)." >/dev/null 2>&1 )

# Output is captured rather than piped: `docker run` inside the loop with a trailing pipe
# swallowed its own stdout here, and a silent line reads exactly like a passing one.
load_on() {                                      # load_on <image> <mount> <beam-without-extension>
  docker run --rm --platform linux/arm64 -v "$2" "$1" \
    erl -noshell -eval "io:format(\"~p~n\",[code:load_abs(\"$3\")]), halt(0)." </dev/null 2>&1 \
    | tr -d '\r' | grep -E '^\{' | tail -1
}

for v in $VERSIONS; do
  printf '  a host-built beam-sharp .beam on OTP %-3s  %s\n' "$v" \
    "$(load_on "erlang:$v" "$HOSTBUILT:/w" /w/Readings)"
  printf '  the compilers own .beam on OTP %-3s        %s\n' "$v" \
    "$(load_on "erlang:$v" "$PWD/compiler:/c" /c/_build/default/lib/bsc/ebin/bsc)"
done
printf '  control: the same .beam on the host       %s\n' \
  "$(erl -noshell -eval "io:format(\"~p~n\",[code:load_abs(\"$HOSTBUILT/Readings\")]), halt(0).")"
rm -rf "$HOSTBUILT"
