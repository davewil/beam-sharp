#!/usr/bin/env bash
# P1: on the BEAM, an exported function is callable by anyone who can compute its module atom.
set -e
D=$(mktemp -d); cd "$D"
cat > inner.erl <<'EOF'
-module(inner).
-export([secret/0]).
secret() -> secret_value.
EOF
cat > outer.erl <<'EOF'
-module(outer).
-export([go/0, go_computed/0]).
go() -> inner:secret().
%% module name built at run time from two binaries: no static edge to inner
go_computed() ->
    M = binary_to_atom(iolist_to_binary([<<"in">>, <<"ner">>])),
    apply(M, secret, []).
EOF
erlc inner.erl outer.erl
erl -noshell -eval 'io:format("static: ~p~ncomputed: ~p~n",[outer:go(), outer:go_computed()]), halt().'
echo "--- OTP release: $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')"
