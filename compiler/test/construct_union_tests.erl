%%% Ticket 111: construction may not name a union (ENG-493).
-module(construct_union_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [run_cli/1, with_src/3]).

%%% The name before `{` stands for exactly one member. Before the refusal,
%%% `Doc { … }` over `Invoice | Receipt` compiled, checked no field, and
%%% returned a value tagged `:'Billing.Doc'`, which is neither member.

billing(Body) ->
    "module Billing\n"
    "record Invoice { Id: string, Amount: int }\n"
    "record Receipt { Id: string, Amount: int, PaidAt: int }\n"
    "type Doc = Invoice | Receipt\n"
    "public Doc Raise(string id, int amount)\n"
    "Raise(id, amount) -> " ++ Body ++ "\n".

split_events(Body) ->
    "module Events\n"
    "type Event = { Kind: :placed, OrderId: string }"
    " | { Kind: :shipped, OrderId: string, Carrier: string }\n"
    "public Event Placed(string id)\n"
    "Placed(id) -> " ++ Body ++ "\n".

%% Compile through the CLI and hand back its combined output, ending `rc:N`.
compiled(Name, Src, Args) ->
    with_src(Name, Src,
             fun(Path, Out) -> run_cli("-o " ++ Out ++ " " ++ Path ++ Args) end).

refused(Name, Src) ->
    Got = compiled(Name, Src, ""),
    ?assertEqual(nomatch, string:find(Got, "rc:0")),
    Got.

has(Got, Text) ->
    ?assertNotEqual(nomatch, string:find(Got, Text)).

%% The JSON channel carries the construction's name and its members as text.
objects(Name, Src) ->
    with_src(Name, Src,
             fun(Path, Root) ->
                     {_, Out, _} = bs_test_support:run_cli_split_result(
                                     "--diagnostics json --src-root " ++ Root
                                     ++ " " ++ Path),
                     [json:decode(list_to_binary(L))
                      || L <- string:split(string:trim(Out), "\n", all), L =/= ""]
             end).

%% A union of records: the error names both, and the advice names a record.
a_union_of_records_is_refused_test() ->
    Got = refused("billing.bs", billing("Doc { Id = id, Amount = amount }")),
    has(Got, "error: Raise constructs Doc, which names more than one member"),
    has(Got, "  Doc is one of:\n    Invoice\n    Receipt\n"),
    has(Got, "`Invoice { ... }`").

%% The wrong field value was never checked; it is refused by the same rule,
%% before any field is read.
a_wrong_field_is_refused_by_the_same_rule_test() ->
    Got = refused("billing.bs", billing("Doc { Id = 7 }")),
    has(Got, "Raise constructs Doc, which names more than one member").

%% The hand-written union, in the split spelling. Its members have no record
%% name, so they print by shape and the advice is the bare brace.
a_split_hand_written_union_is_refused_test() ->
    Got = refused("events.bs",
                  split_events("Event { Kind = :placed, OrderId = id }")),
    has(Got, "Placed constructs Event, which names more than one member"),
    has(Got, ":placed"),
    has(Got, ":shipped"),
    has(Got, "bare brace"),
    ?assertEqual(nomatch, string:find(Got, "by its own name")).

%% The joined spelling is the same type (ticket 109), so the same refusal.
a_joined_hand_written_union_is_refused_test() ->
    Got = refused("joined.bs",
                  "module Joined\n"
                  "type Event = { Kind: :placed | :shipped, OrderId: string }\n"
                  "public Event Placed(string id)\n"
                  "Placed(id) -> Event { Kind = :placed, OrderId = id }\n"),
    has(Got, "Placed constructs Event, which names more than one member"),
    has(Got, ":placed"),
    has(Got, ":shipped").

%% A union mixing a record and a hand-written member gives both repairs.
a_mixed_union_names_both_repairs_test() ->
    Got = refused("mixed.bs",
                  "module Mixed\n"
                  "record Invoice { Id: string }\n"
                  "type Doc = Invoice | { Kind: :refund, Id: string }\n"
                  "public Doc Make(string id)\n"
                  "Make(id) -> Doc { Id = id }\n"),
    has(Got, "    Invoice\n"),
    has(Got, ":refund"),
    has(Got, "`Invoice { ... }`"),
    has(Got, "bare brace").

%% A member need not be a map: `:none` beside a record is a second member.
a_union_with_an_atom_member_is_refused_test() ->
    Got = refused("maybe.bs",
                  "module Maybe\n"
                  "record Invoice { Id: string }\n"
                  "type MaybeDoc = Invoice | :none\n"
                  "public MaybeDoc Make(string id)\n"
                  "Make(id) -> MaybeDoc { Id = id }\n"),
    has(Got, "Make constructs MaybeDoc, which names more than one member"),
    has(Got, "    Invoice\n"),
    has(Got, "    :none\n").

%% A construction nested in a field value is checked where it stands.
a_nested_construction_is_refused_test() ->
    Got = refused("nested.bs",
                  "module Nested\n"
                  "record Invoice { Id: string }\n"
                  "record Receipt { Id: string }\n"
                  "type Doc = Invoice | Receipt\n"
                  "record Envelope { Body: Doc }\n"
                  "public Envelope Wrap(string id)\n"
                  "Wrap(id) -> Envelope { Body = Doc { Id = id } }\n"),
    has(Got, "Wrap constructs Doc, which names more than one member").

%% The machine channel names the construction and lists its members as text.
the_json_channel_carries_the_members_test() ->
    [Object] = objects("billing.bs", billing("Doc { Id = id, Amount = amount }")),
    ?assertMatch(#{<<"tag">> := <<"construct_union">>,
                   <<"severity">> := <<"error">>,
                   <<"type">> := <<"Doc">>,
                   <<"members">> := [<<"Invoice">>, <<"Receipt">>]}, Object).

%%% Green controls: the repairs, and a name that stands for one member.

a_record_member_is_constructed_by_its_own_name_test() ->
    Got = compiled("billing.bs", billing("Invoice { Id = id, Amount = amount }"),
                   " Raise '\"A-1\"' 50"),
    has(Got, "rc:0"),
    has(Got, "Kind = :'Billing.Invoice'").

a_hand_written_member_is_built_with_a_bare_brace_test() ->
    Got = compiled("events.bs", split_events("{ Kind = :placed, OrderId = id }"),
                   " Placed '\"A-1\"'"),
    has(Got, "rc:0"),
    has(Got, "{Kind = :placed, OrderId = \"A-1\"}").

a_single_tagged_member_still_builds_by_name_test() ->
    Got = compiled("placed.bs",
                   "module Placed\n"
                   "type Placed = { Kind: :placed, OrderId: string }\n"
                   "public Placed Make(string id)\n"
                   "Make(id) -> Placed { OrderId = id }\n",
                   " Make '\"A-1\"'"),
    has(Got, "rc:0"),
    has(Got, "{Kind = :placed, OrderId = \"A-1\"}").
