#!/usr/bin/env bash
# PROTOTYPE 50c — can a B# function name contain `!` or `?`, and should it?
#
# Throwaway. Ticket 50 / ENG-250, and it touches ticket 32's FFI surface.
#
# 50b measured that `Req.get!` cannot be named in a `using` block. David then
# reframed the question — "I don't think it's a grammar decision per se, it's
# can a function name include ! or ?" — and that is what this measures, in
# four parts:
#
#   1. What do those two characters cost, if identifiers may contain them?
#   2. Are `get` and `get!` one function or two, and do they differ?
#   3. Are Elixir's conventions actually as consistent as they are said to be?
#   4. Does B# have the one distinction the `?` convention encodes?
#
# The answer the parts add up to is that B# should adopt NEITHER suffix,
# because everything they encode is already carried by a B# signature — and
# carried checkably rather than by convention.
#
#   REQPROBE=/path/to/reqprobe ./50c_bang_and_question_spelling.sh
#
# Requires: OTP 28, Elixir, a built bsc. Parts 2 and 3 need a mix project with
# req compiled; they self-skip without one. Run from the repo root.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER="$HERE/../../compiler"
BSC="$COMPILER/_build/default/bin/bsc"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

REQPROBE="${REQPROBE:-}"

if [ ! -x "$BSC" ]; then
    echo "building bsc..."
    (cd "$COMPILER" && rebar3 escriptize >/dev/null 2>&1)
fi

echo "==============================================================="
echo "1. What would it COST to allow ! or ? in an identifier?"
echo "==============================================================="
cat <<'EOF'
    Neither character is idle in B# today. `!` appears in the lexer
    only as part of `!=`; `?` is a token used in exactly one grammar
    production -- the tripwire that catches `Notes?: int` and redirects
    it to `Notes: option<T>` (ticket 26 section 4: there are no
    optional fields).

    So the question is what longest-match does. Built as a throwaway
    leex scanner rather than reasoned about, because a lexer conflict
    is measured and not inferred.

EOF

cat > "$WORK/bang.xrl" <<'XRLEOF'
Definitions.

LOWER = [a-z_]
UPPER = [A-Z]
ALNUM = [a-zA-Z0-9_]
WS    = [\s\t\r\n]

Rules.

{WS}+                    : skip_token.
{LOWER}{ALNUM}*!         : {token, {bang_ident, TokenLine, TokenChars}}.
{UPPER}{ALNUM}*\?        : {token, {q_uident, TokenLine, TokenChars}}.
{UPPER}{ALNUM}*          : {token, {uident, TokenLine, TokenChars}}.
{LOWER}{ALNUM}*          : {token, {ident, TokenLine, TokenChars}}.
!=                       : {token, {'!=', TokenLine}}.
=                        : {token, {'=', TokenLine}}.
\?                       : {token, {'?', TokenLine}}.
:                        : {token, {':', TokenLine}}.

Erlang code.
XRLEOF

cat > "$WORK/run.escript" <<ESCEOF
#!/usr/bin/env escript
%%! -pa $WORK
main(_) ->
    {ok, _} = leex:file("$WORK/bang.xrl", [{scannerfile, "$WORK/bang.erl"}]),
    {ok, Mod, Bin} = compile:file("$WORK/bang.erl", [binary, return_errors]),
    {module, Mod} = code:load_binary(Mod, "$WORK/bang.beam", Bin),
    lists:foreach(fun({Label, S}) ->
        io:format("    ~-16s ~-14s -> ", [Label, "\"" ++ S ++ "\""]),
        case bang:string(S) of
            {ok, Toks, _} -> io:format("~p~n", [strip(Toks)]);
            Err           -> io:format("ERROR ~p~n", [Err])
        end
    end, [{"comparison,", "a != b"},
          {"...unspaced,", "a!=b"},
          {"bang name,", "a! = b"},
          {"the tripwire,", "Notes?: int"},
          {"...spaced,", "Notes ?: int"}]),
    ok.
strip(Toks) ->
    [case T of {C, _, Ch} -> {C, Ch}; {C, _} -> C end || T <- Toks].
ESCEOF

escript "$WORK/run.escript" 2>&1 | grep -v "^generated"

cat <<'EOF'

    Read the second and third lines together: with a bang allowed in
    identifiers, `a!=b` and `a! = b` produce IDENTICAL tokens. The
    comparison is gone, and since `=` is MATCH in B# (F8), it has
    silently become a match expression.

    And the fourth: `Notes?: int` becomes ONE token, so the production
    `field_decl -> uident '?' ':' type_expr` can never fire. The
    diagnostic ticket 26 §4 paid for is disarmed, and the field is
    simply named `Notes?`. Only the spaced form still works, and
    nobody writes that.

    Neither case is an ERROR. Both silently remove behaviour that
    exists today — which is a better argument than "the character is
    taken", and it is the same argument twice.
EOF

echo
echo "==============================================================="
echo "2. Are \`get\` and \`get!\` one function or two?"
echo "==============================================================="

if [ -z "$REQPROBE" ] || [ ! -d "$REQPROBE/_build/dev/lib/req/ebin" ]; then
    echo "    SKIPPED — needs REQPROBE (a mix project with req compiled)."
else
    cat > "$WORK/two.exs" <<'EXEOF'
bangs = Req.module_info(:exports)
        |> Enum.filter(fn {n, _} -> String.ends_with?(Atom.to_string(n), "!") end)

IO.puts("    Req exports #{length(bangs)} bang functions:")
IO.puts("        " <> (bangs |> Enum.map(fn {n, _} -> n end) |> Enum.uniq()
                              |> Enum.sort() |> Enum.join("  ")))

# Req signals transport failure by RETURNING an exception struct. A stub that
# RAISES would be propagated by both variants and would measure nothing.
fail = fn req -> {req, %Mint.TransportError{reason: :nxdomain}} end
grab = fn f ->
  try do f.() rescue e -> {:raised, e.__struct__} end
end

IO.puts("\n    on a transport failure:")
IO.puts("        Req.get/1   -> #{inspect(grab.(fn -> Req.get("http://x.invalid", adapter: fail) end))}")
IO.puts("        Req.get!/1  -> #{inspect(grab.(fn -> Req.get!("http://x.invalid", adapter: fail) end))}")
EXEOF
    (cd "$REQPROBE" && mix run "$WORK/two.exs" 2>&1 \
        | grep -v "deprecated\|^  (req\|^  (elixir\|two.exs:")
    cat <<'EOF'

    Two exported functions with two contracts, not two spellings of
    one. So a B# module that wants both needs two B# names REGARDLESS
    of whether the bang is spellable — which promotes an alias form
    from workaround to requirement.
EOF
fi

echo
echo "==============================================================="
echo "3. Are Elixir's conventions as consistent as they are said to be?"
echo "==============================================================="

if [ -z "$REQPROBE" ] || [ ! -d "$REQPROBE/_build/dev/lib/req/ebin" ]; then
    echo "    SKIPPED — needs REQPROBE."
else
    cat > "$WORK/conv.exs" <<'EXEOF'
mods = [Enum, Map, String, List, Keyword, File, Integer, Code, Atom,
        Tuple, Access, Path, Regex, Version, MapSet, Date, Range, Function]

ex = fn m -> try do m.module_info(:exports) rescue _ -> [] end end
q  = for m <- mods, {n, a} <- ex.(m), String.ends_with?(Atom.to_string(n), "?"), do: {m, n, a}
b  = for m <- mods, {n, a} <- ex.(m), String.ends_with?(Atom.to_string(n), "!"), do: {m, n, a}

IO.puts("    across #{length(mods)} stdlib modules: #{length(q)} ?-exports, #{length(b)} !-exports")

# Call every arity-1 ?-function against a spread of benign values and look for
# a NON-boolean return. That is the counterexample the convention forbids.
args = [[], "", :a, 0, %{}, [1], {1}, 1.0, nil]
rs = for {m, n, 1} <- q, arg <- args do
       try do {m, n, apply(m, n, [arg])} rescue _ -> :skip catch _, _ -> :skip end
     end |> Enum.reject(&(&1 == :skip))
bad = rs |> Enum.reject(fn {_, _, v} -> is_boolean(v) end)

IO.puts("\n    ? -> boolean:")
IO.puts("        arity-1 ?-calls that returned : #{length(rs)}")
IO.puts("        NON-boolean returns           : #{length(bad)}")

orphans = for {m, n, a} <- b,
              t = String.trim_trailing(Atom.to_string(n), "!") |> String.to_atom(),
              not function_exported?(m, t, a),
              do: "#{inspect(m)}.#{n}/#{a}"

IO.puts("\n    ! -> always paired with a non-bang twin?")
IO.puts("        !-functions with NO same-arity twin : #{length(orphans)}")
IO.puts("        e.g. " <> (orphans |> Enum.take(4) |> Enum.join(", ")))

IO.puts("\n    ? versus is_* — the distinction the suffix ALSO encodes:")
g = try do
      Code.eval_string("(fn x when Map.has_key?(x, :a) -> true; _ -> false end).(%{a: 1})")
      :allowed
    rescue _ -> :REFUSED end
IO.puts("        is_map/1 in a guard      : #{(fn x when is_map(x) -> :allowed; _ -> :no end).(%{})}")
IO.puts("        Map.has_key?/2 in a guard: #{g}")
EXEOF
    (cd "$REQPROBE" && mix run "$WORK/conv.exs" 2>&1 \
        | grep -v "deprecated\|^  (elixir\|conv.exs:\|^warning\|^error:\|^└─")
    cat <<'EOF'

    `?` -> boolean holds without exception in the sample, and the
    official rule is strictly "return a boolean" -- there is no
    truthiness hedge anywhere in the page.

    The unpaired bangs are NOT a convention failure. The official page
    sanctions them outright: "In some situations, you may have bang
    functions without a non-bang counterpart." So the measurement above
    confirms the documented rule rather than finding an exception to it.

    And `?` encodes a SECOND thing. The page states the `is_` side
    positively -- guard-valid checks are named `is_`, "precisely to
    indicate that they are allowed in guard clauses" -- and states the
    exclusion as "A trailing question mark should not be used in
    combination with the `is_` prefix."

    Careful with the mechanism, though: the prefix is a naming SIGNAL,
    not what makes something guard-usable. `defguard` is the mechanism,
    and `Map.has_key?/2` is barred from guards because it is an ordinary
    remote call, not because of how it is spelled.
EOF
fi

echo
echo "==============================================================="
echo "4. Does B# have that second distinction to encode?"
echo "==============================================================="
echo "    If a B# function could appear in a guard, then \"guard-safe\""
echo "    would be a real fact a name might need to advertise."
echo

mkdir -p "$WORK/G/G"
cat > "$WORK/G/G/G.bs" <<'EOF'
module G

private bool Even(int n)
Even(n) -> n == 0

public atom F(int n)
F(n) when Even(n) -> :yes
F(n)              -> :no
EOF

out="$("$BSC" "$WORK/G/G" 2>&1)"; rc=$?
printf '%s\n' "$out" | sed 's/^/    /'
if [ "$rc" -eq 0 ]; then echo "    ACCEPTED (exit 0)"; else echo "    REFUSED (exit $rc)"; fi

cat <<'EOF'

    Refused — nothing user-written may appear in a B# guard. So there
    is no "this one is guard-safe" fact for a suffix to carry, and the
    second half of the `?` convention has nothing to encode either.

    NOTE THE DIAGNOSTIC, THOUGH. That text is erlc's, not bsc's, and it
    comes with a "function 'Even'/1 is unused" warning about a function
    that IS used — just illegally. In a compiler that pays for a whole
    grammar production to redirect `Notes?:` to `option<T>`, a user who
    hits the guard restriction is handed Erlang's vocabulary instead.
    Raised separately.
EOF

cat <<'EOF'

===============================================================
VERDICT
===============================================================
    Elixir's two suffixes encode three things. B# carries all three
    already, and carries them in the SIGNATURE rather than the name:

        `!` failure cases raise an exception
              -> `result<T, foreign_error>`, and F19 EMITS the try

        `?` returns a boolean
              -> the signature says `bool`

        `is_` versus `?`, i.e. guard-valid or not
              -> no such distinction exists; nothing user-written
                 can be in a guard at all

    ONE MISMATCH WORTH CARRYING FORWARD, and it is not a blocker.
    The bang governs SEMANTIC failure only -- the official page says
    "Errors that come from invalid argument types, or similar, must
    always raise regardless if the function has a bang or not." B#'s
    `result<T, foreign_error>` emits a try that catches BOTH, so the
    B# type is broader than the Elixir convention it is standing in
    for. Declaring a bang function that way is right; assuming the
    two mean the same set of failures is not.

    Elixir needs the convention because it has no signature to read.
    Adopting it in B# would duplicate a checked fact with an unchecked
    one, and permit the two to disagree — nothing would stop `Fetch!`
    being declared to return a plain value.

    So: neither character enters a B# identifier, and neither gains
    meaning. They stay what they are — characters in somebody else's
    atom — and the `using` block needs a way to bind a B# name to that
    atom. Ticket 32 already established the declaration carries both
    spellings; this is that principle meeting a name B# cannot spell.
done.
EOF
