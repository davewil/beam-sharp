-module(bs_process).

-export([run_merged/1, run_merged_with_pid/1]).

%% Run a shell command; return its exit status with stdout and stderr merged.
%% The shell `exec`s the command, so the status is the program's own rather
%% than a marker mixed into its output.
run_merged(Command) ->
    {Status, Output, _OsPid} = run_merged_with_pid(Command),
    {Status, Output}.

%% The same run, also reporting the pid the program sees in `os:getpid()`: the
%% shell, `env` and `escript` all exec, so no intermediate pid survives
%% (ENG-318). The pid must be read before the port closes, because
%% `port_info/2` on a closed port is `undefined`.
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
