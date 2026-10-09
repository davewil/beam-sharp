#!/usr/bin/env bash
# P18: Option 3's check lives OUTSIDE compilation: read bs@needs/0 from the emitted beams, ask the code server.
# Compile once with the prototype (check off, so the verdict is environment-pure), then check the apps in two environments.
PROTO=/tmp/bsb_52_x/ebin; LIBS=/usr/lib/elixir/lib
W=$(mktemp -d); cd "$W"; mkdir -p App
printf "module App\nusing :'Elixir.Enum' in :elixir {\n    int count(list<term> xs)\n}\nusing :lists in :stdlib {\n    int sum(list<int> xs)\n}\npublic int Go(list<term> xs)\nGo(xs) -> :'Elixir.Enum'.count(xs) + :lists.sum([1])\n" > App/a.bs
BSB_DEP_CHECK=off ERL_LIBS= erl -noshell -pa $PROTO -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra -o out App/a.bs
cat > needs.escript <<'X'
#!/usr/bin/env escript
main([Dir]) ->
    code:add_patha(Dir),
    [begin M = list_to_atom(filename:basename(F, ".beam")), {module, M} = code:ensure_loaded(M),
           case erlang:function_exported(M, 'bs@needs', 0) of
               false -> io:format("~s: declares no applications~n", [M]);
               true  -> [io:format("~s needs ~s: ~s~n", [M, A,
                                   case code:lib_dir(A) of {error, _} -> "MISSING"; D -> "found at " ++ D end])
                         || A <- M:'bs@needs'()]
           end end || F <- filelib:wildcard(Dir ++ "/*.beam")].
X
echo "--- ERL_LIBS set";   ERL_LIBS=$LIBS escript needs.escript out
echo "--- ERL_LIBS unset (expect elixir MISSING; stdlib found)"; ERL_LIBS= escript needs.escript out
