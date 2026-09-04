-module(bs_process).

-export([run_merged/1]).

%% The shell parses the command strings already used by the compiler and its
%% boundary suite. `exec` replaces that shell, so the port reports the spawned
%% program's status rather than a status marker mixed into its output.
run_merged(Command) ->
    Port = open_port({spawn_executable, "/bin/sh"},
                     [binary, exit_status, stderr_to_stdout, use_stdio,
                      {args, ["-c", "exec " ++ Command]}]),
    collect(Port, []).

collect(Port, Chunks) ->
    receive
        {Port, {data, Data}} ->
            collect(Port, [Data | Chunks]);
        {Port, {exit_status, Status}} ->
            Output = iolist_to_binary(lists:reverse(Chunks)),
            {Status, binary_to_list(Output)}
    end.
