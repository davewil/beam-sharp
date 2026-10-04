#!/bin/bash
# The subtree check trusts Self = the file's declared `module` atom. F15's path check is what makes that
# atom a directory subtree. Does a module in Acme/Evil that DECLARES itself Acme.Orders.Evil get in?
export PATH=/opt/otp28/bin:$PATH
HERE=$(cd "$(dirname "$0")" && pwd)
P=/tmp/c60a/_build/default/bin/bsc
rm -rf /tmp/t60e && cp -r "$HERE/tree" /tmp/t60e && cd /tmp/t60e
sed -i 's/^module Acme.Orders.Rules$/module Acme.Orders.Rules\nwithin Acme.Orders/' Acme/Orders/Rules/Rules.bs
mkdir -p Acme/Evil; cat > Acme/Evil/Evil.bs <<'EOT'
module Acme.Orders.Evil

using Acme.Orders.Rules

public int Go()
Go() -> Recompute([1])
EOT
echo "## with --src-root . (the normal way): declared Acme.Orders.Evil, sits in Acme/Evil"
$P -o /tmp/o60z --src-root . Acme/Evil Go; echo "exit=$?"
echo "## without --src-root (default root = the module directory's parent, Acme/):"
$P -o /tmp/o60z Acme/Evil Go; echo "exit=$?"
echo "## and through the in-process API with no path at all (bs_check:check/2 -- what a test or the REPL uses): is Self trusted?"
erl -noshell -pa /tmp/c60a/_build/default/lib/bsc/ebin -eval '
  Rules = element(2, bs_parser:parse(element(2, bs_lexer:string("module Acme.Orders.Rules\nwithin Acme.Orders\npublic int Recompute(int x)\nRecompute(x) -> x + 1\n")))),
  Entry = #{exports => bs_check:exports_of(Rules, #{}), private => #{}, behaviours => [], types => #{}, polys => #{}, within => bs_check:within_of(Rules)},
  World = #{'"'"'Acme.Orders.Rules'"'"' => Entry},
  Src = "module Acme.Orders.Evil\nusing Acme.Orders.Rules\npublic int Go()\nGo() -> Recompute(1)\n",
  Decls = element(2, bs_parser:parse(element(2, bs_lexer:string(Src)))),
  R = (catch bs_check:check(Decls, World)),
  io:format("check/2 on a pathless module declaring itself Acme.Orders.Evil -> ~P~n", [R, 8]),
  halt().' 2>&1 | head -8
