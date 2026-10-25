#!/usr/bin/env bash
# P15: B# module atoms are PascalCase ('Peer'), OTP's are lowercase (peer). Exact-atom collision is impossible (P1: `module lists` is a syntax error),
# but on a case-insensitive filesystem Peer.beam IS peer.beam (F54:166-172 records ENG-391 and a boot failure). Which B# names in the corpus
# lowercase to an installed OTP 29 module? Also: the cost of the list a case-insensitive refusal would need.
S=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
cd /home/user/beam-sharp
find $S/beam/lib/erlang/lib -path '*/ebin/*.beam' -printf '%f\n' | sed 's/\.beam$//' | sort -u > /tmp/claude-0/otp_mods.txt 2>/dev/null || exit 1
OTP=$S/65/otp_mods.txt; mv /tmp/claude-0/otp_mods.txt $OTP
echo "OTP 29 modules in lib/*/ebin: $(wc -l < $OTP)"
grep -rhoE '^module [A-Za-z0-9_]+$' --include=*.bs --exclude-dir=_build compiler wayfinder | sed 's/module //' | sort -u > $S/65/bs_mods.txt
echo "distinct single-segment B# corpus module names: $(wc -l < $S/65/bs_mods.txt)"
echo "--- corpus names whose lowercase is an OTP module:"
while read m; do l=$(echo "$m" | tr 'A-Z' 'a-z'); grep -qx "$l" $OTP && echo "  $m -> $l"; done < $S/65/bs_mods.txt
echo "--- the planned roster (ticket 96) and the reserved four, lowercased, vs OTP:"
for m in List Map Term Float Enum String Int Process GenServer Supervisor Logger System Task Agent Binary Json Peer; do l=$(echo "$m" | tr 'A-Z' 'a-z'); grep -qx "$l" $OTP && echo "  $m -> $l is an OTP module" || echo "  $m -> $l (not an OTP module)"; done
