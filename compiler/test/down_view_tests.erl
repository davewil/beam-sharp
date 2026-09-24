%%% Scenarios: compiler/features/F60-down-and-exit.md
%%% F60 — `Down` and `Exit` are named views of the tuples OTP sends; `pid`,
%%% `reference` and `port` are types.
%%%
%%% A view names the positions of a tuple the platform sends, so a handler
%%% matches `Down { Ref: r, Reason: why }` by name, in any order, and cannot get
%%% the arity wrong. Every message here is a real one: a monitored process dies,
%%% or a linked one exits while the test traps exits.

-module(down_view_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, errors/1, check_only/1]).

tags(Src) -> [element(1, element(4, E)) || E <- errors(Src)].

down_of(ExitReason) ->
    {Pid, Ref} = spawn_monitor(fun() -> exit(ExitReason) end),
    receive {'DOWN', Ref, process, Pid, _} = M -> M end.

exit_of(ExitReason) ->
    Old = process_flag(trap_exit, true),
    Pid = spawn_link(fun() -> exit(ExitReason) end),
    M = receive {'EXIT', Pid, _} = X -> X end,
    process_flag(trap_exit, Old),
    M.

%% F60.1 — `pid`, `reference` and `port` are types. An identity function
%% passes its argument through, as one over `binary` does; `ValidateAs` decides
%% each kind with its one guard.
opaque_types_are_types_test() ->
    M = build_and_load("module View1\n"
                       "public pid P(pid p)\n"
                       "P(p) -> p\n"
                       "public reference R(reference r)\n"
                       "R(r) -> r\n"
                       "public result<pid, ValidationError> V(term t)\n"
                       "V(t) -> ValidateAs<pid>(t)\n", 'View1'),
    Self = self(),
    Ref = make_ref(),
    ?assertEqual(Self, M:'P'(Self)),
    ?assertEqual(Ref, M:'R'(Ref)),
    ?assertEqual(Self, M:'V'(Self)),
    ?assertMatch({error, #{'Expected' := <<"pid">>}}, M:'V'(Ref)).

%% F60.2 — a foreign return may promise `pid`: one guard decides it.
a_foreign_pid_is_guarded_test() ->
    M = build_and_load("module View2\n"
                       "using :erlang {\n"
                       "    pid self()\n"
                       "}\n"
                       "public pid Me(int n)\n"
                       "Me(n) -> :erlang.self()\n", 'View2'),
    ?assertEqual(self(), M:'Me'(1)).

down_src() ->
    "module View3\n"
    "public atom What(term m)\n"
    "What(Down { Reason: :normal })              -> :normal\n"
    "What(Down { Reason: why, Type: :process })  -> :crashed\n"
    "What(m)                                     -> :other\n"
    "public term Why(Down d)\n"
    "Why(Down { Ref: r } d) -> d.Reason\n".

%% F60.3 — a real `DOWN` matches by name; parts may be named in any order.
a_down_matches_by_name_test() ->
    M = build_and_load(down_src(), 'View3'),
    ?assertEqual(normal, M:'What'(down_of(normal))),
    ?assertEqual(crashed, M:'What'(down_of(boom))),
    ?assertEqual(other, M:'What'({'DOWN', stray})).

%% F60.4 — `d.Reason` reads the part from a bound `Down`.
a_bound_down_projects_its_parts_test() ->
    M = build_and_load(down_src(), 'View3'),
    ?assertEqual(boom, M:'Why'(down_of(boom))).

%% F60.5 — the views cover a `Down`-typed parameter with no catch-all, and a
%% missing case is reported.
a_down_parameter_is_covered_by_views_test() ->
    Src = fun(Extra) ->
              "module View5\n"
              "public atom F(Down d)\n"
              "F(Down { Reason: :normal }) -> :normal\n" ++ Extra
          end,
    ?assertMatch({ok, _, _}, check_only(Src("F(Down { Reason: why }) -> :crashed\n"))),
    ?assertEqual([inexhaustive], tags(Src(""))).

%% F60.6 — a four-element DOWN clause against a `Down` parameter matches no
%% value, and is reported as any such clause is, a `vacuous_clause` warning.
a_misshaped_down_clause_is_reported_test() ->
    {ok, _, Warnings} = check_only("module View6\n"
                                   "public atom F(Down d)\n"
                                   "F((:'DOWN', r, :process, why)) -> :four\n"
                                   "F(Down { Reason: why })        -> :five\n"),
    ?assertMatch([{warning, _, 'F', {vacuous_clause, 1, _}}], Warnings).

%% F60.7 — a part the view does not have is refused, naming the view.
an_unknown_part_is_refused_test() ->
    {'EXIT', {{pattern_field_unknown, _, 'Down', 'Pidd', _}, _}} =
        catch check_only("module View7\n"
                         "public atom F(Down d)\n"
                         "F(Down { Pidd: p }) -> :x\n").

%% F60.8 — `Exit` is a view of `{'EXIT', Pid, Reason}`.
an_exit_matches_by_name_test() ->
    M = build_and_load("module View8\n"
                       "public term Why(term m)\n"
                       "Why(Exit { Pid: p, Reason: why }) -> why\n"
                       "Why(m)                            -> :other\n", 'View8'),
    ?assertEqual(boom, M:'Why'(exit_of(boom))),
    ?assertEqual(other, M:'Why'(stray)).

%% F60.9 — a view is compiler-known: it cannot be redeclared.
a_view_cannot_be_redeclared_test() ->
    {'EXIT', {{compiler_known_type, 'Down', _}, _}} =
        catch check_only("module View9\n"
                         "type Down = int\n"
                         "public int F(int n)\n"
                         "F(n) -> n\n").

%% F60.10 — a user cannot construct one: a view is only matched.
a_view_cannot_be_constructed_test() ->
    ?assertEqual([view_constructed],
                 tags("module View10\n"
                      "public Down Make(reference r)\n"
                      "Make(r) -> Down { Ref = r, Type = :process, Object = :x, Reason = :normal }\n")).

%% F60.11 — the residual names the view, in the diagnostic an author reads:
%% only the parts narrowed below what the view declares.
the_residual_prints_the_view_test_() ->
    {timeout, 60,
     fun() ->
         bs_test_support:with_src("view.bs",
             "module View11\n"
             "public atom F(Down d)\n"
             "F(Down { Reason: :normal }) -> :normal\n",
             fun(Path, _Out) ->
                 {_, Output} = bs_test_support:run_cli_result(Path),
                 ?assertNotEqual(nomatch, string:find(Output, "F(Down { Reason: ")),
                 ?assertEqual(nomatch, string:find(Output, "'DOWN'"))
             end)
     end}.

%% F60.12 — a pid has no wire form, so `ToJson` refuses it.
to_json_refuses_a_pid_test() ->
    {'EXIT', {{unencodable_member, _, 'Body', _, _, _, opaque}, _}} =
        catch check_only("module View12\n"
                         "public string Body(pid p)\n"
                         "Body(p) -> ToJson<pid>(p)\n").


%% F60.13 — a bare prefix binds the whole view and tests all of its shape.
a_bare_prefix_binds_the_view_test() ->
    M = build_and_load("module View13\n"
                       "public atom F(term m)\n"
                       "F(Down d) -> :down\n"
                       "F(m)      -> :other\n", 'View13'),
    ?assertEqual(down, M:'F'(down_of(normal))),
    ?assertEqual(other, M:'F'({'DOWN', x})),
    ?assertEqual(other, M:'F'({'DOWN', 1, 2, 3, 4, 5})).

%% F60.14 — a residual names only the parts narrowed below what the view
%% declares, which is where the printer's part types and the checker's must agree:
%% a part they disagreed on would print although no clause narrowed it.
a_residual_names_only_the_narrowed_part_test_() ->
    {timeout, 60,
     fun() ->
         bs_test_support:with_src("view14.bs",
             "module View14\n"
             "public atom D(Down m)\n"
             "D(Down { Reason: :normal }) -> :n\n"
             "public atom E(Exit m)\n"
             "E(Exit { Reason: :normal }) -> :e\n",
             fun(Path, _Out) ->
                 {_, Output} = bs_test_support:run_cli_result(Path),
                 ?assertNotEqual(nomatch, string:find(Output, "D(Down { Reason: ")),
                 ?assertNotEqual(nomatch, string:find(Output, "E(Exit { Reason: ")),
                 [?assertEqual(nomatch, string:find(Output, Part))
                  || Part <- ["Ref:", "Type:", "Object:", "Pid:"]]
             end)
     end}.

%% F60.15 — `with` over a view builds a new one, so it is refused as a
%% construction is.
a_view_cannot_be_updated_test() ->
    ?assertEqual([view_constructed],
                 tags("module View15\n"
                      "public Down Bump(Down d)\n"
                      "Bump(d) -> d with { Reason = :x }\n")).

%% F60.16 — a switch arm matches a view as a clause head does.
a_switch_arm_matches_a_view_test() ->
    M = build_and_load("module View16\n"
                       "public atom K(Down | (:ok, int) m)\n"
                       "K(m) -> m switch { Down { Reason: :normal } => :normal, "
                       "Down d => :down, (:ok, _) => :ok }\n", 'View16'),
    ?assertEqual(normal, M:'K'(down_of(normal))),
    ?assertEqual(down, M:'K'(down_of(boom))),
    ?assertEqual(ok, M:'K'({ok, 1})).

%% F60.17 — an undeclared part is refused naming the parts the view has, the
%% list under its heading with no stray line.
an_unknown_part_lists_the_declared_ones_test_() ->
    {timeout, 60,
     fun() ->
         bs_test_support:with_src("view17.bs",
             "module View17\n"
             "public term I(Down d)\n"
             "I(Down { Info: i }) -> i\n",
             fun(Path, _Out) ->
                 {_, Output} = bs_test_support:run_cli_result(Path),
                 ?assertNotEqual(nomatch,
                                 string:find(Output, "  Down declares:\n    Ref, Type, Object, Reason\n"))
             end)
     end}.
