#!/usr/bin/env bash
# P2: which of the ticket's / sibling tickets' spellings parse TODAY.
# Expect: plain quoted-atom using accepted; attribute prefix refused; alias (ticket 106) refused (unbuilt);
# a deliberately bogus control (unknown keyword) refused for a different reason than the attribute.
. "$(dirname "$0")/../lib.sh"
probe PlainQuoted accepted 'using :'"'"'Elixir.Req'"'"' {
    term new(list<(atom, term)> opts)
}
public int F(int x)
F(x) -> x'
probe AttrApp refused '[external: elixir, app: req] using :'"'"'Elixir.Req'"'"' {
    term new(list<(atom, term)> opts)
}
public int F(int x)
F(x) -> x'
probe AttrOnly refused '[app: req] using :lists {
    int sum(list<int> xs)
}
public int F(int x)
F(x) -> x'
probe AliasT106 refused 'using :'"'"'Elixir.Req'"'"' {
    term GetOrCrash(binary url) = :'"'"'get!'"'"'
}
public int F(int x)
F(x) -> x'
probe AppKeyword refused 'using :'"'"'Elixir.Req'"'"' app req {
    term new(list<(atom, term)> opts)
}
public int F(int x)
F(x) -> x'
