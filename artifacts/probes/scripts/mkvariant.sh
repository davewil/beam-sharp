#!/bin/sh
# mkvariant.sh NAME : copy pristine-built scratch compiler (bsc/) into NAME/ for patching
S=$(cd "$(dirname "$0")" && pwd); rm -rf $S/$1; mkdir -p $S/$1; cp -r $S/bsc/src $S/bsc/ebin $S/bsc/bsc.sh $S/$1/
