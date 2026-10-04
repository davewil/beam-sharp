#!/bin/sh
# Per-block vs per-module: where does a foreign `using` block live today, and does it reach sibling files?
# A module is a directory; index.bs holds shared declarations; each function has its own file.
. "$(dirname "$0")/env.sh"
export ERL_LIBS=$W/greeter_build/dev/lib
rm -rf $W/multi && mkdir -p $W/multi/Hello && cd $W/multi
cat > Hello/index.bs <<'B'
module Hello

using :'Elixir.Greeter' {
    binary hello(binary name)
}

using :'Elixir.Greeter.Extra' {
    binary shout(binary name)
}
B
cat > Hello/hi.bs <<'B'
public binary Hi(binary n)

Hi(n) -> :'Elixir.Greeter'.hello(n)
B
cat > Hello/yell.bs <<'B'
public binary Yell(binary n)

Yell(n) -> :'Elixir.Greeter.Extra'.shout(n)
B
echo "== A: both blocks in index.bs, used from two sibling files"
$BSC -o out Hello Hi '"bob"'; $BSC -o out Hello Yell '"bob"'
echo "== B: the Extra block moved into yell.bs (a function file); does hi.bs see it? does yell.bs need it in index?"
rm -rf $W/multi2 && cp -r $W/multi $W/multi2 && cd $W/multi2
cat > Hello/index.bs <<'B'
module Hello

using :'Elixir.Greeter' {
    binary hello(binary name)
}
B
cat > Hello/yell.bs <<'B'
using :'Elixir.Greeter.Extra' {
    binary shout(binary name)
}

public binary Yell(binary n)

Yell(n) -> :'Elixir.Greeter.Extra'.shout(n)
B
cat > Hello/hi.bs <<'B'
public binary Hi(binary n)

Hi(n) -> :'Elixir.Greeter.Extra'.shout(n)
B
$BSC -o out Hello Yell '"bob"' 2>&1 | head -8; $BSC -o out Hello Hi '"bob"' 2>&1 | head -8
echo "== C: the double-quoted atom spelling LANGUAGE.md says is 'not lexed yet'"
rm -rf $W/multi3 && mkdir -p $W/multi3/H3 && cd $W/multi3
cat > H3/h.bs <<'B'
module H3

using :"Elixir.Greeter" {
    binary hello(binary name)
}

public binary Hi(binary n)

Hi(n) -> :"Elixir.Greeter".hello(n)
B
$BSC -o out H3 Hi '"bob"' 2>&1 | head -4
