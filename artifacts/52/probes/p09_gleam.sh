#!/usr/bin/env bash
# p09: Gleam 1.12.0, offline, no dependencies.  (1) @external to an Erlang module that does not exist;
# (2) `import` of a Gleam module/package that does not exist.  Where is the dependency declared and who checks it?
cd "$(dirname "$0")/neighbours"
echo '--- 1. @external(erlang, "libdep_not_there", "hello"): build'
( cd gleam_ext && /tmp/tools/gleam build 2>&1 | tail -6; echo "build exit=${PIPESTATUS[0]}"
  echo '--- 1b. run it'
  /tmp/tools/gleam run 2>&1 | tail -6 )
echo '--- 2. import libdep_pkg/thing (no such package in gleam.toml [dependencies]): build'
( cd gleam_imp && /tmp/tools/gleam build 2>&1 | tail -12; echo "build exit=${PIPESTATUS[0]}" )
