%%% PROTOTYPE 25d — exemplar 4 of 6: database querying (PostgreSQL via epgsql).
%%%
%%% Throwaway. Ticket 25. This is the Erlang a beam-sharp `lib/shop/reports/`
%%% directory would lower to. Every claim in 25d-database-querying.md is
%%% produced by running this file; nothing there was reasoned about only on paper.
%%%
%%%   erlc 25d_db_lowering.erl && erl -noshell -s 25d_db_lowering main -s init stop
%%%
%%% SELF-CONTAINED ON PURPOSE. The result-set terms below are NOT hand-written:
%%% they were captured verbatim from a live PostgreSQL 16 through epgsql 4.7.1
%%% by 25d_live_capture.escript on 2026-08-24. The stub `equery/3` replays them
%%% so this file runs anywhere with no server; what a stub cannot do is be
%%% surprising, which is why the capture script exists and is the provenance
%%% for every shape here. The stub returns the full captured set for any
%%% select — row filtering is the server's business and not what this measures.
%%%
%%% The record tag prefix 'Shop.Reports' is a PLACEHOLDER: the exemplars'
%%% module names are an undecided question (ticket 25, F15 note), and this
%%% lowering needs *a* qualified name to mint tags from.
-module('25d_db_lowering').
-export([main/0]).

%%%===================================================================
%%% the captured wire — see 25d_live_capture.escript for provenance
%%%===================================================================

captured_rows() ->
    [{1,<<"ada">>,1999,<<"placed">>,null,<<"{\"gift\": true}">>},
     {2,<<"grace">>,125000,<<"shipped">>,{{2026,8,20},{9,30,0.0}},<<"{}">>},
     {3,<<"alan">>,0,<<"cancelled">>,null,<<"{\"reason\": \"test\"}">>}].
    %% total_legacy (numeric -> {unknown_oid,1700} -> <<"19.99">>) is deliberately
    %% not selected: money that is not integer cents does not cross. See write-up.

captured_columns() ->
    [{column,<<"id">>,int4,23,4,-1,1,16390,1},
     {column,<<"customer">>,text,25,-1,-1,1,16390,2},
     {column,<<"total_cents">>,int4,23,4,-1,1,16390,3},
     {column,<<"status">>,text,25,-1,-1,1,16390,5},
     {column,<<"shipped_at">>,timestamptz,1184,8,-1,1,16390,6},
     {column,<<"meta">>,jsonb,3802,-1,-1,1,16390,7}].

captured_pg_error() ->
    {error,error,<<"42P01">>,undefined_table,
     <<"relation \"no_such_table\" does not exist">>,
     [{file,<<"parse_relation.c">>},{line,<<"1449">>},{position,<<"16">>},
      {routine,<<"parserOpenTable">>},{severity,<<"ERROR">>}]}.

%% The stub: three canned behaviours keyed by the SQL verb, mirroring the
%% measured fact that equery's ok-shape depends on the verb.
equery(_Conn, "update " ++ _, _Params)  -> {ok, 1};
equery(_Conn, "broken " ++ _, _Params)  -> {error, captured_pg_error()};
equery(_Conn, "select " ++ _, _Params)  -> {ok, captured_columns(), captured_rows()}.

%%%===================================================================
%%% opts.bs / sql.bs
%%%===================================================================

config() ->
    [{host, "localhost"}, {port, 5499}, {username, "probe"},
     {password, "probe"}, {database, "shop"}, {timeout, 4000}].

%% Compose(OrderStatus, option<int>, option<string>) -> (string, list<term>)
%% Four clauses over presence; the SQL string near-duplicated in each — the
%% 2^k cost the write-up reports. Note $2 means min in one clause and customer
%% in the next: the placeholder numbering is per-arm.
-spec compose(atom(), integer() | nothing, binary() | nothing) -> {string(), [term()]}.
compose(S, nothing, nothing) ->
    {"select id, customer, total_cents, status, shipped_at, meta"
     " from orders where status = $1 order by id", [S]};
compose(S, nothing, C) ->
    {"select id, customer, total_cents, status, shipped_at, meta"
     " from orders where status = $1 and customer = $2 order by id", [S, C]};
compose(S, Min, nothing) ->
    {"select id, customer, total_cents, status, shipped_at, meta"
     " from orders where status = $1 and total_cents >= $2 order by id", [S, Min]};
compose(S, Min, C) ->
    {"select id, customer, total_cents, status, shipped_at, meta"
     " from orders where status = $1 and total_cents >= $2 and customer = $3 order by id",
     [S, Min, C]}.

%%%===================================================================
%%% fetch.bs — the seam, then the chain
%%%===================================================================

fetch(Conn, S, Min, Cust) ->
    {Sql, Params} = compose(S, Min, Cust),
    fetch_with(Conn, Sql, Params).

%% Split so main/0 can also drive the update/error SQL through the same seam.
fetch_with(Conn, Sql, Params) ->
    case equery(Conn, Sql, Params) of
        {error, E} -> {error, {pg, E}};          % wrap at the seam: |?> cannot rename
        Good       -> then(then(shaped(Good), fun checked/1), fun rowed/1)
    end.

%% The valve's lowering, exactly: stop on {error, _}, run the stage otherwise.
%% `good |> Shaped() |?> Checked() |?> Rowed()` is left-to-right sugar over this.
then({error, E}, _Stage) -> {error, E};
then(V, Stage)           -> Stage(V).

%%%===================================================================
%%% shape.bs — the count-clause tax, and ValidateAs<list<WireRow>>
%%%===================================================================

%% Shaped(QueryOk) — two clauses, exhaustive over the two ok shapes because the
%% seam's switch subtracted the error member (measured: 25d_surface_probe.sh §2).
shaped({ok, N})           -> {error, {not_rows, N}};
shaped({ok, _Cols, Rows}) -> Rows.
    %% _Cols carries the column names that would check WireRow's positional
    %% correspondence with the select list. Discarded — which is the finding.

%% Checked(term) -> ValidateAs<list<WireRow>>: the generated deep validator,
%% lowered by hand to the DESIGN's behaviour — the pathed error descends to the
%% component ("(2)"). Today's compiler stops at the row ("[1]"), which is
%% ticket 61, raised by this exemplar.
checked(Rows) when is_list(Rows) -> checked(Rows, 0, []);
checked(_)                       -> {error, {[], "list<(int, string, int, string, term, term)>"}}.

checked([], _I, Acc) -> lists:reverse(Acc);
checked([Row | Rest], I, Acc) ->
    case wire_row(Row) of
        ok           -> checked(Rest, I + 1, [Row | Acc]);
        {bad, Seg, Expected} ->
            {error, {[idx(I) | Seg], Expected}}
    end.

wire_row({Id, Cust, Cents, Status, _Shipped, _Meta}) ->
    first_bad([{1, is_integer(Id), "int"},
               {2, utf8(Cust), "string"},
               {3, is_integer(Cents), "int"},
               {4, utf8(Status), "string"}]);
wire_row(_) -> {bad, [], "(int, string, int, string, term, term)"}.

first_bad([])                            -> ok;
first_bad([{_N, true, _E} | Rest])       -> first_bad(Rest);
first_bad([{N, false, Expected} | _])    -> {bad, [component(N)], Expected}.

idx(I)       -> lists:flatten(io_lib:format("[~b]", [I])).
component(N) -> lists:flatten(io_lib:format("(~b)", [N])).

utf8(B) when is_binary(B) ->
    case unicode:characters_to_binary(B, utf8, utf8) of
        B -> true;
        _ -> false
    end;
utf8(_) -> false.

%%%===================================================================
%%% rows.bs — the hand-written traverse: three functions to map a
%%% fallible conversion over a list
%%%===================================================================

rowed([])           -> [];
rowed([W | Rest])   ->
    case build(W) of
        {error, E} -> {error, E};
        Row        -> prepend(Row, rowed(Rest))
    end.

build({Id, Cust, Cents, Status, Shipped, Meta}) ->
    case parse_status(Status) of
        {error, E} -> {error, E};
        S ->
            #{'Kind' => 'Shop.Reports.OrderRow',
              'Id' => Id, 'Customer' => Cust, 'TotalCents' => Cents,
              'Status' => S, 'ShippedAt' => shipped(Shipped), 'Meta' => Meta}
    end.

parse_status(<<"placed">>)    -> placed;
parse_status(<<"shipped">>)   -> shipped;
parse_status(<<"cancelled">>) -> cancelled;
parse_status(S)               -> {error, {unknown_status, S}}.

shipped(null) -> never;
shipped(V)    -> {at, V}.

prepend(_Row, {error, E}) -> {error, E};
prepend(Row, Rows)        -> [Row | Rows].

%%%===================================================================
%%% summary.bs — the group-by that needs no map, because the key is closed
%%%===================================================================

summarise(Rows) ->
    tally(Rows, #{'Kind' => 'Shop.Reports.Totals',
                  'Placed' => 0, 'Shipped' => 0, 'Cancelled' => 0}).

tally([], T)           -> T;
tally([R | Rest], T)   -> tally(Rest, add(T, R)).

add(T, #{'Status' := placed} = R) ->
    T#{'Placed' := maps:get('Placed', T) + maps:get('TotalCents', R)};
add(T, #{'Status' := shipped} = R) ->
    T#{'Shipped' := maps:get('Shipped', T) + maps:get('TotalCents', R)};
add(T, #{'Status' := cancelled} = R) ->
    T#{'Cancelled' := maps:get('Cancelled', T) + maps:get('TotalCents', R)}.

%%%===================================================================
%%% init.bs / handle_call.bs — the connection process, driven directly
%%%===================================================================

init(Opts) ->
    %% the stub cannot fail to connect; the live path is in the capture script
    {ok, {connected, Opts}}.

handle_call({by_status, S, Min, Cust}, _From, Conn) ->
    {reply, fetch(Conn, S, Min, Cust), Conn}.

%%%===================================================================
%%% main — every claim in the write-up, executed
%%%===================================================================

main() ->
    {ok, Conn} = init(config()),

    p("== the four compose arms (note $2 changes meaning between arms) =="),
    lists:foreach(fun({Min, Cust}) ->
                          {Sql, Ps} = compose(placed, Min, Cust),
                          p("  ~-28s <- ~s", [io_lib:format("~p", [Ps]),
                                              lists:sublist(Sql, 60, 999)])
                  end,
                  [{nothing, nothing}, {nothing, <<"ada">>},
                   {1000, nothing}, {1000, <<"ada">>}]),

    p("~n== clean fetch: captured rows -> records =="),
    {reply, Rows, Conn} = handle_call({by_status, placed, nothing, nothing}, self(), Conn),
    p("  ~b rows decoded; first: ~p", [length(Rows), hd(Rows)]),

    p("~n== null discipline: shipped_at across the three rows =="),
    lists:foreach(fun(R) -> p("  ~-10s -> ~p", [atom_to_list(maps:get('Status', R)),
                                                maps:get('ShippedAt', R)]) end, Rows),
    {at, {_, {_, _, Sec}}} = maps:get('ShippedAt', lists:nth(2, Rows)),
    p("  the timestamp's seconds field: ~p, is_float -> ~p  (B# cannot write this value)",
      [Sec, is_float(Sec)]),

    p("~n== summarise: the closed-key group-by =="),
    p("  ~p", [summarise(Rows)]),

    p("~n== error path: the captured undefined_table error, wrapped at the seam =="),
    p("  ~p", [fetch_with(Conn, "broken select", [])]),

    p("~n== count shape: an update through a select consumer =="),
    p("  ~p", [fetch_with(Conn, "update orders set total_cents = 0", [])]),

    p("~n== a row that validates but lies: unknown status =="),
    Bad1 = captured_rows() ++ [{4,<<"eve">>,1,<<"teleported">>,null,<<"{}">>}],
    p("  ~p", [then(checked(Bad1), fun rowed/1)]),

    p("~n== a row that does not validate: atom where customer text belongs =="),
    Bad2 = [hd(captured_rows()), {2,broken,1,<<"placed">>,null,<<"{}">>}],
    p("  ~p   (the design's path; today's compiler stops at [1] — ticket 61)",
      [checked(Bad2)]),

    p("~n== ValidateAs + build at result-set scale =="),
    N = 100000,
    Big = [{I, <<"c">>, I, <<"placed">>, null, <<"{}">>} || I <- lists:seq(1, N)],
    T0 = erlang:monotonic_time(microsecond),
    BigRows = then(checked(Big), fun rowed/1),
    T1 = erlang:monotonic_time(microsecond),
    p("  ~b rows validated + built in ~b ms (~p)",
      [N, (T1 - T0) div 1000, maps:get('Status', hd(BigRows))]),
    ok.

p(S)    -> io:format(S ++ "~n", []).
p(F, A) -> io:format(F ++ "~n", A).
