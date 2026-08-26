%%% PROTOTYPE 25e — exemplar 5 of 6: a dynamic web page (server-rendered HTML).
%%%
%%% Throwaway. Ticket 25. This is the Erlang a beam-sharp `lib/shop/page/`
%%% directory would lower to. Every claim in 25e-dynamic-web-page.md is
%%% produced by running this file; nothing there was reasoned about only on paper.
%%%
%%%   erlc 25e_page_lowering.erl && erl -noshell -s '25e_page_lowering' main -s init stop
%%%
%%% WHY THE OUTPUT IS PARSED AND NOT PRINTED.
%%% The exemplar's central claim is about HTML ESCAPING, and an escaping failure
%%% is exactly the kind of thing a reader skims past — `<script>` in a page looks
%%% like markup whether it was meant as markup or not. So the check here is
%%% `xmerl_scan` (in OTP, no dependency): the rendered page is parsed as XML and
%%% the injected payload is located in the resulting tree. If the escaper leaked,
%%% the payload appears as an ELEMENT rather than as TEXT, and the assertion is
%%% red. It is the 25d move — evidence from something that can be surprised —
%%% applied to a program whose output is a document.
%%%
%%% The record tag prefix 'Shop.Page' is this exemplar's declared module; 25e is
%%% the first of the six to declare one (see the write-up's §"The layout").
-module('25e_page_lowering').
-export([main/0]).

-include_lib("xmerl/include/xmerl.hrl").

%%%===================================================================
%%% the model — `record OrderRow` and `record PageModel` lowered
%%%
%%% A B# record lowers to a map with a minted tag under the module's
%%% qualified name (ticket 26 §1, F3). Nothing here is a tuple: the tag
%%% is a field, so two records with the same shape stay distinct.
%%%===================================================================

order_row(Id, Customer, TotalCents, Status) ->
    #{'__tag__' => 'Shop.Page.OrderRow',
      'Id' => Id, 'Customer' => Customer,
      'TotalCents' => TotalCents, 'Status' => Status}.

%%% The page this exemplar renders. `ada` and `grace` are ordinary; the third
%%% customer name is an INJECTION PAYLOAD and it is the whole point of the file.
model() ->
    #{'__tag__' => 'Shop.Page.PageModel',
      'Title'   => <<"Orders">>,
      'Orders'  => [order_row(1, <<"ada">>,   1999, placed),
                    order_row(2, <<"grace">>, 125000, shipped),
                    %% The hard case, chosen on purpose: a name that is markup,
                    %% carrying a quote so the attribute escape is exercised too.
                    order_row(3, <<"<script>alert(\"xss\")</script>">>, 5, cancelled)],
      'Note'    => <<"ends & begins">>,   %% option<string>, the `T` arm
      'IsAdmin' => true}.

%%% The same model with no note — `option<string>`'s `:nothing` arm. B#'s
%%% `option<T>` is `T | :nothing` UNTAGGED (measured), so the absent case is the
%%% bare atom and there is no `{some, _}` wrapper anywhere in this lowering.
model_without_note() ->
    (model())#{'Note' => nothing}.

%%%===================================================================
%%% escape.bs
%%%
%%% Two escapers, because the difference between them IS finding 3.
%%%===================================================================

%%% THE ONE THE EXEMPLAR SHIPS. `escape_correct/1` mirrors the B# `Escape/1`
%%% exactly, including the foreign call: `binary:encode_unsigned(C)` is the only
%%% way B# can turn a matched byte back into a one-byte binary, because binary
%%% CONSTRUCTION in expression position does not exist.
%%%
%%% In Erlang this is of course just `<<C>>`, and writing the FFI call here
%%% instead is deliberate — the lowering is meant to be what B# would emit, not
%%% what an Erlang programmer would write. The cost being measured is one
%%% function call per ordinary character.
escape_correct(S) -> escape_correct(S, []).

escape_correct(<<>>, Acc)          -> lists:reverse(Acc);
escape_correct(<<16#26, R/binary>>, Acc) -> escape_correct(R, [<<"&amp;">>  | Acc]);
escape_correct(<<16#3C, R/binary>>, Acc) -> escape_correct(R, [<<"&lt;">>   | Acc]);
escape_correct(<<16#3E, R/binary>>, Acc) -> escape_correct(R, [<<"&gt;">>   | Acc]);
escape_correct(<<16#22, R/binary>>, Acc) -> escape_correct(R, [<<"&quot;">> | Acc]);
escape_correct(<<C,    R/binary>>, Acc) ->
    escape_correct(R, [binary:encode_unsigned(C) | Acc]);
escape_correct(_, Acc)             -> lists:reverse(Acc).

%%% THE ONE THAT TYPE-CHECKS AND IS WRONG. Without the foreign call there is
%%% nowhere for `C` to go, and the obvious thing is to drop it. This compiles in
%%% B#, runs, and silently deletes every character it was not asked to escape.
%%% It is here so the write-up's claim is demonstrated rather than asserted.
escape_dropping(S) -> escape_dropping(S, []).

escape_dropping(<<>>, Acc)          -> lists:reverse(Acc);
escape_dropping(<<16#26, R/binary>>, Acc) -> escape_dropping(R, [<<"&amp;">>  | Acc]);
escape_dropping(<<16#3C, R/binary>>, Acc) -> escape_dropping(R, [<<"&lt;">>   | Acc]);
escape_dropping(<<16#3E, R/binary>>, Acc) -> escape_dropping(R, [<<"&gt;">>   | Acc]);
escape_dropping(<<16#22, R/binary>>, Acc) -> escape_dropping(R, [<<"&quot;">> | Acc]);
escape_dropping(<<_,    R/binary>>, Acc) -> escape_dropping(R, Acc);
escape_dropping(_, Acc)             -> lists:reverse(Acc).

%%% THE NEGATIVE CONTROL, and check 2 is worth nothing without it.
%%%
%%% Check 2 asserts an ABSENCE — no `script` element in the parsed page — and an
%%% absence assertion passes just as happily over a page that was never rendered,
%%% a parser that found nothing, or a search that looks in the wrong place. This
%%% escaper leaks by construction, so the control can require the check to go RED
%%% over it. Both halves: a check that fires on everything is as useless as one
%%% that fires on nothing.
escape_leaking(S) -> [S].

%%%===================================================================
%%% rows.bs
%%%===================================================================

%%% The escaper is a PARAMETER here only so the negative control can swap it.
%%% In the B# source it is an ordinary call to `Escape` — the language has no
%%% lambda (25b's wall) and could not pass one.
rows([], _Esc, Acc)         -> lists:reverse(Acc);
rows([O | Rest], Esc, Acc)  -> rows(Rest, Esc, [row(O, Esc) | Acc]).

row(#{'Id' := Id, 'Customer' := Cust,
      'TotalCents' := Cents, 'Status' := Status}, Esc) ->
    [<<"<tr><td>">>, integer_to_binary(Id),
     <<"</td><td>">>, Esc(Cust),
     <<"</td><td>">>, money(Cents),
     <<"</td><td>">>, status(Status),
     <<"</td></tr>">>].

%%% F26's `/` and `%`. The B# source says `cents / 100` and `cents % 100`; both
%%% lower to the integer operators, which is F26's decision and not a choice
%%% made here.
money(Cents) ->
    [<<"£"/utf8>>, integer_to_binary(Cents div 100), <<".">>, pence(Cents rem 100)].

%%% A GUARD, not a relational pattern. `Pence(<= 9)` binds no name in B#
%%% (finding 5), so the value has to come from a variable and the test from a
%%% guard. This is the shape the exemplar ships and the shape that compiles.
pence(P) when P =< 9 -> [<<"0">>, integer_to_binary(P)];
pence(P)             -> integer_to_binary(P).

%%% Three clauses over a closed union, no catch-all. Add a fourth status in B#
%%% and the compiler names this function.
status(placed)    -> <<"placed">>;
status(shipped)   -> <<"shipped">>;
status(cancelled) -> <<"cancelled">>.

%%%===================================================================
%%% layout.bs
%%%===================================================================

layout(Model) -> layout(Model, fun escape_correct/1).

layout(#{'Title' := Title, 'Orders' := Orders,
         'Note' := Note, 'IsAdmin' := IsAdmin}, Esc) ->
    [<<"<html><head><title>">>, Esc(Title),
     <<"</title></head><body><h1>">>, Esc(Title), <<"</h1>">>,
     note(Note, Esc),
     admin_link(IsAdmin),
     <<"<table>">>, rows(Orders, Esc, []), <<"</table>">>,
     <<"</body></html>">>].

%%% `option<string>` is `T | :nothing`. The `:nothing` clause is FIRST and the
%%% bound clause is the residual — which is the order B# forces, because there
%%% is no tag to match on.
note(nothing, _Esc) -> [];
note(S, Esc)        -> [<<"<p class=\"note\">">>, Esc(S), <<"</p>">>].

%%% Two clauses, because there is no `if` (ticket 17 §6). `[]` is the empty
%%% fragment and iodata's identity element — no sentinel, no option type.
admin_link(true)  -> [<<"<a href=\"/admin\">admin</a>">>];
admin_link(false) -> [].

%%%===================================================================
%%% render.bs
%%%===================================================================

render(Model) ->
    respond(layout(Model)).

respond(Body) ->
    {200,
     [{<<"content-type">>,   <<"text/html; charset=utf-8">>},
      {<<"content-length">>, integer_to_binary(iolist_size(Body))}],
     Body}.

%%%===================================================================
%%% the checks
%%%===================================================================

main() ->
    io:format("~n=== 25e — a dynamic web page, lowered ===~n~n"),
    ok = check_renders(),
    ok = check_escaping_with_a_parser(),
    ok = check_dropping_escaper_loses_text(),
    ok = check_content_length(),
    ok = check_absent_note(),
    ok = check_empty_fragment_is_free(),
    io:format("~nall checks passed~n"),
    ok.

%%% 1 — it renders, and the response is the shape `render.bs` declares.
check_renders() ->
    {Status, Headers, Body} = render(model()),
    200 = Status,
    true = is_list(Headers),
    Flat = iolist_to_binary(Body),
    io:format("1  rendered ~p bytes~n", [byte_size(Flat)]),
    %% The nesting is real: `Body` is a list containing lists containing lists.
    %% This is the value whose TYPE the checker cannot hold.
    true = depth(Body) >= 3,
    io:format("   iodata nesting depth: ~p — this is why `Iodata` must recurse~n",
              [depth(Body)]),
    ok.

depth(L) when is_list(L) ->
    1 + lists:max([0 | [depth(X) || X <- L]]);
depth(_) -> 0.

%%% 2 — THE ONE THAT MATTERS. Parse the page and prove the injected markup
%%% arrived as TEXT, not as an element.
%%%
%%% A leak and a correct escape produce pages that differ by four characters and
%%% look alike; a parser cannot be fooled by that. If `<script>` were left
%%% unescaped, `xmerl_scan` would build a `script` element and the search below
%%% would find it.
check_escaping_with_a_parser() ->
    {_, _, Body} = render(model()),
    Page = iolist_to_binary(Body),
    {Doc, _Rest} = xmerl_scan:string(binary_to_list(Page)),

    %% No `script` element anywhere in the parsed tree.
    [] = elements_named(Doc, script),
    io:format("2  xmerl parsed the page; `script` elements found: 0~n"),

    %% And the payload IS present, as text, inside a table cell.
    AllText = list_to_binary(text_of(Doc)),
    true = binary:match(AllText, <<"<script>alert(\"xss\")</script>">>) =/= nomatch,
    io:format("   the payload is present as TEXT — escaped, not dropped~n"),

    %% The `&` in the note survived as an ampersand, not as a broken entity.
    true = binary:match(AllText, <<"ends & begins">>) =/= nomatch,
    io:format("   `ends & begins` round-tripped through &amp;~n"),

    %% THE CONTROL. Render the identical page with the leaking escaper and
    %% require the SAME check to find the element. Without this the assertion
    %% above is an absence that has never been seen to fail.
    %%
    %% The note is dropped from the control model on purpose: leaking it puts a
    %% bare `&` in the document, which is an invalid entity reference, and xmerl
    %% then dies on the note BEFORE reaching the script. A control that crashes
    %% is not a control that discriminates — it would prove the check can fail
    %% without proving it can fail ON THE DEFECT IT NAMES.
    LeakedPage = iolist_to_binary(layout(model_without_note(), fun escape_leaking/1)),
    {LeakedDoc, _} = xmerl_scan:string(binary_to_list(LeakedPage)),
    [script] = elements_named(LeakedDoc, script),
    io:format("   CONTROL: the leaking escaper puts a `script` ELEMENT in the tree,~n"),
    io:format("            so check 2 has been seen to fail on the defect it names~n"),
    ok.

elements_named(#xmlElement{name = N, content = C}, Want) ->
    Here = case N of Want -> [N]; _ -> [] end,
    Here ++ lists:flatmap(fun(X) -> elements_named(X, Want) end, C);
elements_named(_, _) -> [].

text_of(#xmlElement{content = C}) -> lists:flatmap(fun text_of/1, C);
text_of(#xmlText{value = V})      -> V;
text_of(_)                        -> "".

%%% 3 — the escaper that compiles without the foreign call deletes the text.
%%% This is finding 3, demonstrated rather than described.
check_dropping_escaper_loses_text() ->
    Input = <<"a<b&c">>,
    Correct  = iolist_to_binary(escape_correct(Input)),
    Dropping = iolist_to_binary(escape_dropping(Input)),
    <<"a&lt;b&amp;c">> = Correct,
    <<"&lt;&amp;">>    = Dropping,
    io:format("3  correct : ~s~n", [Correct]),
    io:format("   dropping: ~s   <- every ordinary character is gone~n", [Dropping]),
    %% And it is not a crash, a warning, or a wrong type. It is a shorter page.
    true = byte_size(Dropping) < byte_size(Correct),
    ok.

%%% 4 — Content-Length is `iolist_size/1` over the recursive type, and it must
%%% agree with the flattened page or the response is malformed.
check_content_length() ->
    {_, Headers, Body} = render(model()),
    {_, Declared} = lists:keyfind(<<"content-length">>, 1, Headers),
    Actual = byte_size(iolist_to_binary(Body)),
    Actual = binary_to_integer(Declared),
    io:format("4  content-length ~s agrees with the flattened page~n", [Declared]),
    ok.

%%% 5 — `option<string>`'s absent arm renders nothing, and the page stays valid.
check_absent_note() ->
    {_, _, Body} = render(model_without_note()),
    Page = iolist_to_binary(Body),
    nomatch = binary:match(Page, <<"class=\"note\"">>),
    {_Doc, _} = xmerl_scan:string(binary_to_list(Page)),
    io:format("5  `:nothing` rendered no note, and the page still parses~n"),
    ok.

%%% 6 — the empty fragment costs nothing: `[]` flattens away entirely.
check_empty_fragment_is_free() ->
    WithAdmin    = iolist_to_binary(layout(model())),
    WithoutAdmin = iolist_to_binary(layout((model())#{'IsAdmin' => false})),
    Delta = byte_size(WithAdmin) - byte_size(WithoutAdmin),
    Delta = byte_size(<<"<a href=\"/admin\">admin</a>">>),
    %% `admin_link(false)` contributed exactly zero bytes — no sentinel, no
    %% placeholder, nothing to strip.
    io:format("6  the absent section contributed 0 bytes (delta ~p = the link itself)~n",
              [Delta]),
    ok.
