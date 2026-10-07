#!/bin/sh
export PATH=$HOME/.nix-profile/bin:$PATH
cd "$(dirname "$0")" || exit 1
escript probe.escript; rm -f *.beam
