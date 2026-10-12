# sourced by probes: BSC path, repo root, helper to pretty-print .abstr
PROBES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$PROBES/../.." && pwd)"
BSC="$REPO/compiler/_build/default/bin/bsc"
# pp_abstr FILE.abstr : pretty-print each form as Erlang source
pp_abstr() {
  erl -noshell -eval '{ok,Fs}=file:consult(hd(init:get_plain_arguments())), [io:put_chars(erl_pp:form(F)) || F <- Fs], halt().' -extra "$1"
}
# beam_asm FILE.beam : print the function's disassembly of named function
