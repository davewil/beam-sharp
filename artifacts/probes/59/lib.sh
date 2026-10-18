# Shared by every probe. BSC = a built bsc wrapper (see run.sh header).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH=/tmp/bin:$PATH
SCRATCH=${SCRATCH:-/tmp/claude-0/-home-user-beam-sharp/9b30e02b-d742-5d59-8509-86bd14e28edc/scratchpad}
BSC=${BSC:-$SCRATCH/bsc}
WORK=${WORK:-$(mktemp -d)}; mkdir -p "$WORK"
# mod NAME <<< source : writes $WORK/NAME/a.bs (one directory is one module)
mod() { mkdir -p "$WORK/$1"; cat > "$WORK/$1/a.bs"; }
# abstr NAME : compile, leave $WORK/NAME/*.abstr/.beam
bsc_compile() { "$BSC" -o "$WORK/$1/out" "$WORK/$1" 2>&1; }
