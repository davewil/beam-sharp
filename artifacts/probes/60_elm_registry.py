#!/usr/bin/env python3
"""Writes ELM_HOME/0.19.2/packages/registry.dat for an OFFLINE registry (package.elm-lang.org is blocked here).
Format reverse-engineered by trial (u8-length Utf8 names, 3-byte versions, big-endian Int64 counts); the run in
60_elm.sh is what proves it is accepted (elm proceeds past the registry read). usage: 60_elm_registry.py ELM_HOME author/pkg@x.y.z ..."""
import struct, sys
home = sys.argv[1]
pk = []
for a in sys.argv[2:]:
    n, v = a.split('@'); au, pr = n.split('/'); pk.append((au, pr, tuple(int(x) for x in v.split('.'))))
u8 = lambda s: bytes([len(s.encode())]) + s.encode()
out = struct.pack('>q', len(pk)) + struct.pack('>q', len(pk))
for au, pr, v in sorted(pk):
    out += u8(au) + u8(pr) + bytes(v) + struct.pack('>q', 0)
open(f"{home}/0.19.2/packages/registry.dat", 'wb').write(out)
