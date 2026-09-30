#!/usr/bin/env bash
# p15: does naming the DIRECT application suffice?  libdep.app lists `applications: [kernel,stdlib,elixir,logger]`;
# libdep's Elixir code calls Enum.  Run the B# program with only libdep reachable, then with Elixir's lib dir too;
# and walk the .app `applications` closure the way a compile-time check could.
cd "$(dirname "$0")"
LD=/tmp/mixdeps52b/consumer/_build/dev/lib
echo '--- A. only libdep reachable: the declared application is present'
ERL_LIBS=$LD ./bsc.sh --src-root programs programs/Total Sum "[1,2,3]"; echo "exit=$?"
echo '--- B. libdep + Elixir reachable'
ERL_LIBS=$LD:/usr/lib/elixir/lib ./bsc.sh --src-root programs programs/Total Sum "[1,2,3]"; echo "exit=$?"
echo '--- C. closure walk over .app `applications` (what a compile-time check could additionally do)'
cat > /tmp/closure52.escript <<'EOS'
#!/usr/bin/env escript
main([A0]) -> walk([list_to_atom(A0)], #{}).
walk([], Seen) -> io:format("closure: ~p~n", [lists:sort(maps:keys(Seen))]);
walk([A | Rest], Seen) when is_map_key(A, Seen) -> walk(Rest, Seen);
walk([A | Rest], Seen) ->
    case code:lib_dir(A) of
        {error, _} -> io:format("  MISSING application ~p~n", [A]), walk(Rest, Seen#{A => missing});
        D -> {ok, [{application, A, P}]} = file:consult(filename:join([D, "ebin", atom_to_list(A) ++ ".app"])),
             walk(Rest ++ proplists:get_value(applications, P, []), Seen#{A => D})
    end.
EOS
echo 'with only libdep reachable:'; ERL_LIBS=$LD escript /tmp/closure52.escript libdep
echo 'with libdep + elixir lib dir:'; ERL_LIBS=$LD:/usr/lib/elixir/lib escript /tmp/closure52.escript libdep
