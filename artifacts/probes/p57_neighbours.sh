#!/usr/bin/env bash
# Ticket 57: where do the neighbours fold `-5` — parser, or the pass that reads it?
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
echo "== Erlang: erl_parse keeps unary minus as a node (erl_parse.yrl:269 expr, :301 pat_expr); erl_lint folds it later"
cat > $d/e.escript <<'X'
#!/usr/bin/env escript
main(_) ->
    {ok,T,_} = erl_scan:string("N >= -5."), {ok,[E]} = erl_parse:parse_exprs(T),
    io:format("guard   : ~w~n",[E]),
    {ok,T2,_} = erl_scan:string("f(-5) -> a."), {ok,F} = erl_parse:parse_form(T2),
    io:format("pattern : ~w~n",[F]),
    io:format("erl_eval:partial_eval (erl_lint.erl:2140) -> ~w~n",[erl_eval:partial_eval({op,1,'-',{integer,1,5}})]).
X
escript $d/e.escript
echo "== Elixir: parser emits {:-, _, [5]}; unary minus stays a node in the AST (no claim about where it is folded)"
elixir -e 'IO.inspect(Code.string_to_quoted!("n >= -5"), label: "quoted")
           IO.inspect(Code.string_to_quoted!("-5"), label: "bare  ")'
echo "== Gleam 1.19.1 (binary only, no source installed): the emitted guard already carries {integer,_,-5}"
mkdir -p "$d/g/src" && printf 'name = "g57"\nversion = "1.0.0"\ntarget = "erlang"\n' > "$d/g/gleam.toml"
printf 'pub fn sign(n: Int) -> Int {\n  case n {\n    -5 -> 0\n    m if m >= -5 -> 1\n    _ -> 2\n  }\n}\n' > "$d/g/src/g57.gleam"
( cd "$d/g" && gleam build >/dev/null 2>&1 )
cat > $d/g.escript <<'X'
#!/usr/bin/env escript
main([F]) ->
    {ok,B} = file:read_file(F), Forms = binary_to_term(B),
    Ops = lists:usort(find(Forms, [])),
    io:format("~w~n",[Ops]).
find({op,_,'>=',_,_}=T, A) -> [T|A];
find(T, A) when is_tuple(T) -> find(tuple_to_list(T), A);
find([H|T], A) -> find(T, find(H, A));
find(_, A) -> A.
X
escript $d/g.escript "$d/g/build/dev/erlang/g57/_gleam_artefacts/g57.abstr"
echo "== Elm 0.19.3: binary installed, but package.elm-lang.org is unreachable from this sandbox, so no project compiles; nothing probed"
