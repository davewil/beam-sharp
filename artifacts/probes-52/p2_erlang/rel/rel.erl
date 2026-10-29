-module(rel).
-export([main/0]).
%% systools checks the .app 'applications' key against the release's app list, never the call sites.
main() ->
  Base = filename:absname("a"), filelib:ensure_dir("a/appa/ebin/x"), file:write_file("a/appa/ebin/appa.app", "{application,appa,[{description,\"d\"},{vsn,\"1\"},{modules,[]},{registered,[]},{applications,[kernel,stdlib]}]}.\n"),
  Path = [Base ++ "/appa/ebin"],
  file:write_file("r1.rel", io_lib:format("~p.~n", [{release,{"r1","1"},{erts,"13.2.2.5"},[{kernel,"8.5.4.2"},{stdlib,"4.3.1.3"},{appa,"1"}]}])),
  io:format("release with appa (applications=[kernel,stdlib]): ~p~n", [systools:make_script("r1", [silent,{path,Path}])]),
  %% appc declares applications [kernel,stdlib,ghostdep], release omits ghostdep
  filelib:ensure_dir("c/ebin/x"),
  file:write_file("c/ebin/appc.app", "{application,appc,[{description,\"d\"},{vsn,\"1\"},{modules,[]},{registered,[]},{applications,[kernel,stdlib,ghostdep]}]}.\n"),
  file:write_file("r2.rel", io_lib:format("~p.~n", [{release,{"r2","1"},{erts,"13.2.2.5"},[{kernel,"8.5.4.2"},{stdlib,"4.3.1.3"},{appc,"1"}]}])),
  io:format("release with appc needing ghostdep: ~p~n", [systools:make_script("r2", [silent,{path,["c/ebin"]}])]).
