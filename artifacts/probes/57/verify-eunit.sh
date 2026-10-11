#!/usr/bin/env bash
source /tmp/claude-0/env.sh
cd /tmp/claude-0/wp-$1/compiler && rebar3 eunit > /tmp/claude-0/eunit-$1.log 2>&1
echo FINISHED >> /tmp/claude-0/eunit-$1.log
