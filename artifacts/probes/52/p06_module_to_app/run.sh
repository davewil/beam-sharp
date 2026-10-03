#!/bin/sh
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
cd "$(dirname "$0")"; escript derive.escript
