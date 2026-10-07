#!/usr/bin/env bash
# Variant A: parser folds a negated INT literal exactly as it already folds a negated float literal.
f="$1/src/bs_parser.yrl"
python3 - "$f" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
s=s.replace("negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};",
 "negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};\nnegate(_L, {e_int, IL, N})   -> {e_int, IL, -N};")
open(p,'w').write(s)
PY
