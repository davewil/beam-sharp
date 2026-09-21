%%% F54 — `ToExistingAtom`, the interop escape: a string to an atom the VM
%%% already has, or the name back as the reason it has not.
%%%
%%% AT THE BOUNDARY, AND THE BOUNDARY IS A RUNNING PROGRAM, as `parse_atom_tests`
%%% set for the sibling: what `ToExistingAtom` MEANS is what a compiled module
%%% returns when handed a string, so the behavioural tests compile source, load
%%% the `.beam` and call it. Nothing asserts on the emitted abstract format.
%%%
%%% ONE TEST RUNS THE MODULE IN A VM THAT DID NOT COMPILE IT, and the reason is
%%% a trap the in-process tests cannot see. `build_and_load` compiles in this
%%% VM, and the compiler interns every atom the source spells the moment it
%%% lexes `:widget` — so in-process, `ToExistingAtom("widget")` succeeds because
%%% the COMPILER minted the atom, whatever the emitted module carries. The
%%% question this feature turns on is what a fresh VM finds after loading the
%%% `.beam`, so those tests spawn one. One asks about an atom in value position.
%%% An atom that appears ONLY in a type is ticket 10 §6.2's obligation, decided
%%% as ticket 87 and built as F55: the emitter exports `'bs@type_atoms'/0` on
%%% every module, and the two tests beside it are the ones that see it. Never
%%% `beam_lib`'s atom chunk: a literal's atoms live in the literal chunk and are
%%% interned at load, so that inspector reports "absent" for a module that works.
%%%
%%% THE REFUSALS CANNOT LIVE IN `examples/`, for the reason F39 gave: every
%%% example must compile, and a rule whose whole content is a rejection has
%%% nowhere else to be looked at.
-module(to_existing_atom_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, errors/1, check_only/1]).

%%% ---------------------------------------------------------------------------
%%% F54.1 — the decided case: an atom the VM has comes back as that atom
%%% ---------------------------------------------------------------------------

peer_src() ->
    "module TeaResolve\n"
    "public result<atom, string> Resolve(string name)\n"
    "Resolve(name) -> ToExistingAtom(name)\n".

%% `ok` and `true` exist in every VM, so nothing about this test depends on
%% who minted them.
an_atom_the_vm_has_resolves_test() ->
    M = build_and_load(peer_src(), 'TeaResolve'),
    ?assertEqual(ok, M:'Resolve'(<<"ok">>)),
    ?assertEqual(true, M:'Resolve'(<<"true">>)).

%%% ---------------------------------------------------------------------------
%%% F54.2 — a name no atom has: the error carries the name, and nothing is minted
%%% ---------------------------------------------------------------------------

%% Ticket 67: the failure is `(:error, name)`, the reason being the name that
%% resolved to nothing. And ticket 10 §4's whole reason for the long spelling:
%% the table is not grown. Measured as a delta, as F39.2 does, because eunit
%% interns atoms of its own while the suite runs.
a_name_no_atom_has_is_the_error_carrying_the_name_test() ->
    M = build_and_load(peer_src(), 'TeaResolve'),
    Name = <<"zzz_no_such_atom_anywhere_xyz">>,
    Before = erlang:system_info(atom_count),
    ?assertEqual({error, Name}, M:'Resolve'(Name)),
    ?assertEqual(Before, erlang:system_info(atom_count)),
    %% and the name it was handed is still not an atom
    ?assertError(badarg, binary_to_existing_atom(Name, utf8)).

%% The reason is the string handed over, byte for byte. A non-ASCII name is
%% the case that would show a re-encoding, because `atom_to_binary` and
%% `binary_to_existing_atom` both speak UTF-8 and a latin-1 detour would not.
the_reason_is_the_name_handed_over_test() ->
    M = build_and_load(peer_src(), 'TeaResolve'),
    Name = <<"zzz_naïve_ünïcode_name"/utf8>>,
    ?assertEqual({error, Name}, M:'Resolve'(Name)).

%%% ---------------------------------------------------------------------------
%%% F54.3 — in a VM that did not compile it: the module's own atoms are found
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

%% `Mod:Resolve(<<Name>>)` in a VM that only LOADS the beam, printed as a
%% term. No `cd` in front: `run_command_result/1` hands the shell `exec`
%% and the command, so a leading `cd` is what gets exec'd and `erl` never
%% runs — measured as an empty answer with status 0, which is why the
%% status is matched and the output compared whole.
in_fresh_vm(Dir, Mod, Name) ->
    Eval = "io:format(\"~0p\", [apply(list_to_atom(\"" ++ atom_to_list(Mod) ++
           "\"), list_to_atom(\"Resolve\"), [<<\"" ++ Name ++ "\">>])]), halt().",
    Cmd = "erl -noshell -pa '" ++ Dir ++ "' -eval '" ++ Eval ++ "'",
    {0, Out} = bs_test_support:run_command_result(Cmd),
    Out.

%% An atom in VALUE position reaches the chunk by construction, so a fresh VM
%% has it the moment the module loads. The absent control beside it is what
%% shows the fresh VM is not this one: it has never seen either name.
%%
%% THE BEAM IS COPIED TO A DIRECTORY OF ITS OWN before the VM is pointed at
%% it. The suite's shared output directory holds every test module's beam,
%% and on a case-insensitive disk one of them shadows an OTP module the VM
%% loads at boot — `Peer.beam` over `peer`, the `Json.beam` shape of ENG-391 —
%% so the spawned VM died before it could answer, but only under the full
%% suite, never with this module run alone.
a_value_position_atom_resolves_in_a_vm_that_did_not_compile_it_test() ->
    M = build_and_load(widget_src(), 'Widget'),
    Dir = bs_test_support:fixture_root(),
    {ok, _} = file:copy(code:which(M), filename:join(Dir, "Widget.beam")),
    ?assertEqual("zzz_widget_tag", in_fresh_vm(Dir, M, "zzz_widget_tag")),
    ?assertEqual("{error,<<\"zzz_widget_absent\">>}",
                 in_fresh_vm(Dir, M, "zzz_widget_absent")).

%% Ticket 10 §6.2: an atom appearing ONLY in a type is absent from the chunk
%% unless the compiler puts it there, and then ToExistingAtom("zzz_type_only_mode")
%% refuses a value the declared type says is legal. `Mode`'s members appear in
%% no pattern and no expression of `Widget`; this test was red until the
%% emitter discharged the obligation (ticket 87, ENG-397), and it is the first
%% construct in the language that can tell. Never `beam_lib`: the atoms live in
%% the literal chunk and are interned at load, so only a fresh VM can see them.
a_type_only_atom_resolves_in_a_vm_that_did_not_compile_it_test() ->
    M = build_and_load(widget_src(), 'Widget'),
    Dir = bs_test_support:fixture_root(),
    {ok, _} = file:copy(code:which(M), filename:join(Dir, "Widget.beam")),
    ?assertEqual("zzz_type_only_mode", in_fresh_vm(Dir, M, "zzz_type_only_mode")),
    ?assertEqual("zzz_other_mode", in_fresh_vm(Dir, M, "zzz_other_mode")).

%% The discharge is one exported function on EVERY module, `'bs@type_atoms'/0`,
%% returning the sorted atoms its type positions name — an empty list where
%% there are none, so the surface is one shape (ticket 87). `Widget`'s three:
%% `Mode`'s two members, and `error` from `result<atom, string>`'s failure
%% tuple. `atom` itself is the cofinite top and names nothing.
every_module_exports_the_atoms_its_types_name_test() ->
    W = build_and_load(widget_src(), 'Widget'),
    ?assertEqual([error, zzz_other_mode, zzz_type_only_mode], W:'bs@type_atoms'()),
    P = build_and_load("module Plain\n"
                       "public int Inc(int n)\n"
                       "Inc(n) -> n + 1\n", 'Plain'),
    ?assertEqual([], P:'bs@type_atoms'()).

%% A declared type no signature names still counts, and so does every atom a
%% type names in KEY position: a record's field names and its minted `Kind`
%% are atoms the type spells. A parametric alias is walked with its variables
%% erased to `term`, as a polymorphic signature is, so its own literals are
%% collected without applying it (the review of F55 found both walks missing).
a_declared_but_unused_type_still_counts_keys_included_test() ->
    D = build_and_load("module Decl\n"
                       "record Point { X: int }\n"
                       "type Tagged<T> = :zzz_tagged | T\n"
                       "public int Inc(int n)\n"
                       "Inc(n) -> n + 1\n", 'Decl'),
    ?assertEqual(['Decl.Point', 'Kind', 'X', zzz_tagged], D:'bs@type_atoms'()).

%% A type that came in through `using` is a type position of THIS module, and
%% this module is the one a fresh VM may load alone: `Kinds.beam` is not on the
%% spawned VM's path, only `Uses.beam` is, and both members resolve. Neither
%% name is spelled as a value anywhere in `Uses`.
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
%%% F54.4 — the declared return must admit the failure member
%%% ---------------------------------------------------------------------------

%% Ticket 15 §1 is why the result is `result<atom, string>` and not
%% `option<atom>`: the singleton would be absorbed into the cofinite top and
%% the failure could not be matched. So the tagged member is in the result
%% whether the signature admits it or not, and a bare `atom` is a narrowing
%% the checker refuses — with F25's correction offering the member back.
a_return_type_without_the_failure_member_is_refused_test() ->
    Src = "module TeaNarrow\n"
          "public atom Go(string s)\n"
          "Go(s) -> ToExistingAtom(s)\n",
    [{error, _, 'Go', {return_not_declared, Undeclared, Corrected}}] = errors(Src),
    ?assertEqual(<<"(:error, string)">>,
                 iolist_to_binary(bs_types:to_string(Undeclared))),
    ?assertNotEqual(none, Corrected).

%%% ---------------------------------------------------------------------------
%%% F54.5 — the argument is a string, and this was a choice
%%% ---------------------------------------------------------------------------

%% `term` is the case that will actually happen: a value straight off a
%% boundary. `binary_to_existing_atom` on a non-binary is `badarg`, the same
%% failure a missing name raises, so a `term` argument would turn "that was
%% never a name" into "no atom has that name". Refused; the author matches
%% the term into a string first.
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

%% THE CHOICE, and where this differs from `ParseAtom<T>`, which admits a
%% `binary`. Here the argument flows into the result: the failure carries the
%% name as a `string`, and a `binary` that is not valid UTF-8 is not one. The
%% BIF agrees — `binary_to_existing_atom(<<255>>, utf8)` is `badarg` — so a
%% `binary` argument would make two failures one. A wire binary becomes a
%% `string` through `ValidateAs<string>`, which is the check the type names.
a_binary_argument_is_refused_test() ->
    Src = "module TeaArgBin\n"
          "public result<atom, string> Go(binary b)\n"
          "Go(b) -> ToExistingAtom(b)\n",
    ?assertMatch([{error, _, 'Go', {to_existing_atom_arg, _}}], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F54.6 — the construct's shape: no type argument, one value
%%% ---------------------------------------------------------------------------

%% The name stays in ticket 28's closed set, so `<` after it opens a bracket
%% rather than reading as a comparison — and what is in the bracket is then
%% refused, because this obligation has no `T`: its result is fixed. The tag
%% is `obligation_arity`, the same rule that refuses `ValidateAs<int, atom>`,
%% carrying what was written.
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
%%% F54.7 — the pipe form
%%% ---------------------------------------------------------------------------

%% F14's rewrite fills a call's first argument from the pipe, and it has to
%% fill it for a bare compiler-known call and not only for the bracket forms
%% it was measured on, so this is a running program rather than a grammar fact.
the_pipe_form_resolves_the_piped_string_test() ->
    Src = "module TeaPipe\n"
          "public result<atom, string> Go(string s)\n"
          "Go(s) -> s |> ToExistingAtom()\n",
    M = build_and_load(Src, 'TeaPipe'),
    ?assertEqual(ok, M:'Go'(<<"ok">>)),
    ?assertEqual({error, <<"zzz_piped_absent">>}, M:'Go'(<<"zzz_piped_absent">>)).

%%% ---------------------------------------------------------------------------
%%% F54.8 — the name is compiler-known, so a user may not declare it
%%% ---------------------------------------------------------------------------

%% A bare `ToExistingAtom(s)` is read by the checker before any user function
%% is looked up, so a user's `ToExistingAtom/1` would be shadowed in silence.
%% The rule is `ValidationError`'s (F18): a compiler-known name cannot be
%% redeclared, and the refusal lands at the declaration.
redeclaring_the_name_as_a_function_is_refused_test() ->
    Src = "module TeaShadow\n"
          "public atom ToExistingAtom(string s)\n"
          "ToExistingAtom(s) -> :nope\n",
    ?assertError({compiler_known_function, 'ToExistingAtom', _}, check_only(Src)).

%% TWO SITES. `bsc --api` runs the declaration pass through `exports_of/2`,
%% never `check/2`, so a refusal wired at one prints a signature as fact from
%% the other — the gap ENG-371 records for two older refusals, and F31's,
%% F40's and F50's sentence for a fourth time.
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
%%% F54.9 — reading the result: a switch over `result<atom, string>`
%%% ---------------------------------------------------------------------------

%% What a caller does with the answer. The failure is a value, so handling it
%% is an arm and not a rescue, and the residual after `(:error, _)` is `atom`,
%% which the binder takes whole.
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
%%% F54.10 — the new sentences, as the AUTHOR receives them
%%% ---------------------------------------------------------------------------

%% `validate_as_tests` states the case for this block: `check-diagnostics.sh`
%% compares tag SETS, so a `message/1` clause that never dispatches leaves
%% the gate green and the author holding a map. So `bsc` runs as a subprocess
%% and the sentence is looked for on one line.
%%
%% The `obligation_arity` case is the one with teeth. That message ends
%% "Write `Name<T>(x)`", and for this name that is advice to write the form
%% the same compiler just refused — F19's shape, which `check-advice-compiles`
%% exists for. The fragment asserts the message says what this name takes.
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
     %% The roster `not_an_obligation` prints was written by hand in
     %% `bs_diag` and named three obligations for six days after F50 made it
     %% four. It reads the checker's list now, and the sentence names all of
     %% them.
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
