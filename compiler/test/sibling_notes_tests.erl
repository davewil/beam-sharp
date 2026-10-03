%%% ENG-576 — a module is a directory, so two of its files may hold a node at
%%% the same line and column, and each file numbers its valves from one. What
%%% the checker decides about a node in one file must not reach its sibling's.
%%%
%%% Each program below is one module in two files, written so that a node in
%%% the second file sits where the first file's does. Every test runs the
%%% module through `bsc` and reads what it prints.
-module(sibling_notes_tests).

-include_lib("eunit/include/eunit.hrl").

%%% Helpers: fixtures live under module paths in an isolated source root.

run(Files, Call) ->
    Root = bs_test_support:fixture_root(),
    Paths = [bs_test_support:place(Root, N, S) || {N, S} <- Files],
    bs_test_support:run_cli("--src-root " ++ Root ++ " " ++ hd(Paths) ++ " " ++ Call).

%% The whole of what a run printed before its exit status.
prints(Got, Value) -> ?assertEqual(Value ++ "\nrc:0\n", Got).

%% `/` between two floats is the BEAM's `/`, and between two ints its `div`.
%% The float pair in one file left the int pair in the other dividing as
%% floats: `Boxes`, declared `int`, answered `3.5`.
an_int_division_beside_a_float_one_stays_whole_test() ->
    Files = [{"ratio.bs",
              "module Shop.Split\n"
              "public float Ratio(float x, float y)\n"
              "Ratio(x, y) -> x / y\n"},
             {"boxes.bs",
              "module Shop.Split\n"
              "public int Boxes(int x, int y)\n"
              "Boxes(x, y) -> x / y\n"}],
    prints(run(Files, "Boxes 7 2"), "3"),
    prints(run(Files, "Ratio 7.0 2.0"), "3.5").

%% `d.Reason` on a `Down` reads a tuple position; on a record it reads a key.
%% The view's position reached the record's projection in the sibling file.
a_record_projection_beside_a_views_reads_its_key_test() ->
    Files = [{"watch.bs",
              "module Shop.Jobs\n"
              "record Job { Reason: string }\n"
              "public term Why(Down d)\n"
              "Why(d) -> d.Reason\n"},
             {"job.bs",
              "module Shop.Jobs\n"
              "\n"
              "public string Got(Job j)\n"
              "Got(j) -> j.Reason\n"
              "public string Demo()\n"
              "Demo() -> Got(Job { Reason = \"late\" })\n"}],
    prints(run(Files, "Demo"), "\"late\"").

%% A protocol call goes to the implementation of the record it is given. Two
%% calls at one position, over two records, both went to one implementation.
a_protocol_call_reaches_its_own_records_implementation_test() ->
    Files = [{"basket.bs",
              "module Shop.Hold\n"
              "record Basket { Items: list<int> }\n"
              "implements Enumerable<int> for Basket {\n"
              "    Reduce(Basket b, acc, f) -> List.Fold(b.Items, acc, f)\n"
              "}\n"
              "public int InBasket(Basket s)\n"
              "InBasket(s) -> Enumerable.Reduce(s, 0, (a, v) => a + v)\n"},
             {"crate.bs",
              "module Shop.Hold\n"
              "record Crate { Boxes: list<int> }\n"
              "implements Enumerable<int> for Crate {\n"
              "    Reduce(Crate c, acc, f) -> List.Fold(c.Boxes, acc, f)\n"
              "}\n"
              "public int InCrates(Crate s)\n"
              "InCrates(s) -> Enumerable.Reduce(s, 0, (a, v) => a + v)\n"
              "public int Demo()\n"
              "Demo() -> InBasket(Basket { Items = [1, 2] })"
              " + InCrates(Crate { Boxes = [10] })\n"}],
    prints(run(Files, "Demo"), "13").

%% A bare name in value position is the function it resolves to. Two names at
%% one position, in two files, resolved to one function.
a_bare_name_resolves_in_its_own_file_test() ->
    Files = [{"double.bs",
              "module Shop.Scale\n"
              "private int Double(int n)\n"
              "Double(n) -> n * 2\n"
              "public list<int> Doubled(list<int> xs)\n"
              "Doubled(xs) -> List.Map(xs, Double)\n"},
             {"triple.bs",
              "module Shop.Scale\n"
              "private int Triple(int n)\n"
              "Triple(n) -> n * 3\n"
              "public list<int> Tripled(list<int> xs)\n"
              "Tripled(xs) -> List.Map(xs, Triple)\n"}],
    prints(run(Files, "Doubled '[1,2]'"), "[2, 4]"),
    prints(run(Files, "Tripled '[1,2]'"), "[3, 6]").

%% The valve drops a stop arm its subject can never reach. The first valve of
%% each file carries the same generated name, so the arm one file's subject
%% cannot reach was dropped from the other's, whose subject can.
a_valve_keeps_the_stop_arm_its_own_subject_reaches_test() ->
    Files = [{"place.bs",
              "module Shop.Stock\n"
              "type Res = int | (:error, atom)\n"
              "private Res Start(int n)\n"
              "Start(n) when n > 0  -> n\n"
              "Start(n) when n <= 0 -> (:error, :bad)\n"
              "private Res Charge(int v)\n"
              "Charge(v) -> v * 2\n"
              "public Res Place(int n)\n"
              "Place(n) -> Start(n) |?> Charge()\n"},
             {"load.bs",
              "module Shop.Stock\n"
              "type Maybe = int | :nothing\n"
              "private Maybe Fetch(int id)\n"
              "Fetch(0) -> :nothing\n"
              "Fetch(n) -> n\n"
              "private Maybe Double(int v)\n"
              "Double(v) -> v * 2\n"
              "public Maybe Load(int id)\n"
              "Load(id) -> Fetch(id) |?> Double()\n"}],
    prints(run(Files, "Place 0"), "(:error, :bad)"),
    prints(run(Files, "Place 4"), "8"),
    prints(run(Files, "Load 0"), ":nothing"),
    prints(run(Files, "Load 4"), "8").
