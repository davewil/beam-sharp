#!/usr/bin/env bash
# Probe 64/05 - heap and serialised size of V vs {ok,V} vs {some,V}.
cd "$(dirname "$0")" && escript sizes.escript
