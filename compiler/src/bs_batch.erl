%%% bs_batch — many `bsc` invocations, one VM.
%%%
%%%     bsc --batch MANIFEST RESULTS
%%%
%%% Every entry of a manifest runs in this one VM, and each gets exactly the
%%% files a `bsc` process of its own would have written. A VM boot is a fixed
%%% cost per invocation, and no invocation needs a VM of its own (ENG-314).
%%%
%%% The manifest is line-framed, one argument per line:
%%%
%%%     entry <id>
%%%     cwd <directory>          optional, at most one
%%%     arg <text>               one per argument, `arg` alone is an empty one
%%%     end
%%%
%%% A newline is the argument boundary, so there is no quoting rule and no
%%% shell between the manifest and the compiler: an `arg` line saying
%%% `; touch pwned` reaches `bsc` as one argument. An argument therefore
%%% cannot contain a newline.
%%%
%%% Each entry gets `RESULTS/<id>.stdout`, `.stderr`, `.output` (both streams
%%% in write order, as `2>&1` would deliver them) and `.status`.
%%%
%%% A malformed manifest runs nothing: the whole file is read before the
%%% first entry runs, and a line the reader cannot place fails the batch with
%%% its number and exit status 2, leaving no result files at all. So a missing
%%% `<id>.status` is the one shape a partial run can have.
%%%
%%% Between entries the VM is restored by hand: the working directory, the
%%% code path, and every module an entry loaded. The last one matters most,
%%% because `code:ensure_loaded/1` is a no-op for a module already present, so
%%% a stale module would run an earlier entry's code rather than fail. The
%%% process dictionary needs no restoring: each entry runs in its own process.
-module(bs_batch).

-export([run/2]).

%% Returns the batch's exit status: 0 when the manifest read and every entry
%% ran, whatever each entry's own status was; 2 when it could not start or
%% could not restore the VM between two entries (see `run_entries/2`).
run(ManifestPath, ResultsDir) ->
    try run_1(ManifestPath, ResultsDir)
    catch
        Class:Reason ->
            io:format(standard_error, "bsc: the batch stopped: ~w:~p~n", [Class, Reason]),
            2
    end.

run_1(ManifestPath, ResultsDir) ->
    case read_manifest(ManifestPath) of
        {error, Line, Reason} ->
            %% `~ts`, not `~s`: the reasons carry an em dash, and the path may
            %% carry anything. `~s` raises on a character above 255.
            io:format(standard_error,
                      "bsc: ~ts:~p: ~ts~n"
                      "  a batch runs nothing until every entry reads. The manifest is~n"
                      "  `entry ID`, an optional `cwd DIR`, one `arg TEXT` per argument~n"
                      "  and `end`, with blank lines only between entries.~n",
                      [ManifestPath, Line, Reason]),
            2;
        {ok, Entries} ->
            case filelib:ensure_dir(filename:join(ResultsDir, "x")) of
                {error, R} ->
                    io:format(standard_error, "bsc: cannot create ~ts: ~p~n",
                              [ResultsDir, R]),
                    2;
                ok ->
                    preload_own_modules(),
                    case run_entries(Entries, ResultsDir) of
                        ok           -> 0;
                        {error, Why} -> io:format(standard_error, "bsc: ~ts~n", [Why]), 2
                    end
            end
    end.

%%% ---------------------------------------------------------------------------
%%% Reading the manifest
%%% ---------------------------------------------------------------------------

read_manifest(Path) ->
    case file:read_file(Path) of
        {error, R} ->
            {error, 0, io_lib:format("cannot read the manifest: ~p", [R])};
        {ok, Bin} ->
            case unicode:characters_to_list(Bin, utf8) of
                Text when is_list(Text) ->
                    parse(string:split(Text, "\n", all), 1, outside, [], []);
                _ ->
                    {error, 0, "the manifest is not UTF-8"}
            end
    end.

%% `State` is `outside` between entries or `{in, Id, Cwd, ArgsReversed}`.
parse([], _N, outside, Acc, _Seen) ->
    {ok, lists:reverse(Acc)};
parse([], N, {in, Id, _, _}, _Acc, _Seen) ->
    {error, N, io_lib:format("the manifest ended inside entry `~ts` — no `end`", [Id])};
parse([Line | Rest], N, State, Acc, Seen) ->
    case {classify(Line), State} of
        {blank, outside} ->
            parse(Rest, N + 1, outside, Acc, Seen);
        {blank, {in, Id, _, _}} ->
            {error, N, io_lib:format("a blank line inside entry `~ts`", [Id])};
        {{entry, Id}, outside} ->
            case {valid_id(Id), lists:member(Id, Seen)} of
                {false, _} ->
                    {error, N, io_lib:format("`~ts` is not an id — letters, digits, `_`, `.` and `-`, starting with a letter, digit or `_`", [Id])};
                {true, true} ->
                    {error, N, io_lib:format("entry `~ts` is named twice, so its results would overwrite each other", [Id])};
                {true, false} ->
                    parse(Rest, N + 1, {in, Id, undefined, []}, Acc, [Id | Seen])
            end;
        {{entry, _}, {in, Id, _, _}} ->
            {error, N, io_lib:format("`entry` before entry `~ts` has its `end`", [Id])};
        {{cwd, Dir}, {in, Id, undefined, Args}} ->
            case filelib:is_dir(Dir) of
                true  -> parse(Rest, N + 1, {in, Id, Dir, Args}, Acc, Seen);
                false -> {error, N, io_lib:format("cwd names no directory: ~ts", [Dir])}
            end;
        {{cwd, _}, {in, Id, _, _}} ->
            {error, N, io_lib:format("a second `cwd` in entry `~ts`", [Id])};
        {{arg, A}, {in, Id, Cwd, Args}} ->
            parse(Rest, N + 1, {in, Id, Cwd, [A | Args]}, Acc, Seen);
        {'end', {in, Id, Cwd, Args}} ->
            Entry = #{id => Id, cwd => Cwd, args => lists:reverse(Args)},
            parse(Rest, N + 1, outside, [Entry | Acc], Seen);
        {'end', outside} ->
            {error, N, "`end` outside any entry — `entry ID` opens one"};
        {{cwd, _}, outside} ->
            {error, N, "`cwd` outside any entry — `entry ID` opens one"};
        {{arg, _}, outside} ->
            {error, N, "`arg` outside any entry — `entry ID` opens one"};
        {other, _} ->
            {error, N, "not a manifest line — expected `entry ID`, `cwd DIR`, `arg TEXT` or `end`"}
    end.

classify("")            -> blank;
classify("end")         -> 'end';
classify("arg")         -> {arg, ""};
classify("entry " ++ I) -> {entry, I};
classify("cwd " ++ D)   -> {cwd, D};
classify("arg " ++ A)   -> {arg, A};
classify(_)             -> other.

%% The id names four files, so it is restricted to what is safe in a file name
%% on every platform the gates run on — and cannot be `.` or `..`.
valid_id(Id) ->
    re:run(Id, "^[A-Za-z0-9_][A-Za-z0-9_.-]*$", [{capture, none}]) =:= match.

%%% ---------------------------------------------------------------------------
%%% Running an entry
%%% ---------------------------------------------------------------------------

%% Failing to enter an entry's `cwd` is that entry's problem: it is recorded
%% as status 127 with the reason on its stderr, and the batch goes on.
%% Failing to restore the VM afterwards is every later entry's problem, since
%% they would run from the wrong directory, a stale code path or another
%% entry's module and write wrong files rather than none. So that stops the
%% batch: `run/2` says why and exits 2, and the entries after it have no
%% files. The entry's own run needs neither: `bs_capture:run/2` turns a crash
%% into an outcome.
run_entries([], _ResultsDir) -> ok;
run_entries([E | Rest], ResultsDir) ->
    case run_entry(E, ResultsDir) of
        ok           -> run_entries(Rest, ResultsDir);
        {error, Why} -> {error, Why}
    end.

run_entry(#{id := Id, cwd := Cwd, args := Args}, ResultsDir) ->
    {ok, Cwd0} = file:get_cwd(),
    Path0 = code:get_path(),
    Loaded0 = code:all_loaded(),
    {Outcome, {Out, Err, Merged}} =
        case enter(Cwd) of
            ok ->
                bs_capture:run(fun() -> bsc:status(Args, batch) end, infinity);
            {error, Reason} ->
                {{crashed, error, {cannot_enter, Cwd, Reason}}, {<<>>, <<>>, <<>>}}
        end,
    {Status, Err1, Merged1} =
        case Outcome of
            {ok, N} when is_integer(N) ->
                {N, Err, Merged};
            {crashed, Class, Detail} ->
                %% A standalone escript dies with this line and status 127. The
                %% VM survives here, so the entry gets the same two facts.
                Crash = unicode:characters_to_binary(
                          io_lib:format("escript: exception ~w: ~p~n", [Class, Detail])),
                {127, <<Err/binary, Crash/binary>>, <<Merged/binary, Crash/binary>>}
        end,
    write(ResultsDir, Id, "stdout", Out),
    write(ResultsDir, Id, "stderr", Err1),
    write(ResultsDir, Id, "output", Merged1),
    write(ResultsDir, Id, "status", integer_to_list(Status) ++ "\n"),
    restore(Cwd0, Path0, Loaded0).

enter(undefined) -> ok;
enter(Cwd)       -> file:set_cwd(Cwd).

restore(Cwd0, Path0, Loaded0) ->
    try
        ok = file:set_cwd(Cwd0),
        [code:del_path(D) || D <- code:get_path() -- Path0],
        unload_new(Loaded0),
        ok
    catch
        Class:Reason ->
            {error, io_lib:format("the VM could not be restored after an entry (~w:~p),~n"
                                  "  so the entries after it did not run and have no result files",
                                  [Class, Reason])}
    end.

write(Dir, Id, Ext, Data) ->
    ok = file:write_file(filename:join(Dir, Id ++ "." ++ Ext), Data).

%% The compiler's own modules are loaded before the first entry, so the entry
%% that first reaches `bs_run` or `bs_repl` does not see it purged at its end.
%% `unload_new/1` also refuses to touch anything under the escript or OTP.
preload_own_modules() ->
    case application:load(bsc) of
        ok -> ok;
        {error, {already_loaded, bsc}} -> ok;
        _ -> ok
    end,
    case application:get_key(bsc, modules) of
        {ok, Mods} -> [code:ensure_loaded(M) || M <- Mods], ok;
        undefined  -> ok
    end.

unload_new(Loaded0) ->
    Root = code:root_dir(),
    Own = try escript:script_name() catch _:_ -> undefined end,
    New = [M || {M, Where} <- code:all_loaded(),
                not lists:keymember(M, 1, Loaded0),
                is_list(Where),
                not lists:prefix(Root, Where),
                Own =:= undefined orelse not lists:prefix(Own, Where)],
    lists:foreach(fun(M) -> code:purge(M), code:delete(M), code:purge(M) end, New).
