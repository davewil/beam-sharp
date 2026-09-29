#!/usr/bin/env bash
# Ticket 52 (ENG-234) probe suite. Re-runnable: ./run.sh   Prints PASS/FAIL per probe against the expectation written
# in that probe's own file BEFORE it was first run. A FAIL is a finding, not a bug in this script: three probes
# (2b, 3b, 6a) had wrong expectations and are meant to keep printing FAIL; see the brief, section 2.
# Toolchains: OTP 25, Elixir 1.14.0, gleam 1.12.0, elm 0.19.2 (paths below), reference bsc built from HEAD.
S=/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad
BSC=${BSC:-$S/bsc.sh}; GEN=${GEN:-$S/bsc/gen}
here=$(cd "$(dirname "$0")" && pwd); cd "$here"
W=${TMPDIR:-/tmp}/p52work; mkdir -p "$W"
pass=0; fail=0
t() { # t ID "description" <command returning 0 when the expectation holds>
  local id=$1 d=$2; shift 2
  if "$@" >/dev/null 2>&1; then echo "PASS $id  $d"; pass=$((pass+1)); else echo "FAIL $id  $d"; fail=$((fail+1)); fi; }
has() { grep -q -- "$1" "$2"; }
hasnt() { ! grep -q -- "$1" "$2"; }

# ---- P1: reference compiler, module absent vs present -------------------------------------------------
# EXPECTED (before run): both files COMPILE (exit 0) on a machine where the module is absent; the absent one fails at
# the call with `crashed: error:undef`; Present works only with ERL_LIBS naming Elixir's lib dir (prints 3).
(cd p1; rm -rf out; mkdir out
 env -u ERL_LIBS $BSC --src-root . -o out Absent >"$W/p1-compile-absent.txt" 2>&1; echo "exit=$?" >>"$W/p1-compile-absent.txt"
 env -u ERL_LIBS $BSC --src-root . -o out Absent Count "[1,2,3]" >"$W/p1-run-absent.txt" 2>&1
 env -u ERL_LIBS $BSC --src-root . -o out Present Count "[1,2,3]" >"$W/p1-run-present-nolibs.txt" 2>&1
 ERL_LIBS=/usr/lib/elixir/lib $BSC --src-root . -o out Present Count "[1,2,3]" >"$W/p1-run-present-libs.txt" 2>&1)
t P1a "Absent (no such module) COMPILES, exit 0"            has 'exit=0' "$W/p1-compile-absent.txt"
t P1b "Absent fails at the call: error:undef"               has 'crashed: error:undef' "$W/p1-run-absent.txt"
t P1c "Present compiles but is undef without ERL_LIBS"      has 'crashed: error:undef' "$W/p1-run-present-nolibs.txt"
t P1d "Present runs with ERL_LIBS (prints 3)"               has '^3$' "$W/p1-run-present-libs.txt"

# ---- P1v: the check prototyped in a patched COPY of bsc (p1/v1.patch; HEAD sources are untouched) ------------
# EXPECTED (before run): with the patch, Absent is refused at compile time naming the module, Present passes with
# ERL_LIBS and is refused without it, `--api` refuses too (the check lives in declared/4, shared by compile and --api),
# and the 21 in-repo example directories still compile (the check has no false positive on the OTP-only corpus).
rm -rf "$W/cc"; mkdir -p "$W/cc/src" "$W/cc/ebin"; cp "$here/../../../compiler/src/"*.erl "$W/cc/src/"
(cd "$W/cc/src" && patch -s bs_check.erl < <(awk '/^--- a\/bs_check/{f=1} /^--- a\/bs_diag/{f=0} f' "$here/p1/v1.patch") && patch -s bs_diag.erl < <(awk '/^--- a\/bs_diag/{f=1} f' "$here/p1/v1.patch"))
for f in "$W"/cc/src/*.erl "$GEN/bs_lexer.erl" "$GEN/bs_parser.erl"; do erlc -o "$W/cc/ebin" -I "$W/cc/src" "$f" >/dev/null 2>&1; done
V1="erl -noshell -pa $W/cc/ebin -eval bsc:main(init:get_plain_arguments()),halt(). -extra"
(cd p1; mkdir -p out
 env -u ERL_LIBS $V1 --src-root . -o out Absent >"$W/v1-absent.txt" 2>&1; echo "exit=$?" >>"$W/v1-absent.txt"
 env -u ERL_LIBS $V1 --src-root . --api Absent >"$W/v1-api-absent.txt" 2>&1
 env -u ERL_LIBS $V1 --src-root . -o out Present >"$W/v1-present-nolibs.txt" 2>&1; echo "exit=$?" >>"$W/v1-present-nolibs.txt"
 ERL_LIBS=/usr/lib/elixir/lib $V1 --src-root . -o out Present Count "[1,2,3]" >"$W/v1-present-libs.txt" 2>&1)
t P1e "patched: Absent refused at compile time, exit 1"     bash -c "grep -q 'names a module that is not on the code path' $W/v1-absent.txt && grep -q 'exit=1' $W/v1-absent.txt"
t P1f "patched: Present refused without ERL_LIBS"           has 'not on the code path' "$W/v1-present-nolibs.txt"
t P1g "patched: Present still runs (3) with ERL_LIBS"       has '^3$' "$W/v1-present-libs.txt"
t P1h "patched: --api refuses too (check sits in declared/4)" has 'not on the code path' "$W/v1-api-absent.txt"
bad=0; for d in ../../../compiler/examples/*/; do n=$(basename "$d"); [ "$n" = exemplars ] && continue
  (cd ../../../compiler && env -u ERL_LIBS $V1 --src-root examples -o "$W" examples/$n >/dev/null 2>&1) || bad=$((bad+1)); done
t P1i "patched: all 21 in-repo example dirs still compile"  test "$bad" = 0

# ---- P2: code-path questions -------------------------------------------------------------------------------
env -u ERL_LIBS ./p2/probe.escript >"$W/p2-unset.txt" 2>&1
ERL_LIBS=/usr/lib/elixir/lib ./p2/probe.escript >"$W/p2-with.txt" 2>&1
t P2-E1 "lib_dir(elixir): bad_name unset, a path with ERL_LIBS" bash -c "grep -q 'lib_dir(elixir) *{error,bad_name}' $W/p2-unset.txt && grep -q 'lib_dir(elixir) *\"/usr/lib/elixir/lib/elixir\"' $W/p2-with.txt"
t P2-E2 "lib_dir(nope): bad_name"                          has 'lib_dir(nope) *{error,bad_name}' "$W/p2-with.txt"
t P2-E3 "which('Elixir.Enum'): non_existing unset, a beam path with ERL_LIBS" bash -c "grep -q \"which('Elixir.Enum') *non_existing\" $W/p2-unset.txt && grep -q \"which('Elixir.Enum') *\\\"/usr/lib/elixir/lib/elixir/ebin/Elixir.Enum.beam\\\"\" $W/p2-with.txt"
t P2-E4 "module-only beam: which finds it, lib_dir(loosemod) bad_name" bash -c "grep -q 'which(loosemod) after add_patha *\"loosemod.beam\"' $W/p2-with.txt && grep -q 'lib_dir(loosemod) *{error,bad_name}' $W/p2-with.txt"
t P2-E5 "application:load(elixir): ok with ERL_LIBS, no such file without" bash -c "grep -q 'application:load(elixir) *ok' $W/p2-with.txt && grep -A2 'application:load(elixir) ' $W/p2-unset.txt | grep -q 'elixir.app'"
lib=$(awk '/TIME lib_dir\(elixir\)/{print $4}' "$W/p2-with.txt"); wh=$(awk '/TIME which\(.Elixir.Enum.\) unloaded/{print $5}' "$W/p2-with.txt")
t P2-E6 "lib_dir < 20 us; which on an unloaded module >= 50x slower (min: ${lib}us vs ${wh}us)" awk -v a="$lib" -v b="$wh" 'BEGIN{exit !(a<20 && b/a>=50)}'
./p2/probe2b.escript >"$W/p2b.txt" 2>&1 <<<""
# Expectation written before the run: lib_dir(bare) stays {error,bad_name}. Observed "./bare": lib_dir/1 matches any path entry by directory name.
t P2b   "lib_dir(bare) == bad_name for a beam in a dir not shaped <app>/ebin  [expected to FAIL: expectation was wrong]" has 'lib_dir(bare) *{error,bad_name}' "$W/p2b.txt"
t P2b-2 "lib_dir(myapp) bad_name before add_patha, found after"  bash -c "grep -q 'before   lib_dir(myapp) {error,bad_name}' $W/p2b.txt && grep -q 'after    lib_dir(myapp) \"myapp\"' $W/p2b.txt"
ERL_LIBS=/usr/lib/elixir/lib ./p2/derive.escript >"$W/p2c.txt" 2>&1
t P2c   "app derivable from a beam path: get_application undefined then {ok,elixir}; dir names elixir / stdlib-4.3.1.3" bash -c "grep -q 'before load: undefined' $W/p2c.txt && grep -q 'after load : {ok,elixir}' $W/p2c.txt && grep -q 'app dir elixir' $W/p2c.txt && grep -q 'app dir stdlib-4.3.1.3' $W/p2c.txt"

# ---- P3: mix (Elixir 1.14.0, hex not installed) ------------------------------------------------------------
./p3/run.sh >"$W/p3.txt" 2>&1
sec() { awk -v s="$1" 'index($0,s){f=1;next} /^=== /{f=0} f' "$W/p3.txt"; }
sec "=== a_extra_app: mix compile" >"$W/p3a.txt";  sec "=== c_undef_call: mix compile" >"$W/p3c.txt"
sec "=== b_hexdep: mix compile" >"$W/p3b.txt"
sec "=== 3d missing path dep: mix compile" >"$W/p3d1.txt"; sec "=== 3d missing path dep: mix compile --no-deps-check" >"$W/p3d2.txt"; sec "=== 3d present-but-uncompiled path dep: mix compile" >"$W/p3d3.txt"
t P3a "mix compile succeeds silently with extra_applications [:nope_app]" bash -c "grep -q 'exit=0' $W/p3a.txt && ! grep -qi warning $W/p3a.txt"
t P3a2 "nope_app lands in the .app applications list; failure only at start" bash -c "grep -q 'applications,\[kernel,stdlib,elixir,logger,nope_app\]' $W/p3.txt && grep -q 'could not find application file: nope_app.app' $W/p3.txt"
t P3b "hex dep, hex absent: refused with an 'Unchecked dependencies' error; --no-deps-check compiles  [expected to FAIL: hex-less mix stops earlier with 'Could not find an SCM']" bash -c "grep -q 'Unchecked dependencies' $W/p3b.txt"
t P3c "call to a nonexistent module: compiles, exit 0, with an 'undefined (module ... not available)' warning" bash -c "grep -q 'Nope.Module.call/1 is undefined (module Nope.Module is not available' $W/p3c.txt && grep -q 'exit=0' $W/p3c.txt"
t P3d1 "missing path dep: mix compile refused (Unchecked dependencies), exit 1"  bash -c "grep -q 'Unchecked dependencies' $W/p3d1.txt && grep -q 'exit=1' $W/p3d1.txt"
t P3d2 "missing path dep: --no-deps-check compiles anyway, exit 0"  bash -c "grep -q 'Generated d app' $W/p3d2.txt && grep -q 'exit=0' $W/p3d2.txt"
t P3d3 "present-but-uncompiled path dep: mix builds it, exit 0"  bash -c "grep -q 'Generated dd app' $W/p3d3.txt && grep -q 'exit=0' $W/p3d3.txt"

# ---- P4: Erlang precedent ---------------------------------------------------------------------------------
./p4/run.sh >"$W/p4.txt" 2>&1
t P4a "erlc on a call to a missing module: exit 0, no warning" bash -c "grep -q 'erlc exit=0' $W/p4.txt && ! grep -qi 'warning' $W/p4.txt"
t P4b "-required_app(nope_app) is accepted and stored, nothing checks it" has '^\[nope_app\]$' "$W/p4.txt"
t P4c "xref (with +debug_info) reports {caller,f,0} -> {'Elixir.Nope',count,1}" has "{{caller,f,0},{'Elixir.Nope',count,1}}" "$W/p4.txt"
t P4c0 "xref on a beam without debug_info reports nothing (setup trap, not a finding about Nope)" has 'no debug information' "$W/p4.txt"
t P4d "app list: load ok, ensure_all_started fails, systools reports undefined_applications" bash -c "grep -q 'load: ok' $W/p4.txt && grep -q '{error,{nope_app,{\"no such file or directory\"' $W/p4.txt && grep -q 'undefined_applications,\[nope_app\]' $W/p4.txt"

# ---- P5: Gleam 1.12.0 offline -----------------------------------------------------------------------------
./p5/run.sh >"$W/p5.txt" 2>&1
sec5() { awk -v s="=== $1" 'index($0,s)==1{f=1;next} /^=== /{f=0} f' "$W/p5.txt"; }
sec5 a_external >"$W/p5a.txt"; sec5 b_dep >"$W/p5b.txt"; sec5 c_import >"$W/p5c.txt"
t P5a "@external to a nonexistent Erlang module: gleam build succeeds"  bash -c "grep -q 'exit=0' $W/p5a.txt && grep -q \"'Elixir.Nope':count\" $W/p5.txt"
t P5b "gleam.toml dependency, no network: fails at dependency resolution, exit 1" bash -c "grep -q 'Dependency resolution failed' $W/p5b.txt && grep -q 'exit=1' $W/p5b.txt"
t P5c "import of a module in no declared package: Unknown module, exit 1"  bash -c "grep -q 'error: Unknown module' $W/p5c.txt && grep -q 'exit=1' $W/p5c.txt"

# ---- P6: Elm 0.19.2 offline -------------------------------------------------------------------------------
./p6/run.sh >"$W/p6.txt" 2>&1
sec6() { awk -v s="=== $1" 'index($0,s)==1{f=1;next} /^=== /{f=0} f' "$W/p6.txt"; }
sec6 6a >"$W/p6a.txt"; sec6 6b >"$W/p6b.txt"
t P6a "elm.json with elm/core only: fails on the registry  [expected to FAIL: it fails EARLIER on a local outline check, MISSING DEPENDENCY elm/json]" has 'PROBLEM LOADING PACKAGE LIST' "$W/p6a.txt"
t P6a2 "observed instead: MISSING DEPENDENCY elm/json, before any network"  has 'MISSING DEPENDENCY' "$W/p6a.txt"
t P6b "with elm/json added: reaches the registry, 403, exit 1, nothing said about Http" bash -c "grep -q 'PROBLEM LOADING PACKAGE LIST' $W/p6b.txt && grep -q 'exit=1' $W/p6b.txt && ! grep -qi 'http' <(grep -v 'package.elm-lang.org\|HTTP library' $W/p6b.txt)"

# ---- P7: cost -----------------------------------------------------------------------------------------------
env -u ERL_LIBS ./p7/which.escript >"$W/p7w.txt" 2>&1
t P7b "which/1 on loaded/preloaded modules is single-digit-to-tens of microseconds; on an unloaded one ~0.3 ms (first 3 runs' zip line)" bash -c "awk '/first which\(zip/{ if (\$4+0 < 100) exit 1 } /first which\(ets/{ if (\$4+0 > 60) exit 1 }' $W/p7w.txt"
env -u ERL_LIBS ./p7/corpus.escript >"$W/p7c.txt" 2>&1
t P7c "corpus: json and epgsql are non_existing on this OTP 25 machine; lists/erlang found" bash -c "grep -q 'json .*non_existing' $W/p7c.txt && grep -q 'epgsql .*non_existing' $W/p7c.txt && ! grep -q 'lists .*non_existing' $W/p7c.txt"
echo "INFO P7 end-to-end compile time (noisy; see p7/out.txt for the captured runs): run  TMPDIR=\$TMPDIR ./p7/time.escript EBIN SRC"
echo; echo "summary: $pass PASS, $fail FAIL  (3 FAIL lines are the pre-stated expectations that were wrong: P2b, P3b, P6a)"
