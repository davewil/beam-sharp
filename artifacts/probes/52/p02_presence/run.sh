#!/bin/sh
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
cd "$(dirname "$0")"
echo "######## 1. ERL_LIBS=elixir libs"; ERL_LIBS=/tmp/otp/lib/elixir/lib escript presence.escript
echo; echo "######## 2. ERL_LIBS unset"; env -u ERL_LIBS escript presence.escript
echo; echo "######## 3. module -> app directory, ERL_LIBS set"; ERL_LIBS=/tmp/otp/lib/elixir/lib escript mismatch.escript
echo; echo "######## 4. versioned dir (hex style: req-0.7.3/ebin) and bare -pa (no app dir)"
T=$(mktemp -d); mkdir -p $T/libs/eex-9.9.9/ebin $T/bare
cp /tmp/otp/lib/elixir/lib/eex/ebin/* $T/libs/eex-9.9.9/ebin/
cp /tmp/otp/lib/elixir/lib/elixir/ebin/* $T/bare/
cat > $T/ver.escript <<'X'
#!/usr/bin/env escript
main(_) -> io:format("versioned dir: lib_dir(eex)=~p which(EEx)=~p~n",[code:lib_dir(eex), code:which('Elixir.EEx')]).
X
ERL_LIBS=$T/libs escript $T/ver.escript
cat > $T/bare.escript <<'X'
#!/usr/bin/env escript
main(_) -> true = code:add_patha("BARE"), io:format("bare -pa: lib_dir(elixir)=~p which(String)=~p~n",[code:lib_dir(elixir), code:which('Elixir.String')]).
X
sed -i "s|BARE|$T/bare|" $T/bare.escript; env -u ERL_LIBS escript $T/bare.escript
