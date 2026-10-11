#!/usr/bin/env bash
# Probe: Rust pub(in path) -- the callee names a module subtree that may name it, checked by rustc.
cd "$(dirname "$0")/rust" && rustc --version
rustc --edition 2021 --crate-type lib --emit=metadata -o /dev/null src/lib.rs 2>&1; echo "exit=$?"
echo "--- CONTROL: delete the 'elsewhere' module; the same file must compile"
sed '/^pub mod elsewhere/,$d' src/lib.rs > /tmp/rust_ctl_$$.rs; rustc --edition 2021 --crate-type lib --emit=metadata -o /dev/null /tmp/rust_ctl_$$.rs 2>&1; echo "exit=$?"; rm -f /tmp/rust_ctl_$$.rs
