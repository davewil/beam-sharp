#!/usr/bin/env bash
# P14: run the two candidate derivation rules over EVERY public function name in the repo's real .bs corpus (examples, exemplars, fixtures).
# Rule S = acronym-aware (bs_alias:snake/1, the patch).  Rule G = Gleam's observed constructor rule (`_` before every capital, p05).
# CLAIM A: on the real corpus rule S yields no within-module collision (REFUTED IF any module has two public names with equal S-alias).
# CLAIM B: rule G produces visibly worse names (`h_t_t_p_get`) than S on acronym-bearing names (REFUTED IF no corpus name contains 2+ adjacent capitals).
# Reads only: the .bs files. Writes nothing in the repo.
. "$(dirname "$0")/lib.sh"; build_alias_compiler || exit 1
find "$REPO" -name '*.bs' -not -path '*/artifacts/*' -not -path '*/_build/*' | sort > "$SCRATCH/bsfiles.txt"
awk '/^module /{m=$2} /^public /{ if (match($0, /[A-Z][A-Za-z0-9_]*\(/)) { n=substr($0,RSTART,RLENGTH-1); print FILENAME "\t" m "\t" n } }' $(cat "$SCRATCH/bsfiles.txt") > "$SCRATCH/pubnames.tsv"
echo "files=$(wc -l < "$SCRATCH/bsfiles.txt")  public signatures=$(wc -l < "$SCRATCH/pubnames.tsv")  distinct (module,name)=$(cut -f2,3 "$SCRATCH/pubnames.tsv" | sort -u | wc -l)  distinct names=$(cut -f3 "$SCRATCH/pubnames.tsv" | sort -u | wc -l)"
erl -noshell -pa "$SCRATCH/compiler-alias/_build/default/lib/bsc/ebin" -eval '
  {ok, Bin} = file:read_file("'"$SCRATCH"'/pubnames.tsv"),
  Rows = [list_to_tuple(string:split(L, "\t", all)) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""],
  MN = lists:usort([{M, list_to_atom(N)} || {_, M, N} <- Rows]),
  Names = lists:usort([N || {_, N} <- MN]),
  Coll = fun(Rule) -> By = lists:foldl(fun({M,N}, A) -> maps:update_with({M, bs_alias:Rule(N)}, fun(L) -> [N|L] end, [N], A) end, #{}, MN),
                      [{K, lists:sort(V)} || {K, V} <- maps:to_list(By), length(V) > 1] end,
  io:format("within-module collisions, rule S: ~p~n", [Coll(snake)]),
  io:format("within-module collisions, rule G: ~p~n", [Coll(snake_gleam)]),
  Diff = [{N, bs_alias:snake(N), bs_alias:snake_gleam(N)} || N <- Names, bs_alias:snake(N) =/= bs_alias:snake_gleam(N)],
  io:format("names where S and G differ: ~p of ~p distinct~n", [length(Diff), length(Names)]),
  [io:format("  ~-28s S: ~-28s G: ~s~n", [N, S, G]) || {N, S, G} <- lists:sublist(Diff, 12)],
  Same = [N || N <- Names, N =:= bs_alias:snake(N)], io:format("names whose S-alias equals the name (none expected): ~p~n", [Same]),
  Acr = [N || N <- Names, re:run(atom_to_list(N), "[A-Z][A-Z]") =/= nomatch], io:format("corpus names with 2+ adjacent capitals: ~p~n", [Acr]),
  Us = [N || N <- Names, lists:member($_, atom_to_list(N))], io:format("corpus names containing underscore: ~p~n", [Us]),
  Dg = [N || N <- Names, re:run(atom_to_list(N), "[0-9]") =/= nomatch], io:format("corpus names containing digits: ~p~n", [Dg]),
  halt().'
