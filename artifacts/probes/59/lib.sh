#!/usr/bin/env bash
# Shared by the ticket-59 probes. Builds SCRATCH copies of compiler/ patched to run under OTP 25 (repo pins
# OTP 28.5; plain `rebar3 escriptize` fails here). The repo is never modified.
#   build_bsc NAME [PATCHER]  -> echoes path of bsc. PATCHER, if given, is a script run as `PATCHER <builddir>`
#                                after the OTP-25 patch, to apply a scope variant to bs_emit.erl.
PROBES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$PROBES/../../.." && pwd)"
SCRATCH="${SCRATCH:-/tmp/claude-0/ws59-run}"
export LC_ALL=C.UTF-8
build_bsc() {
  local d="$SCRATCH/$1" patcher="${2:-}"
  if [ ! -x "$d/_build/default/bin/bsc" ]; then
    rm -rf "$d"; mkdir -p "$d"; cp -r "$REPO/compiler/." "$d/"; rm -rf "$d/_build"
    ( cd "$d"
      # PATCH 1 (OTP 25 leex has no error_location option and no TokenLoc): drop xrl_opts, drop warnings_as_errors,
      # make every token location {Line,1} (columns lost; emission unaffected) and stub adjust_col/3.
      sed -i 's/^{xrl_opts.*$/{xrl_opts, []}./; s/, warnings_as_errors//' rebar.config
      sed -i 's/TokenLoc/{TokenLine,1}/g' src/bs_lexer.xrl
      printf '\nadjust_col(_Chars, _Len, C) -> C.\n' >> src/bs_lexer.xrl
      if [ -n "$patcher" ]; then bash "$patcher" "$d" || exit 1; fi
      rebar3 escriptize >"$d/build.log" 2>&1 ) || { echo "bsc build failed; see $d/build.log" >&2; return 1; }
  fi
  echo "$d/_build/default/bin/bsc"
}
# print the emitted Erlang for every function of a .beam (abstract code)
pp_beam() { erl -noshell -eval '
  {ok,{_,[{abstract_code,{_,Forms}}]}} = beam_lib:chunks(hd(init:get_plain_arguments()),[abstract_code]),
  [io:put_chars(erl_pp:function(X)) || X={function,_,N,_,_} <- Forms, N =/= (bs@type_atoms)],
  io:format("exports: ~p~n",[lists:append([E || {attribute,_,export,E} <- Forms])]), halt().' -extra "$1"; }
