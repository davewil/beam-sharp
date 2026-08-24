#!/usr/bin/env escript
%%! -pa _build/default/lib/epgsql/ebin
%% PROTOTYPE 25d — capture what epgsql actually hands back, verbatim.
%%
%% Throwaway. Ticket 25, exemplar 4. This is the provenance for every wire-shape
%% claim in 25d-database-querying.md: the terms in 25d_db_lowering.erl were
%% captured by THIS script from a live PostgreSQL 16 through epgsql 4.7.1, not
%% written by hand. Run 2026-08-24 on OTP 28; the transcript is inline below.
%%
%% To reproduce (none of this is wired into any gate):
%%
%%   docker run -d --name bs25d-pg -e POSTGRES_PASSWORD=probe -e POSTGRES_USER=probe \
%%     -e POSTGRES_DB=shop -p 5499:5432 postgres:16-alpine
%%   mkdir epgsql_probe && cd epgsql_probe
%%   printf '{deps, [{epgsql, "4.7.1"}]}.\n' > rebar.config
%%   mkdir src && printf '{application, epgsql_probe, [{vsn, "0.1.0"},
%%     {applications, [kernel, stdlib]}]}.\n' > src/epgsql_probe.app.src
%%   rebar3 compile
%%   escript path/to/25d_live_capture.escript
%%
%% THE CAPTURED TRANSCRIPT (2026-08-24), abridged to the shapes that matter.
%% Every claim below was also re-run and printed by this script.
%%
%% equery select over all seven columns:
%%   {ok,[{column,<<"id">>,int4,23,4,-1,1,16390,1},
%%        {column,<<"customer">>,text,25,-1,-1,1,16390,2},
%%        {column,<<"total_cents">>,int4,23,4,-1,1,16390,3},
%%        {column,<<"total_legacy">>,{unknown_oid,1700},1700,-1,655366,0,16390,4},
%%        {column,<<"status">>,text,25,-1,-1,1,16390,5},
%%        {column,<<"shipped_at">>,timestamptz,1184,8,-1,1,16390,6},
%%        {column,<<"meta">>,jsonb,3802,-1,-1,1,16390,7}],
%%       [{1,<<"ada">>,1999,<<"19.99">>,<<"placed">>,null,<<"{\"gift\": true}">>},
%%        {2,<<"grace">>,125000,<<"1250.00">>,<<"shipped">>,
%%         {{2026,8,20},{9,30,0.0}},                          %% <- seconds is a FLOAT
%%         <<"{}">>},
%%        {3,<<"alan">>,0,<<"0.00">>,<<"cancelled">>,null,<<"{\"reason\": \"test\"}">>}]}
%%
%%   - numeric(10,2) column: epgsql types it {unknown_oid,1700}, value is TEXT (<<"19.99">>)
%%   - timestamptz: {{Y,M,D},{H,Min,S}} with S a float (0.0)
%%   - SQL NULL: the atom 'null'
%%   - jsonb: {"gift":true} went in, {"gift": true} came back — the server re-encodes
%%
%% equery for an UPDATE returns a DIFFERENT ok shape from a select:
%%   {ok,1}
%%
%% a failed query returns epgsql's #error{} record — its record tag is ALSO 'error',
%% and the last field is a proplist whose keys vary by error class:
%%   {error,{error,error,<<"42P01">>,undefined_table,
%%           <<"relation \"no_such_table\" does not exist">>,
%%           [{file,<<"parse_relation.c">>},...]}}
%%   {error,{error,error,<<"23514">>,check_violation,
%%           <<"new row for relation \"orders\" violates check constraint ...">>,
%%           [{constraint_name,<<"orders_status_check">>},{detail,<<"...">>},...]}}
%%
%% follow-ups that decided exemplar spellings:
%%   - connect/1 and connect/4 both accept a PROPLIST (a map is not required) -> opts.bs
%%   - an atom crosses as a text parameter: equery(C, "... status = $1", [placed]) matched
%%     the row whose status text is <<"placed">> -> sql.bs sends the status atom raw

main(_) ->
    Opts = [{host, "localhost"}, {port, 5499}, {username, "probe"},
            {password, "probe"}, {database, "shop"}, {timeout, 4000}],
    C = connect_retry(Opts, 20),

    {ok, [], []} = epgsql:squery(C, "drop table if exists orders"),
    {ok, [], []} = epgsql:squery(C,
        "create table orders ("
        " id serial primary key,"
        " customer text not null,"
        " total_cents int4 not null,"
        " total_legacy numeric(10,2) not null,"
        " status text not null check (status in ('placed','shipped','cancelled')),"
        " shipped_at timestamptz null,"
        " meta jsonb not null default '{}')"),

    Ins = "insert into orders (customer, total_cents, total_legacy, status, shipped_at, meta)"
          " values ($1, $2, $3, $4, $5, $6)",
    {ok, 1} = epgsql:equery(C, Ins, [<<"ada">>, 1999, <<"19.99">>, <<"placed">>, null,
                                     <<"{\"gift\":true}">>]),
    {ok, 1} = epgsql:equery(C, Ins, [<<"grace">>, 125000, <<"1250.00">>, <<"shipped">>,
                                     {{2026,8,20},{9,30,0.0}}, <<"{}">>]),
    {ok, 1} = epgsql:equery(C, Ins, [<<"alan">>, 0, <<"0.00">>, <<"cancelled">>, null,
                                     <<"{\"reason\":\"test\"}">>]),

    io:format("== equery select ==~n~p~n~n",
              [epgsql:equery(C, "select id, customer, total_cents, total_legacy, status,"
                                " shipped_at, meta from orders order by id", [])]),
    io:format("== atom as a text parameter ==~n~p~n~n",
              [epgsql:equery(C, "select id from orders where status = $1", [placed])]),
    io:format("== update: the count shape ==~n~p~n~n",
              [epgsql:equery(C, "update orders set total_cents = total_cents + 1"
                                " where status = $1", [<<"placed">>])]),
    io:format("== undefined table ==~n~p~n~n",
              [epgsql:equery(C, "select id from no_such_table", [])]),
    io:format("== check violation ==~n~p~n~n",
              [epgsql:equery(C, Ins, [<<"eve">>, 1, <<"0.01">>, <<"teleported">>, null,
                                      <<"{}">>])]),
    ok = epgsql:close(C).

connect_retry(_Opts, 0) -> halt(1);
connect_retry(Opts, N) ->
    case epgsql:connect(Opts) of
        {ok, C} -> C;
        {error, _} -> timer:sleep(500), connect_retry(Opts, N - 1)
    end.
