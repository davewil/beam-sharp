#!/usr/bin/env bash
# Can the Abstract Format carry a B# interval into the optimiser? Print the final asm of a/1,b/1,c/1 (OTP 25).
R=/home/user/beam-sharp/artifacts/39; O=$R/build/p8
cp $R/probes/p8_carry.erl $O/; erlc -S -o $O $O/p8_carry.erl
for f in a b c; do echo "=== $f/1 ==="; awk "/^\{function, $f, 1/,/^\{function, (a|b|c|wa|wb|wc|hit|module_info), /{print}" $O/p8_carry.S | grep -v line | head -30; done
echo "=== wb/1 (spec 0..99)  and wc/1 (guard) ==="; grep -n -A14 "^{function, wb" $O/p8_carry.S | grep -v line; grep -n -A18 "^{function, wc" $O/p8_carry.S | grep -v line
