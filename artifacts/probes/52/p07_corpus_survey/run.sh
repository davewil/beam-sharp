#!/bin/sh
# p07: how do real B# modules use foreign `using` blocks? (answers per-block vs per-module repeat cost)
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
cd "$(dirname "$0")"
ERL_LIBS=/tmp/otp/lib/elixir/lib escript survey.escript /home/user/beam-sharp
