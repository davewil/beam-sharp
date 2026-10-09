#!/bin/bash
cd /home/user/beam-sharp && D=$(mktemp -d) && erlc -o $D artifacts/probes/60/p9_check_micro.erl && erl -noshell -pa $D -eval 'p9_check_micro:main(), halt().'
rm -rf $D
