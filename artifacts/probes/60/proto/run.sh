#!/bin/sh
export PATH=$HOME/.nix-profile/bin:$PATH
cd "$(dirname "$0")" || exit 1
erlc may_name.erl && escript run_proto.escript mods.txt; rm -f may_name.beam
