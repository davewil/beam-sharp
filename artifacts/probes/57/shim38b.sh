#!/usr/bin/env bash
# shim38b.sh EBIN -- the repo's 38b probe, REVISED ONLY in how it finds the compiler.
# Original (wayfinder/prototypes/38b_divisor_expressiveness.sh) needs
# compiler/_build/default/bin/bsc built by rebar3, which is broken on OTP 29 here, so it
# exits silently at the build step (see 38b_as_is.out).  This copy swaps two lines:
#   bsc=...   -> the hand-built bsc via bsc.sh   |   `erl -pa ...ebin` -> the hand-built ebin
# Every probe case and every expected value is untouched.
here=$(cd "$(dirname "$0")" && pwd); ebin=$1
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/wayfinder/prototypes"
printf '#!/bin/sh\nexec %s %s "$@"\n' "$here/bsc.sh" "$ebin" > "$tmp/bscw"; chmod +x "$tmp/bscw"
sed -e "s#^bsc=.*#bsc=$tmp/bscw#" \
    -e 's#^if \[ ! -x "\$bsc" \]; then#if false; then#' \
    -e "s#-pa \"\$root/compiler/_build/default/lib/bsc/ebin\"#-pa $ebin#" \
    /home/user/beam-sharp/wayfinder/prototypes/38b_divisor_expressiveness.sh > "$tmp/wayfinder/prototypes/38b.sh"
PATH=/tmp/otp/bin:$PATH bash "$tmp/wayfinder/prototypes/38b.sh"
