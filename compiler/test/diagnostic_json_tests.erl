%%% Scenarios: compiler/features/F47-diagnostic-json.md
-module(diagnostic_json_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [with_src/3, project_root/0]).

%%% JSON diagnostics

out(Args) ->
    {_, Stdout, _} = bs_test_support:run_cli_split_result(Args),
    Stdout.

err(Args) ->
    {_, _, Stderr} = bs_test_support:run_cli_split_result(Args),
    Stderr.

guarded(Fun) ->
    case bs_test_support:built() of
        false -> ok;
        true  -> Fun()
    end.

parse_term(S) ->
    {ok, Tokens, _} = erl_scan:string(S ++ "."),
    {ok, Term} = erl_parse:parse_term(Tokens),
    Term.

lines(S) -> [L || L <- string:split(string:trim(S), "\n", all), L =/= ""].

terms(S) -> [parse_term(L) || L <- lines(S)].

%% Stdout is read as bytes, so these binaries preserve the emitted UTF-8.
objects(S) -> [json:decode(list_to_binary(L)) || L <- lines(S)].

%% Normalize independently of the encoder so it cannot validate itself.
%% Empty lists and declared arities are arrays, not text.
wire(Desc) -> wire(maps:get(tag, Desc, undefined), tag, Desc).

wire(Tag, _Key, M) when is_map(M) ->
    maps:from_list([{wire(Tag, K, K), wire(Tag, K, V)} || {K, V} <- maps:to_list(M)]);
wire(_Tag, _Key, []) ->
    [];
wire(Tag, Key, L) when is_list(L) ->
    case lists:all(fun erlang:is_integer/1, L) of
        true when Tag =:= name_arity_unfixed, Key =:= declared -> L;
        true when Tag =:= arity_not_declared, Key =:= declared -> L;
        true  -> unicode:characters_to_binary(L);
        false -> [wire(Tag, Key, X) || X <- L]
    end;
wire(_Tag, _Key, A) when A =:= true; A =:= false; A =:= null ->
    A;
wire(_Tag, _Key, A) when is_atom(A) ->
    atom_to_binary(A, utf8);
wire(_Tag, _Key, X) ->
    X.

inexhaustive_src() ->
    "module Rank\n"
    "type Signal = :red | :amber | :green\n"
    "public int Rank(Signal s)\n"
    "Rank(:red) -> 1\n"
    "Rank(:green) -> 3\n"
    "public int Two(Signal s, int n)\n"
    "Two(:red, n) when n > 0 -> n\n".

%%% F47.1 — stdout carries one object per line with text as strings.

the_json_is_published_on_stdout_test() ->
    guarded(fun() ->
        with_src("in.bs", inexhaustive_src(), fun(Path, Root) ->
            Objects = objects(out("--diagnostics json --src-root " ++ Root ++
                                      " " ++ Path)),
            ?assertEqual(2, length(Objects)),
            [Rank, Two] = Objects,
            ?assertMatch(#{<<"tag">> := <<"inexhaustive">>,
                           <<"severity">> := <<"error">>,
                           <<"function">> := <<"Rank">>,
                           <<"line">> := 3,
                           <<"heads">> := #{<<"pasteable">> :=
                                                [<<"Rank(:amber) -> ...">>]}},
                         Rank),
            %% Raw charlists would encode as integer arrays.
            #{<<"file">> := File} = Rank,
            ?assert(is_binary(File)),
            ?assertEqual(<<"in.bs">>, filename:basename(File)),
            %% Residual products nest as arrays; their leaves are text.
            ?assertMatch(#{<<"function">> := <<"Two">>,
                           <<"heads">> :=
                               #{<<"products">> :=
                                     [[[<<":amber">>, <<":green">>], [<<"int">>]],
                                      [[<<":red">>], [<<"int <= 0">>]]]}},
                         Two)
        end)
    end).

%%% F47.2 — JSON leaves stderr prose unchanged.

the_prose_is_unchanged_under_json_test() ->
    guarded(fun() ->
        with_src("in.bs", inexhaustive_src(), fun(Path, Root) ->
            Args = "--src-root " ++ Root ++ " " ++ Path,
            ?assertEqual(err(Args), err("--diagnostics json " ++ Args)),
            ?assertNotEqual(nomatch, string:find(err(Args), "is not exhaustive"))
        end)
    end).

%%% F47.3 — decoded JSON equals the normalized diagnostic term.

the_json_is_the_term_test() ->
    guarded(fun() ->
        with_src("in.bs", inexhaustive_src(), fun(Path, Root) ->
            Args = "--src-root " ++ Root ++ " " ++ Path,
            Terms   = terms(out("--diagnostics term " ++ Args)),
            Objects = objects(out("--diagnostics json " ++ Args)),
            ?assertEqual(2, length(Terms)),
            ?assertEqual([wire(T) || T <- Terms], Objects)
        end)
    end).

%%% F47.4 — raised errors and warnings use JSON too.

a_raised_condition_is_json_too_test() ->
    guarded(fun() ->
        Src = "module R\n"
              "public int F(Missing m)\n"
              "F(m) -> 1\n",
        with_src("in.bs", Src, fun(Path, Root) ->
            Args = "--src-root " ++ Root ++ " " ++ Path,
            [Object] = objects(out("--diagnostics json " ++ Args)),
            ?assertMatch(#{<<"tag">> := <<"unknown_type">>,
                           <<"severity">> := <<"error">>,
                           <<"line">> := 2, <<"column">> := 12}, Object),
            [Term] = terms(out("--diagnostics term " ++ Args)),
            ?assertEqual(wire(Term), Object)
        end)
    end).

a_warning_is_json_and_still_compiles_test() ->
    guarded(fun() ->
        Src = "module W\n"
              "public int F(int n)\n"
              "F(n) -> 1\n"
              "F(0) -> 0\n",
        with_src("in.bs", Src, fun(Path, Root) ->
            Args = "--diagnostics json --src-root " ++ Root ++ " " ++ Path,
            [Object] = objects(out(Args)),
            ?assertMatch(#{<<"tag">> := <<"unreachable_clause">>,
                           <<"severity">> := <<"warning">>}, Object),
            {Rc, _} = bs_test_support:run_cli_result(Args),
            ?assertEqual(0, Rc)
        end)
    end).

%%% F47.5 — paths reach stdout as UTF-8.

%% The filename uses codepoints for filesystem and port arguments.
%% Expectations use UTF-8 bytes because stdout is read as bytes.
a_path_is_utf8_on_the_wire_test() ->
    guarded(fun() ->
        with_src("caf\x{e9}.bs", inexhaustive_src(), fun(Path, Root) ->
            Out = out("--diagnostics json --src-root " ++ Root ++ " " ++ Path),
            ?assertNotEqual(nomatch, string:find(Out, "caf\303\251.bs\"")),
            [Rank | _] = objects(Out),
            #{<<"file">> := File} = Rank,
            ?assertEqual(<<"caf", 195, 169, ".bs">>, filename:basename(File))
        end)
    end).

%%% F47.6–F47.7 — channel refusals name the supported choices.

the_json_channel_is_refused_in_the_repl_test() ->
    guarded(fun() ->
        {Rc, Out} = bs_test_support:run_cli_result(
                      "--repl -S x.bs --diagnostics json"),
        ?assertNotEqual(nomatch, string:find(Out, "not available in the REPL")),
        ?assertEqual(2, Rc)
    end).

an_unknown_channel_is_refused_naming_all_three_test() ->
    guarded(fun() ->
        {Rc, Out} = bs_test_support:run_cli_result("--diagnostics xml x.bs"),
        ?assertEqual(2, Rc),
        ?assertNotEqual(nomatch, string:find(Out, "`prose`, `term` or `json`")),
        {2, Usage} = bs_test_support:run_cli_result(""),
        ?assertNotEqual(nomatch, string:find(Usage, "--diagnostics term|json"))
    end).

%%% F47.8 — query mode returns JSON.

the_api_answer_is_json_test() ->
    guarded(fun() ->
        Counter = project_root() ++ "/examples/Counter",
        {Rc, Out, _} = bs_test_support:run_cli_split_result(
                         "--diagnostics json --api " ++ Counter),
        ?assertEqual(0, Rc),
        [Module | Ops] = objects(Out),
        ?assertMatch(#{<<"tag">> := <<"module">>, <<"module">> := <<"Counter">>,
                       <<"behaviours">> := [<<"GenServer">>],
                       <<"operations">> := 3}, Module),
        ?assertEqual([{<<"HandleCall">>, 3}, {<<"HandleCast">>, 2}, {<<"Init">>, 1}],
                     [{N, A} || #{<<"tag">> := <<"operation">>,
                                  <<"name">> := N, <<"arity">> := A} <- Ops]),
        {0, TermOut, _} = bs_test_support:run_cli_split_result(
                            "--diagnostics term --api " ++ Counter),
        ?assertEqual([wire(T) || T <- terms(TermOut)], [Module | Ops])
    end).

%%% F47.10 — unclassified details remain printable diagnostics.

%% Exercise the descriptor directly: source cannot force this fallback path.
%% Tuple details must print as text rather than crash the JSON encoder.
an_unclassified_detail_is_printed_text_test() ->
    Desc = #{tag => unclassified, severity => error, file => "x.bs",
             detail => {error, 3, "F", {no_such_shape, [1, 2]}}},
    Object = json:decode(iolist_to_binary(bs_diag:json(Desc))),
    ?assertMatch(#{<<"tag">> := <<"unclassified">>, <<"file">> := <<"x.bs">>},
                 Object),
    #{<<"detail">> := Detail} = Object,
    ?assert(is_binary(Detail)),
    ?assertEqual(<<"{error,3,\"F\",{no_such_shape,[1,2]}}">>, Detail).

%%% F47.12–F47.13 — integer payload lists encode as arrays or are refused.

%% Assert bytes independently of `wire/3` so a shared schema mistake fails.
the_declared_arities_are_an_array_on_the_wire_test() ->
    guarded(fun() ->
        Src = "module Arity\n"
              "public int Add(int a, int b)\n"
              "Add(a, b) -> a + b\n"
              "public int Add(int a, int b, int c)\n"
              "Add(a, b, c) -> a + b + c\n"
              "public int Call()\n"
              "Call() -> Add(1)\n",
        with_src("in.bs", Src, fun(Path, Root) ->
            Args = "--src-root " ++ Root ++ " " ++ Path,
            Out = out("--diagnostics json " ++ Args),
            ?assertNotEqual(nomatch, string:find(Out, "\"declared\":[2,3]")),
            [Object] = objects(Out),
            ?assertMatch(#{<<"tag">> := <<"arity_not_declared">>,
                           <<"got">> := 1, <<"declared">> := [2, 3]}, Object),
            [Term] = terms(out("--diagnostics term " ++ Args)),
            ?assertEqual(wire(Term), Object)
        end)
    end).

the_bare_name_arities_are_an_array_on_the_wire_test() ->
    guarded(fun() ->
        Src = "module Bare\n"
              "public int Double(int n)\n"
              "Double(n) -> n * 2\n"
              "public int Double(int n, int k)\n"
              "Double(n, k) -> n * k\n"
              "public int Later(int n)\n"
              "Later(n) -> var f = Double\n"
              "            f(n)\n",
        with_src("in.bs", Src, fun(Path, Root) ->
            Out = out("--diagnostics json --src-root " ++ Root ++ " " ++ Path),
            ?assertNotEqual(nomatch, string:find(Out, "\"declared\":[1,2]")),
            [Object] = objects(Out),
            ?assertMatch(#{<<"tag">> := <<"name_arity_unfixed">>,
                           <<"name">> := <<"Double">>,
                           <<"declared">> := [1, 2]}, Object)
        end)
    end).

%% No descriptor produces this payload; inject it directly to test refusal.
an_unrostered_integer_list_crashes_rather_than_encoding_test() ->
    Desc = #{tag => some_new_tag, severity => error, file => "x.bs",
             line => 1, column => 1, function => 'F', widths => [8, 16]},
    ?assertError({json_list_unrostered, some_new_tag, widths, [8, 16]},
                 bs_diag:json(Desc)).

%% Empty lists represent arrays in diagnostic terms, never empty strings.
an_empty_list_is_an_array_test() ->
    guarded(fun() ->
        Aliasing = project_root() ++ "/examples/Aliasing",
        {0, Out, _} = bs_test_support:run_cli_split_result(
                        "--diagnostics json --api " ++ Aliasing),
        ?assertNotEqual(nomatch, string:find(Out, "\"behaviours\":[]")),
        [Module | _] = objects(Out),
        ?assertMatch(#{<<"tag">> := <<"module">>, <<"behaviours">> := []}, Module)
    end).
