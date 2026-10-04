#!/bin/bash
# Rust: private modules are visible to the parent module's SUBTREE; `pub(in path)` restricts a single item
# to a named subtree. Both are compile-time only. rustc is installed, so this was RUN, not recalled.
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/rs"; rustc --version
echo "## ok.rs: the parent and a descendant name a private module and a pub(in) item"
rustc --edition 2021 -o /tmp/rs_ok ok.rs 2>&1 | head -5; /tmp/rs_ok
echo "## bad.rs: a SIBLING names them"
rustc --edition 2021 -o /tmp/rs_bad bad.rs 2>&1 | grep -E "^(error|warning)|-->|= note|^[0-9 ]*\|.*(private|visible)" | head -20
