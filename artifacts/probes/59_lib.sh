# Shared by the 59_* probes. Source after env.sh.
# Builds four compilers from a COPY of compiler/ (never the repo's):
#   BSC_HEAD   unpatched                         tag test: every record fn; int/float test: exported only
#   BSC_EXP    59_uniform_exported_only.patch    both guards: exported only
#   BSC_ALL    59_uniform_all_functions.patch    both guards: every function
#   BSC_NOTAG  59_no_tag_test.patch              no tag test anywhere (measurement tool only)
# V59_DIR may be preset to reuse a build; otherwise a fresh mktemp dir is used.
PROBES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V59_DIR="${V59_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/p59.XXXXXX")}"
build_variant() { # name patch-or-empty
  local d="$V59_DIR/$1"
  if [ ! -x "$d/_build/default/bin/bsc" ]; then
    mkdir -p "$d"
    (cd "$REPO/compiler" && tar cf - --exclude=_build .) | (cd "$d" && tar xf -)
    # a/ b/ paths: apply with -p1 from the copy
    if [ -n "$2" ]; then (cd "$d" && patch -s -p1 < "$PROBES/$2") || { echo "patch $2 failed"; return 1; }; fi
    (cd "$d" && rebar3 escriptize >"$d/build.log" 2>&1) || { echo "build $1 failed"; tail "$d/build.log"; return 1; }
  fi
  echo "$d/_build/default/bin/bsc"
}
BSC_HEAD=$(build_variant head "")
BSC_EXP=$(build_variant exp 59_uniform_exported_only.patch)
BSC_ALL=$(build_variant all 59_uniform_all_functions.patch)
BSC_NOTAG=$(build_variant notag 59_no_tag_test.patch)
export V59_DIR BSC_HEAD BSC_EXP BSC_ALL BSC_NOTAG PROBES
