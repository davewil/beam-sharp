#!/bin/bash
# (b) What the checker has in hand at add_module_import, on an INSTRUMENTED COPY (/tmp/c60i):
#     two io:format lines added, nothing else changed (diff printed below).
export PATH=/opt/otp28/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
BSC=/tmp/c60i/_build/default/bin/bsc
cd "$HERE/tree"
echo "## the layout on disk (F15: a directory is a module; module name == dir path under --src-root)"
find Acme -type f | sort
echo
echo "## instrumentation diff vs. HEAD"
diff -u /home/user/beam-sharp/compiler/src/bs_check.erl /tmp/c60i/src/bs_check.erl | grep '^[+-][^+-]'
echo
echo "## compile Acme.Billing (uses Acme.Orders and Acme.Orders.Rules)"
$BSC -o /tmp/o60c --src-root . Acme/Billing Invoice "[1,2,3]" 2>&1
echo
echo "## compile Acme.Orders only (uses its own child Acme.Orders.Rules)"
$BSC -o /tmp/o60d --src-root . Acme/Orders Total "[1,2]" 2>&1
