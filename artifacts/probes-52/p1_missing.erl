%% p1: what a missing dependency looks like at run time (and what code:/application: say)
-module(p1_missing).
-export([main/0]).
main() ->
  p("call a module that exists nowhere", catch 'Elixir.Req':new([])),
  p("same via apply", catch apply('Elixir.Req', new, [[]])),
  p("code:which", code:which('Elixir.Req')),
  p("code:ensure_loaded", code:ensure_loaded('Elixir.Req')),
  p("code:is_loaded", code:is_loaded('Elixir.Req')),
  p("code:lib_dir(req)", code:lib_dir(req)),
  p("application:load(req)", application:load(req)),
  p("application:ensure_all_started(req)", application:ensure_all_started(req)),
  p("application:get_application(Elixir.Req)", application:get_application('Elixir.Req')),
  p("erlang:function_exported (module not loaded)", erlang:function_exported('Elixir.Req', new, 1)),
  %% undef in a spawned process: shape of the crash report / exit reason
  {Pid, Ref} = spawn_monitor(fun() -> 'Elixir.Req':new([]) end),
  receive {'DOWN', Ref, _, Pid, R} -> p("exit reason of process", R) end,
  %% fake app on a path: .app lists a dependency that does not exist
  Base = "/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/probes/52/fakelibs",
  ok = filelib:ensure_dir(Base ++ "/fakeapp/ebin/x"),
  ok = file:write_file(Base ++ "/fakeapp/ebin/fakeapp.app",
     "{application,fakeapp,[{vsn,\"1.0.0\"},{modules,[]},{registered,[]},{applications,[kernel,stdlib,ghostdep]}]}.\n"),
  true = code:add_pathz(Base ++ "/fakeapp/ebin"),
  p("code:lib_dir(fakeapp) after add path", code:lib_dir(fakeapp)),
  p("application:load(fakeapp)", application:load(fakeapp)),
  p("application:ensure_all_started(fakeapp)", application:ensure_all_started(fakeapp)),
  p("application:load(ghostdep)", application:load(ghostdep)),
  ok = file:write_file(Base ++ "/fakeapp/ebin/fakeapp.app",
     "{application,fakeapp,[{vsn,\"1.0.0\"},{modules,[]},{registered,[]},{applications,[kernel,stdlib]}]}.\n"),
  application:unload(fakeapp),
  p("control: after fixing .app, ensure_all_started", application:ensure_all_started(fakeapp)),
  %% .app exists but modules missing .beam
  p("code:which(module named in .app but no beam)", code:which(fakeapp_mod)).
p(L, V) -> io:format("~-55s ~p~n", [L, V]).
