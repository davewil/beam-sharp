#!/bin/sh
# Re-runnable: bsc is prebuilt, compiler/ is not touched. Output goes to run.out.
BSC=${BSC:-/home/user/beam-sharp/compiler/_build/default/bin/bsc}
cd "$(dirname "$0")" || exit 1
for m in Shop/Orders Shop/Orders/Internal/Cache Other/Thing Other/Tests Other/NoUsing; do
  echo "== bsc --src-root src src/$m"; $BSC --src-root src src/$m 2>&1; echo "[exit $?]"
done
echo "== run Other.Thing.Go 4 (an outsider names Shop.Orders.Internal.Cache today)"
$BSC --src-root src src/Other/Thing Go 4 2>&1; echo "[exit $?]"
