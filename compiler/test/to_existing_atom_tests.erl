%%% F54 — ToExistingAtom resolves atoms already in the VM.
%%% Scenarios: compiler/features/F54-to-existing-atom.md
-module(to_existing_atom_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, errors/1, check_only/1]).

%%% ---------------------------------------------------------------------------
%%% F54.1 — an existing atom resolves.
%%% ---------------------------------------------------------------------------

peer_src() ->
    "module TeaResolve\n"
    "public result<atom, string> Resolve(string name)\n"
    "Resolve(name) -> ToExistingAtom(name)\n".

%% `ok` and `true` exist in every VM.
an_atom_the_vm_has_resolves_test() ->
    M = build_and_load(peer_src(), 'TeaResolve'),
    ?assertEqual(ok, M:'Resolve'(<<"ok">>)),
    ?assertEqual(true, M:'Resolve'(<<"true">>)).

%%% ---------------------------------------------------------------------------
%%% F54.2 — a name no atom has is an error carrying the name; nothing is
%%% minted.
%%% ---------------------------------------------------------------------------

%% Measure the delta because eunit interns atoms while the suite runs.
a_name_no_atom_has_is_the_error_carrying_the_name_test() ->
    M = build_and_load(peer_src(), 'TeaResolve'),
    Name = <<"zzz_no_such_atom_anywhere_xyz">>,
    Before = erlang:system_info(atom_count),
    ?assertEqual({error, Name}, M:'Resolve'(Name)),
    ?assertEqual(Before, erlang:system_info(atom_count)),
    ?assertError(badarg, binary_to_existing_atom(Name, utf8)).

%% Non-ASCII input exposes accidental re-encoding of the failure name.
the_reason_is_the_name_handed_over_test() ->
    M = build_and_load(peer_src(), 'TeaResolve'),
    Name = <<"zzz_naïve_ünïcode_name"/utf8>>,
    ?assertEqual({error, Name}, M:'Resolve'(Name)).

%%% ---------------------------------------------------------------------------
%%% F54.3 — module atoms resolve in a VM that only loads the beam.
%%% ---------------------------------------------------------------------------

widget_src() ->
    "module Widget\n"
    "type Mode = :zzz_type_only_mode | :zzz_other_mode\n"
    "public atom Tag()\n"
    "Tag() -> :zzz_widget_tag\n"
    "public list<Mode> Modes()\n"
    "Modes() -> []\n"
    "public result<atom, string> Resolve(string name)\n"
    "Resolve(name) -> ToExistingAtom(name)\n".

%% The shell helper uses exec; a leading cd would prevent erl from running.
in_fresh_vm(Dir, Mod, Name) ->
    Eval = "io:format(\"~0p\", [apply(list_to_atom(\"" ++ atom_to_list(Mod) ++
           "\"), list_to_atom(\"Resolve\"), [<<\"" ++ Name ++ "\">>])]), halt().",
    Cmd = "erl -noshell -pa '" ++ Dir ++ "' -eval '" ++ Eval ++ "'",
    {0, Out} = bs_test_support:run_command_result(Cmd),
    Out.

%% An isolated directory prevents test beams from shadowing OTP modules
%% on case-insensitive disks. The absent name controls the fresh-VM lookup.
a_value_position_atom_resolves_in_a_vm_that_did_not_compile_it_test() ->
    M = build_and_load(widget_src(), 'Widget'),
    Dir = bs_test_support:fixture_root(),
    {ok, _} = file:copy(code:which(M), filename:join(Dir, "Widget.beam")),
    ?assertEqual("zzz_widget_tag", in_fresh_vm(Dir, M, "zzz_widget_tag")),
    ?assertEqual("{error,<<\"zzz_widget_absent\">>}",
                 in_fresh_vm(Dir, M, "zzz_widget_absent")).

%% The compiler interns source atoms, so only a fresh VM tests loading.
%% Type atoms can live in the literal chunk, beyond beam_lib atom inspection.
a_type_only_atom_resolves_in_a_vm_that_did_not_compile_it_test() ->
    M = build_and_load(widget_src(), 'Widget'),
    Dir = bs_test_support:fixture_root(),
    {ok, _} = file:copy(code:which(M), filename:join(Dir, "Widget.beam")),
    ?assertEqual("zzz_type_only_mode", in_fresh_vm(Dir, M, "zzz_type_only_mode")),
    ?assertEqual("zzz_other_mode", in_fresh_vm(Dir, M, "zzz_other_mode")).

%% The error atom comes from result; atom itself names no finite set.
every_module_exports_the_atoms_its_types_name_test() ->
    W = build_and_load(widget_src(), 'Widget'),
    ?assertEqual([error, zzz_other_mode, zzz_type_only_mode], W:'bs@type_atoms'()),
    P = build_and_load("module Plain\n"
                       "public int Inc(int n)\n"
                       "Inc(n) -> n + 1\n", 'Plain'),
    ?assertEqual([], P:'bs@type_atoms'()).

a_declared_but_unused_type_still_counts_keys_included_test() ->
    D = build_and_load("module Decl\n"
                       "record Point { X: int }\n"
                       "type Tagged<T> = :zzz_tagged | T\n"
                       "public int Inc(int n)\n"
                       "Inc(n) -> n + 1\n", 'Decl'),
    ?assertEqual(['Decl.Point', 'Kind', 'X', zzz_tagged], D:'bs@type_atoms'()).

%% Only Uses.beam is on the fresh VM path; neither name is a value in Uses.
an_imported_types_atoms_reach_the_importing_modules_chunk_test() ->
    Root = bs_test_support:fixture_root(),
    Main = bs_test_support:place(
             Root, "uses.bs",
             "module Uses\n"
             "using Kinds\n"
             "public list<Mode> Known()\n"
             "Known() -> []\n"
             "public result<atom, string> Resolve(string name)\n"
             "Resolve(name) -> ToExistingAtom(name)\n"),
    _Dep = bs_test_support:place(
             Root, "kinds.bs",
             "module Kinds\n"
             "type Mode = :zzz_kind_fast | :zzz_kind_slow\n"
             "public Mode First()\n"
             "First() -> :zzz_kind_fast\n"),
    Out = Root ++ "/out",
    {0, ""} = bs_test_support:run_cli_result(
                "--src-root " ++ Root ++ " -o " ++ Out ++ " " ++ Main),
    Alone = bs_test_support:fixture_root(),
    {ok, _} = file:copy(Out ++ "/Uses.beam", filename:join(Alone, "Uses.beam")),
    ?assertEqual("zzz_kind_slow", in_fresh_vm(Alone, 'Uses', "zzz_kind_slow")),
    ?assertEqual("zzz_kind_fast", in_fresh_vm(Alone, 'Uses', "zzz_kind_fast")).

%%% ---------------------------------------------------------------------------
%%% F54.4 — the return type must admit failure.
%%% ---------------------------------------------------------------------------

a_return_type_without_the_failure_member_is_refused_test() ->
    Src = "module TeaNarrow\n"
          "public atom Go(string s)\n"
          "Go(s) -> ToExistingAtom(s)\n",
    [{error, _, 'Go', {return_not_declared, Undeclared, Corrected}}] = errors(Src),
    ?assertEqual(<<"(:error, string)">>,
                 iolist_to_binary(bs_types:to_string(Undeclared))),
    ?assertNotEqual(none, Corrected).

%%% ---------------------------------------------------------------------------
%%% F54.5 — the argument must be a string.
%%% ---------------------------------------------------------------------------

%% Non-binary input and missing atoms both raise badarg in the runtime BIF.
a_term_argument_is_refused_test() ->
    Src = "module TeaArgTerm\n"
          "public result<atom, string> Go(term t)\n"
          "Go(t) -> ToExistingAtom(t)\n",
    ?assertMatch([{error, _, 'Go', {to_existing_atom_arg, _}}], errors(Src)).

an_int_argument_is_refused_test() ->
    Src = "module TeaArgInt\n"
          "public result<atom, string> Go(int n)\n"
          "Go(n) -> ToExistingAtom(n)\n",
    ?assertMatch([{error, _, 'Go', {to_existing_atom_arg, _}}], errors(Src)).

%% A binary may contain invalid UTF-8, but the failure must carry a string.
a_binary_argument_is_refused_test() ->
    Src = "module TeaArgBin\n"
          "public result<atom, string> Go(binary b)\n"
          "Go(b) -> ToExistingAtom(b)\n",
    ?assertMatch([{error, _, 'Go', {to_existing_atom_arg, _}}], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F54.6 — the call takes no type argument and one value.
%%% ---------------------------------------------------------------------------

the_bracket_form_is_refused_test() ->
    Src = "module TeaBracket\n"
          "public result<atom, string> Go(string s)\n"
          "Go(s) -> ToExistingAtom<atom>(s)\n",
    ?assertMatch([{error, _, 'Go', {obligation_arity, 'ToExistingAtom', 1, 1}}],
                 errors(Src)).

no_value_is_refused_test() ->
    Src = "module TeaNoArg\n"
          "public result<atom, string> Go(string s)\n"
          "Go(s) -> ToExistingAtom()\n",
    ?assertMatch([{error, _, 'Go', {obligation_arity, 'ToExistingAtom', 0, 0}}],
                 errors(Src)).

two_values_are_refused_test() ->
    Src = "module TeaTwoArgs\n"
          "public result<atom, string> Go(string s)\n"
          "Go(s) -> ToExistingAtom(s, s)\n",
    ?assertMatch([{error, _, 'Go', {obligation_arity, 'ToExistingAtom', 0, 2}}],
                 errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F54.7 — the pipe supplies the string.
%%% ---------------------------------------------------------------------------

the_pipe_form_resolves_the_piped_string_test() ->
    Src = "module TeaPipe\n"
          "public result<atom, string> Go(string s)\n"
          "Go(s) -> s |> ToExistingAtom()\n",
    M = build_and_load(Src, 'TeaPipe'),
    ?assertEqual(ok, M:'Go'(<<"ok">>)),
    ?assertEqual({error, <<"zzz_piped_absent">>}, M:'Go'(<<"zzz_piped_absent">>)).

%%% ---------------------------------------------------------------------------
%%% F54.8 — a user cannot declare the compiler-known name.
%%% ---------------------------------------------------------------------------

redeclaring_the_name_as_a_function_is_refused_test() ->
    Src = "module TeaShadow\n"
          "public atom ToExistingAtom(string s)\n"
          "ToExistingAtom(s) -> :nope\n",
    ?assertError({compiler_known_function, 'ToExistingAtom', _}, check_only(Src)).

%% The API query uses a separate declaration pass from normal checking.
the_query_refuses_the_redeclaration_too_test() ->
    Src = "module TeaShadowApi\n"
          "public atom ToExistingAtom(string s)\n"
          "ToExistingAtom(s) -> :nope\n",
    bs_test_support:with_src(
      "in.bs", Src,
      fun(Path, Root) ->
              {Rc, Out, Err} = bs_test_support:run_cli_split_result(
                                 "--src-root " ++ Root ++ " --api " ++ Path),
              ?assertEqual(1, Rc),
              ?assertEqual("", Out),
              ?assertNotEqual(nomatch, string:find(Err, "compiler-known"))
      end).

%%% ---------------------------------------------------------------------------
%%% F54.9 — a switch handles success and failure.
%%% ---------------------------------------------------------------------------

kind_src() ->
    "module Kind\n"
    "public atom Kind(string s)\n"
    "Kind(s) -> ToExistingAtom(s) switch {\n"
    "    (:error, _) => :unknown,\n"
    "    a           => a\n"
    "}\n".

a_switch_over_the_result_is_exhaustive_test() ->
    M = build_and_load(kind_src(), 'Kind'),
    ?assertEqual(ok, M:'Kind'(<<"ok">>)),
    ?assertEqual(unknown, M:'Kind'(<<"zzz_kind_absent_name">>)).

%%% ---------------------------------------------------------------------------
%%% F54.10 — CLI diagnostics reach the author as prose.
%%% ---------------------------------------------------------------------------

%% Run the CLI to check prose dispatch; diagnostic tag sets cannot prove it.
prose_cases() ->
    [{to_existing_atom_arg,
      "module TeaProseArg\n"
      "public result<atom, string> Go(term t)\n"
      "Go(t) -> ToExistingAtom(t)\n",
      "hands ToExistingAtom a"},
     {obligation_arity,
      "module TeaProseBracket\n"
      "public result<atom, string> Go(string s)\n"
      "Go(s) -> ToExistingAtom<atom>(s)\n",
      "no type argument and one value"},
     {compiler_known_function,
      "module TeaProseShadow\n"
      "public atom ToExistingAtom(string s)\n"
      "ToExistingAtom(s) -> :nope\n",
      "compiler-known"},
     {not_an_obligation,
      "module TeaProseRoster\n"
      "public int Go(term t)\n"
      "Go(t) -> Encode<int>(t)\n",
      "ValidateAs, ParseAtom, ToExistingAtom, ToJson"}].

every_new_diagnostic_reaches_the_author_as_prose_test_() ->
    [{atom_to_list(Tag), fun() -> assert_prose(Tag, Src, Fragment) end}
     || {Tag, Src, Fragment} <- prose_cases()].

assert_prose(Tag, Src, Fragment) ->
    ?assert(filelib:is_regular(bs_test_support:escript())),
    bs_test_support:with_src(
      "in.bs", Src,
      fun(Path, Root) ->
              Out = bs_test_support:run_cli(
                      "-o " ++ Root ++ "/out " ++ filename:dirname(Path)),
              ?assertNotEqual(nomatch, string:find(Out, "rc:1")),
              ?assertNotEqual(nomatch, string:find(Out, Fragment)),
              ?assertEqual(nomatch, string:find(Out, "escript: exception")),
              ?assertEqual(nomatch, string:find(Out, atom_to_list(Tag)))
      end).
