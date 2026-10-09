#!/bin/bash
# P8: bytes of per-module compiler-memory metadata each option adds (the World entry is in-memory only; bsc.erl:204-209 "No artefact").
cd /home/user/beam-sharp && D=$(mktemp -d) && erlc -o $D artifacts/probes/60/p8_metadata_size.erl && erl -noshell -pa /tmp/bsbuild/ebin $D -eval 'p8_metadata_size:main(), halt().'
rm -rf $D
