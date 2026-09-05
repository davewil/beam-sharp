-module(bs_process).

-export([run_merged/1, run_merged_with_pid/1]).

%% The shell parses the command strings already used by the compiler and its
%% boundary suite. `exec` replaces that shell, so the port reports the spawned
%% program's status rather than a status marker mixed into its output.
run_merged(Command) ->
    {Status, Output, _OsPid} = run_merged_with_pid(Command),
    {Status, Output}.

%% The same run, also reporting the OS pid the child ran under. Because the
%% shell `exec`s the command, and `env` and `escript` exec in turn, that pid is
%% the one the program sees in `os:getpid()` — measured 2026-09-05 for ENG-318,
%% whose boundary test asserts a scratch path against it. Read before the port
%% closes: `port_info/2` on a closed port is `undefined`.
run_merged_with_pid(Command) ->
    Port = open_port({spawn_executable, "/bin/sh"},
                     [binary, exit_status, stderr_to_stdout, use_stdio,
                      {args, ["-c", "exec " ++ Command]}]),
    {os_pid, OsPid} = erlang:port_info(Port, os_pid),
    {Status, Output} = collect(Port, []),
    {Status, Output, OsPid}.

collect(Port, Chunks) ->
    receive
        {Port, {data, Data}} ->
            collect(Port, [Data | Chunks]);
        {Port, {exit_status, Status}} ->
            Output = iolist_to_binary(lists:reverse(Chunks)),
            {Status, binary_to_list(Output)}
    end.
