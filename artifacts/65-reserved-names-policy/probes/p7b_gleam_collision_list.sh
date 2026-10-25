#!/usr/bin/env bash
# P7b: which other OTP-ish module names does gleam 1.19.1 refuse as local modules? (run p7 first to create the project)
export PATH=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/beam/bin:$PATH LANG=C.UTF-8
cd /tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/65/p7/probe || exit 1
for m in kernel stdlib code application init io string unicode file gen_server; do
  find src -name '*.gleam' -delete
  printf 'pub fn f() { 1 }\n' > src/$m.gleam; printf 'pub fn main() { 1 }\n' > src/probe.gleam
  r=$(gleam build 2>&1 | grep -c 'name collision'); echo "src/$m.gleam -> collision-refusals=$r"
done
