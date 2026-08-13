%% PROTOTYPE 25a — throwaway. The Erlang that the HTTP API exemplar lowers to.
%%
%% Ticket 25's second requirement: a lowering that COMPILES AND RUNS. Written to
%% falsify claims the beam-sharp source can only assert:
%%
%%   - routing as multi-clause dispatch on method + path   -> ticket 08
%%   - a JSON document as a structural, open, recursive type -> ticket 09
%%   - json:decode's term validated by ValidateAs<T>       -> ticket 11
%%   - records erasing to TAGGED MAPS                      -> ticket 26 §1
%%   - request validation as a condition ladder            -> ticket 17 job 1
%%   - closed vs open residual on the route union          -> ticket 12 §2
%%
%% Run: erlc 25a_http_lowering.erl && erl -noshell -pa . -s '25a_http_lowering' demo -s init stop

-module('25a_http_lowering').
-export([route/3, validate_create_order/1, encode_response/1, demo/0]).

%% ---------------------------------------------------------------------------
%% 0. What a record erases to — ticket 26 §1
%% ---------------------------------------------------------------------------
%%
%%   record Order { Id: string, Total: int, Status: Status }
%%
%% desugars to a type whose field set carries a tag minted from the QUALIFIED
%% name (map.md's fifth consumer of the naming fog: a short name would unify
%% Shop.Orders.Order with Billing.Invoices.Order).
%%
%%   #{kind => 'Shop.Orders.Order', id => ..., total => ..., status => ...}
%%
%% The discriminator is one map_get/2, which fails a guard silently on an
%% absent key — so `is_order(X)` needs no is_map and no per-field test.

-define(ORDER_TAG, 'Shop.Orders.Order').

is_order(X) when map_get(kind, X) =:= ?ORDER_TAG -> true;
is_order(_) -> false.

mk_order(Id, Total, Status) ->
    #{kind => ?ORDER_TAG, id => Id, total => Total, status => Status}.

%% ---------------------------------------------------------------------------
%% 1. Routing — multi-clause dispatch on method and path
%% ---------------------------------------------------------------------------
%%
%% THE FINDING: the route table is the shape beam-sharp is best at, and it is
%% ALSO the shape where the residual is most awkward. A path is list<string>,
%% whose residual after any finite set of literal patterns is INFINITE and open.
%% So ticket 12 permits `_` here — but it permits it for a reason that has
%% nothing to do with routing being open-ended in the author's mind.

route(get,  [<<"orders">>], _Body) ->
    {200, [mk_order(<<"o1">>, 1250, placed)]};

route(get,  [<<"orders">>, Id], _Body) ->
    case lookup(Id) of
        {ok, O}   -> {200, O};
        not_found -> {404, #{error => <<"no such order">>}}
    end;

route(post, [<<"orders">>], Body) ->
    %% The boundary: a term from outside becomes a typed value or a reason.
    case validate_create_order(Body) of
        {ok, Cmd}      -> {201, mk_order(maps:get(id, Cmd), maps:get(total, Cmd), draft)};
        {error, Where} -> {422, #{error => <<"invalid">>, at => Where}}
    end;

route(delete, [<<"orders">>, Id], _Body) ->
    case lookup(Id) of
        {ok, _}   -> {204, no_content};
        not_found -> {404, #{error => <<"no such order">>}}
    end;

%% The boundary clause. Residual is OPEN (method is an atom top, path is an
%% unbounded list<string>), so `_` is legal per ticket 12 §2.
route(_Method, _Path, _Body) ->
    {404, #{error => <<"no route">>}}.

lookup(<<"o1">>) -> {ok, mk_order(<<"o1">>, 1250, placed)};
lookup(_)        -> not_found.

%% ---------------------------------------------------------------------------
%% 2. ValidateAs<CreateOrder> — the generated deep structural check
%% ---------------------------------------------------------------------------
%%
%% Ticket 11: patterns over a `term` are O(1) guard-decidable ONLY; deep
%% validation is an explicit call to a GENERATED ValidateAs<T> returning
%% result<T, ValidationError>. This is what the compiler would emit for
%%
%%   record CreateOrder { Id: string, Total: int, Lines: list<Line> }
%%   record Line { Sku: string, Qty: int }
%%
%% ValidationError is "a path into the offending term plus the type expected
%% there" (CONTEXT.md). Note it is written by hand here at ~40 lines for TWO
%% record types — the cost the map says is unmeasured.

validate_create_order(T) when is_map(T) ->
    with_field(T, <<"id">>, fun is_utf8/1, [id],
      fun(Id) ->
        with_field(T, <<"total">>, fun erlang:is_integer/1, [total],
          fun(Total) ->
            with_field(T, <<"lines">>, fun erlang:is_list/1, [lines],
              fun(Lines) ->
                case validate_lines(Lines, 0, []) of
                    {ok, Ls}       -> {ok, #{id => Id, total => Total, lines => Ls}};
                    {error, Where} -> {error, Where}
                end
              end)
          end)
      end);
validate_create_order(_) ->
    {error, {[], map}}.

with_field(T, Key, Pred, Path, K) ->
    case maps:find(Key, T) of
        error      -> {error, {Path, missing}};
        {ok, V}    -> case Pred(V) of
                          true  -> K(V);
                          false -> {error, {Path, wrong_type}}
                      end
    end.

validate_lines([], _I, Acc) ->
    {ok, lists:reverse(Acc)};
validate_lines([L | Rest], I, Acc) when is_map(L) ->
    case {maps:find(<<"sku">>, L), maps:find(<<"qty">>, L)} of
        {{ok, S}, {ok, Q}} when is_binary(S), is_integer(Q) ->
            validate_lines(Rest, I + 1, [#{sku => S, qty => Q} | Acc]);
        _ ->
            {error, {[lines, I], line}}
    end;
validate_lines([_ | _], I, _Acc) ->
    {error, {[lines, I], map}}.

%% ticket 20: `string` is `binary` refined by valid UTF-8 — an OPAQUE
%% refinement, O(n), established by generated code where a value enters.
is_utf8(B) when is_binary(B) -> unicode:characters_to_binary(B) =:= B;
is_utf8(_) -> false.

%% ---------------------------------------------------------------------------
%% 3. The condition ladder — ticket 17 job 1
%% ---------------------------------------------------------------------------
%%
%% 17 §6 made `switch` the only branching construct, with a TUPLE SUBJECT for
%% compound conditions, and asked whether a ladder of unrelated conditions
%% actually occurs and at what width. Request admission control is the site.
%% This is FIVE unrelated booleans, written as 17 would have to write it.

admit(Req) ->
    Authed   = maps:get(authed,   Req, false),
    Verified = maps:get(verified, Req, false),
    Quota    = maps:get(quota,    Req, 0) > 0,
    Size     = maps:get(size,     Req, 0) =< 1048576,
    Beta     = maps:get(beta,     Req, false),
    case {Authed, Verified, Quota, Size, Beta} of
        {false, _,     _,     _,     _}     -> {401, unauthenticated};
        {_,     false, _,     _,     _}     -> {403, unverified};
        {_,     _,     false, _,     _}     -> {429, quota_exceeded};
        {_,     _,     _,     false, _}     -> {413, too_large};
        {_,     _,     _,     _,     false} -> {404, not_in_beta};
        {true,  true,  true,  true,  true}  -> {200, ok}
    end.

%% ---------------------------------------------------------------------------
%% 4. JSON out — ticket 16 §4's serialisation obligation
%% ---------------------------------------------------------------------------
%%
%% json:encode/1 REFUSES TUPLES AT ANY DEPTH, at runtime (ticket 16 §4, 20 §4).
%% Every beam-sharp construct that erases to a tuple — result's (:error, E),
%% ticket 09's newtype tag — is therefore unencodable without a mapping.

encode_response({Status, no_content}) ->
    {Status, <<>>};
encode_response({Status, Body}) ->
    {Status, iolist_to_binary(json:encode(strip_tags(Body)))}.

%% The published mapping has to strip the minted tag, or every record on the
%% wire carries an internal name. THIS IS A FINDING: ticket 26's tag is data in
%% the term, so it reaches the serialiser like any other field.
strip_tags(M) when is_map(M) ->
    maps:from_list([{atom_or_bin(K), strip_tags(V)}
                    || {K, V} <- maps:to_list(M), K =/= kind]);
strip_tags(L) when is_list(L) -> [strip_tags(X) || X <- L];
strip_tags(A) when is_atom(A) -> atom_to_binary(A);
strip_tags(X) -> X.

atom_or_bin(K) when is_atom(K) -> atom_to_binary(K);
atom_or_bin(K) -> K.

%% ---------------------------------------------------------------------------
%% 5. Demo
%% ---------------------------------------------------------------------------

demo() ->
    io:format("~n== 25a: HTTP API server ==~n~n"),

    io:format("GET  /orders       -> ~p~n", [element(1, route(get, [<<"orders">>], none))]),
    io:format("GET  /orders/o1    -> ~p~n", [route(get, [<<"orders">>, <<"o1">>], none)]),
    io:format("GET  /orders/zz    -> ~p~n", [element(1, route(get, [<<"orders">>, <<"zz">>], none))]),
    io:format("PATCH /orders      -> ~p~n", [element(1, route(patch, [<<"orders">>], none))]),

    %% The record discriminator, ticket 26
    O = mk_order(<<"o1">>, 1250, placed),
    io:format("is_order(order)    -> ~p~n", [is_order(O)]),
    io:format("is_order(bare map) -> ~p~n", [is_order(#{id => <<"o1">>})]),
    io:format("is_order(non-map)  -> ~p~n", [is_order(42)]),

    %% JSON in — the boundary
    Good = json:decode(<<"{\"id\":\"o9\",\"total\":500,",
                         "\"lines\":[{\"sku\":\"a\",\"qty\":2}]}">>),
    io:format("validate good      -> ~p~n", [validate_create_order(Good)]),

    Bad1 = json:decode(<<"{\"id\":\"o9\",\"total\":\"lots\",\"lines\":[]}">>),
    io:format("validate bad total -> ~p~n", [validate_create_order(Bad1)]),

    Bad2 = json:decode(<<"{\"id\":\"o9\",\"total\":5,\"lines\":[{\"sku\":\"a\"}]}">>),
    io:format("validate bad line  -> ~p~n", [validate_create_order(Bad2)]),

    Bad3 = json:decode(<<"{\"total\":5,\"lines\":[]}">>),
    io:format("validate missing   -> ~p~n", [validate_create_order(Bad3)]),

    io:format("POST /orders good  -> ~p~n", [element(1, route(post, [<<"orders">>], Good))]),
    io:format("POST /orders bad   -> ~p~n", [route(post, [<<"orders">>], Bad2)]),

    %% The condition ladder, ticket 17 job 1
    io:format("admit all-true     -> ~p~n", [admit(#{authed => true, verified => true,
                                                     quota => 5, size => 10, beta => true})]),
    io:format("admit unverified   -> ~p~n", [admit(#{authed => true, verified => false,
                                                     quota => 5, size => 10, beta => true})]),

    %% JSON out
    io:format("encode order       -> ~p~n", [encode_response({200, O})]),
    io:format("encode 204         -> ~p~n", [encode_response({204, no_content})]),

    %% json:encode REFUSES a tuple — ticket 16 §4, at runtime
    Tup = (catch json:encode({error, nope})),
    io:format("encode a tuple     -> ~p~n", [element(1, Tup)]),

    %% ------------------------------------------------------------------
    %% THE FINDING THIS EXEMPLAR EXISTS FOR.
    %% A 422 response body carries a ValidationError. CONTEXT.md says that is
    %% "a tuple today". json:encode refuses tuples at any depth. So the error
    %% response of the language's own boundary check is UNENCODABLE — and it
    %% fails at runtime, on the error path, which is the path least likely to
    %% be exercised before shipping.
    %% ------------------------------------------------------------------
    R422 = route(post, [<<"orders">>], Bad2),
    io:format("~n422 response term  -> ~p~n", [R422]),
    io:format("encode 422         -> ~p~n", [encode_or_reason(R422)]),

    %% And the same shape one level down: result's (:error, E) is a tuple too.
    io:format("encode result err  -> ~p~n",
              [encode_or_reason({200, #{outcome => {error, underpaid}}})]),

    ok.

encode_or_reason(R) ->
    try encode_response(R)
    catch C:E -> {crashed, C, element(1, E)}
    end.
