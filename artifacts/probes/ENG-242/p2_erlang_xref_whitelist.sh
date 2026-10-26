#!/usr/bin/env bash
# P2: xref can implement a caller-whitelist ("only modules under prefix may call inner") and
# what it cannot see (computed-module apply) is reported as unresolved. Counts lines and time.
set -e
D=$(mktemp -d); cd "$D"
mkdir ebin
cat > shop_orders_inner.erl <<'EOF'
-module(shop_orders_inner).
-export([recompute/1]).
recompute(X) -> X + 1.
EOF
cat > shop_orders.erl <<'EOF'
-module(shop_orders).
-export([total/1]).
total(X) -> shop_orders_inner:recompute(X).
EOF
cat > shop_billing.erl <<'EOF'
-module(shop_billing).
-export([bill/1, sneaky/1]).
bill(X) -> shop_orders_inner:recompute(X).
sneaky(X) -> M = list_to_atom("shop_orders_" ++ "inner"), M:recompute(X).
EOF
erlc +debug_info -o ebin *.erl
cat > check.escript <<'EOF'
#!/usr/bin/env escript
main([Dir]) ->
    {ok, _} = xref:start(s),
    xref:set_default(s, [{verbose,false},{warnings,false}]),
    {ok, _} = xref:add_directory(s, Dir),
    %% rule: callee shop_orders_inner may only be called from shop_orders (+ itself)
    Allowed = [shop_orders, shop_orders_inner],
    {ok, Edges} = xref:q(s, "E"),
    Bad = [{C, Callee} || {{CM,_,_}=C, {shop_orders_inner,_,_}=Callee} <- Edges,
                          not lists:member(CM, Allowed)],
    {ok, Unres} = xref:q(s, "UC"),
    io:format("violations: ~p~nunresolved (escape the check): ~p~n", [Bad, Unres]).
EOF
echo "check.escript non-comment lines: $(grep -c -v '^\s*%' check.escript)"
time escript check.escript ebin
