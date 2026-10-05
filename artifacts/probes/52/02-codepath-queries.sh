#!/usr/bin/env bash
# CLAIM (ticket 52): "Checking that the application is on the code path at compile time is one line."
# Which line, and does it give the same answer for an Elixir-in-ERL_LIBS dep, an OTP app, an app
# loadable only through its .app, a loose beam, and an absent app?  Run inside an escript, the same
# VM kind bsc is.  Three ERL_LIBS values.
# REFUTED IF: code:lib_dir/1 returns {error,bad_name} for the mix-built dep or for crypto when they are
#   reachable (then it is not "one line"); OR `ghost` (.app only) is reported present by lib_dir and ABSENT
#   by application:load (or the reverse) -> the one line would have to pick a side; OR code:which/1 finds the
#   loose beam while lib_dir finds an app for it.
. "$(dirname "$0")/lib.sh"
ELIXLIB=$SCRATCH/env/lib/elixir/lib
echo "######## S1: ERL_LIBS = mix-built dep : OTP-style apps : Elixir's lib dir"
ERL_LIBS=$MYLIBS:$ERLLIBS:$ELIXLIB escript "$ROOT/codepath.escript" "$WORK/loose"
echo; echo "######## S2: ERL_LIBS unset"
env -u ERL_LIBS escript "$ROOT/codepath.escript" "$WORK/loose"
echo; echo "######## S3: ERL_LIBS = OTP-style apps only"
ERL_LIBS=$ERLLIBS escript "$ROOT/codepath.escript" "$WORK/loose"
