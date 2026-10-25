# shared helper: source me. mk NAME < source  -> writes $W/NAME/NAME.bs
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
export PATH=$S/beam/bin:$PATH LANG=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu"
BSC=$S/bsc
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W=${W:-$S/64/work}; mkdir -p "$W"
mk () { mkdir -p "$W/$1"; cat > "$W/$1/$1.bs"; cp "$W/$1/$1.bs" "$HERE/src_$1.bs"; }
