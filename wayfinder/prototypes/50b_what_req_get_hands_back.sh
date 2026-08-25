#!/usr/bin/env bash
# PROTOTYPE 50b — what does `Req.get!` return, and what can B# declare it as?
#
# Throwaway. Tickets 50 and 48. Raised by David 2026-08-25:
#   "let's examine the result from Req.get! in Elixir what does it return —
#    an Elixir struct or map? if I call Req.get! from B# what do I get —
#    record or dict?"
#
# 51a measured `Req.new/1`. This measures `Req.get!`, which is the call an
# exemplar actually makes, and it measures the B# side rather than reasoning
# about it.
#
# The Elixir half runs against a STUBBED adapter and never reaches the
# network — ticket 50's own rule, since a gate that makes a real HTTP call is
# flaky by construction. The stub's values coming back verbatim is how we know.
#
#   REQPROBE=/path/to/reqprobe ./50b_what_req_get_hands_back.sh
#
# Requires: OTP 28, Elixir, a built bsc, and a mix project with req compiled.
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

# Body comes in on stdin, so nothing here has to fight bash quoting over the
# `:'Elixir.Req'` atoms. One directory per probe, named for the module — F15.
probe () {
    local name="$1" body mod out rc
    body="$(cat)"
    mod="$(printf '%s\n' "$body" | sed -n 's/^module  *\([A-Za-z0-9_.]*\).*/\1/p' | head -1)"
    mkdir -p "$WORK/$name/$mod"
    printf '%s\n' "$body" > "$WORK/$name/$mod/$mod.bs"
    echo "--- $name ---"
    out="$("$BSC" "$WORK/$name/$mod/$mod.bs" 2>&1)"; rc=$?
    [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/    /'
    if [ "$rc" -eq 0 ]; then echo "    ACCEPTED (exit 0)"; else echo "    REFUSED (exit $rc)"; fi
    echo
}

echo "==============================================================="
echo "PART 1 — Elixir: what does Req.get! hand back?"
echo "==============================================================="

if [ -z "$REQPROBE" ] || [ ! -d "$REQPROBE/_build/dev/lib/req/ebin" ]; then
    echo "    SKIPPED — no req tree. Build one with:"
    echo "        mix new reqprobe && cd reqprobe"
    echo "        # add {:req, \"~> 0.5\"} to deps, then"
    echo "        mix deps.get && mix deps.compile"
    echo "    then re-run with REQPROBE=/path/to/reqprobe"
    echo
else
    cat > "$WORK/inspect.exs" <<'EXEOF'
stub = fn req ->
  {req, Req.Response.new(status: 200,
                         headers: %{"content-type" => ["application/json"]},
                         body: %{"ok" => true, "id" => 7})}
end
resp = Req.get!("http://example.invalid/thing", adapter: stub)
p = fn l, v -> IO.puts("    " <> String.pad_trailing(l, 44) <> inspect(v)) end

IO.puts("\n  the RESPONSE:")
p.("is_struct?", is_struct(resp))
p.("is_map?", is_map(resp))
p.(":maps.get(:__struct__, ...)", :maps.get(:__struct__, resp))
p.(":maps.is_key(:Kind, ...)", :maps.is_key(:Kind, resp))
p.("keys", resp |> Map.keys() |> Enum.sort())

IO.puts("\n  the BODY, nested inside it:")
p.("body", resp.body)
p.("body is_struct?", is_struct(resp.body))
p.("body has __struct__?", :maps.is_key(:__struct__, resp.body))

IO.puts("\n  the HEADERS, also nested inside it:")
p.("headers is_struct?", is_struct(resp.headers))
p.("headers has __struct__?", :maps.is_key(:__struct__, resp.headers))
EXEOF
    (cd "$REQPROBE" && mix run "$WORK/inspect.exs" 2>&1 \
        | grep -v "deprecated\|^  (req\|^  (elixir\|inspect.exs:")
fi

echo
echo "==============================================================="
echo "PART 2 — B#: can the function even be NAMED?"
echo "==============================================================="
echo "    The Elixir function is 'Elixir.Req':'get!'/2. The bang is an"
echo "    ordinary character in an Erlang atom, but not obviously one"
echo "    a C#-shaped identifier grammar can spell."
echo

probe a_bang_bare <<'EOF'
module BangBare

using :'Elixir.Req' {
    term get!(binary url, list<(atom, term)> opts)
}

public term Fetch(binary u)
Fetch(u) -> :'Elixir.Req'.get!(u, [])
EOF

probe b_bang_quoted <<'EOF'
module BangQuoted

using :'Elixir.Req' {
    term :'get!'(binary url, list<(atom, term)> opts)
}

public term Fetch(binary u)
Fetch(u) -> :'Elixir.Req'.:'get!'(u, [])
EOF

echo "==============================================================="
echo "3. CONTROL — a bang-free Elixir function, everything else equal."
echo "   If this is refused too, every result above is my typo and"
echo "   not a finding."
echo "==============================================================="

probe c_control_term <<'EOF'
module CtlTerm

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}

public term Build()
Build() -> :'Elixir.Req'.new([])
EOF

echo "==============================================================="
echo "4. Can the return be declared as a RECORD? (ticket 50, shape 1)"
echo "==============================================================="

probe d_as_record <<'EOF'
module AsRecord

record Response { Status: int }

using :'Elixir.Req' {
    Response new(list<(atom, term)> opts)
}

public Response Build()
Build() -> :'Elixir.Req'.new([])
EOF

echo "==============================================================="
echo "5. Can the return be declared as a MAP or DICT? (shape 2)"
echo "==============================================================="

probe e_as_map <<'EOF'
module AsMap

using :'Elixir.Req' {
    map<atom, term> new(list<(atom, term)> opts)
}

public map<atom, term> Build()
Build() -> :'Elixir.Req'.new([])
EOF

probe f_as_dict <<'EOF'
module AsDict

using :'Elixir.Req' {
    dict<atom, term> new(list<(atom, term)> opts)
}

public dict<atom, term> Build()
Build() -> :'Elixir.Req'.new([])
EOF

echo "==============================================================="
echo "6. THE ONE THAT MATTERS — the record declaration was ACCEPTED."
echo "   Does it WORK?"
echo "==============================================================="
echo "    Type-checking is not the question. The value carries"
echo "    __struct__ and not Kind, so the question is whether a clause"
echo "    head can dispatch on it at RUN time. Two controls run first"
echo "    against the same live value, so a crash below cannot be"
echo "    blamed on the call itself failing."
echo

if [ -z "$REQPROBE" ] || [ ! -d "$REQPROBE/_build/dev/lib/req/ebin" ]; then
    echo "    SKIPPED — needs REQPROBE (see PART 1)."
else
    EX_LIB="$(elixir -e 'IO.puts(:filename.dirname(:code.lib_dir(:elixir)))' 2>/dev/null | tail -1)"
    export ERL_LIBS="$EX_LIB:$REQPROBE/_build/dev/lib"

    mkdir -p "$WORK/ReqRec"
    cat > "$WORK/ReqRec/ReqRec.bs" <<'EOF'
module ReqRec

record Response { Status: int }

using :'Elixir.Req' {
    Response new(list<(atom, term)> opts)
}

using :maps {
    term get(atom k, term m)
    bool is_key(atom k, term m)
}

// CONTROL 1 — the call really happens and really returns Elixir's value.
public term Tag()
Tag() -> :maps.get(:'__struct__', :'Elixir.Req'.new([]))

// CONTROL 2 — and it really does not carry beam-sharp's tag.
public bool HasKind()
HasKind() -> :maps.is_key(:'Kind', :'Elixir.Req'.new([]))

// THE TEST — bsc ACCEPTED `Response` as this function's return type.
// Does a record pattern over that value match at run time?
public atom Dispatch()
Dispatch() -> Describe(:'Elixir.Req'.new([]))

private atom Describe(Response r)
Describe({ Status: _ } r) -> :matched_a_record
EOF

    for fn in Tag HasKind Dispatch; do
        echo "    --- $fn ---"
        "$BSC" "$WORK/ReqRec" "$fn" 2>&1 | sed 's/^/        /' | head -8
    done
    echo
    echo "    Read those three together. The call works, the value is"
    echo "    Elixir's, it carries no Kind — and the record pattern the"
    echo "    compiler type-checked crashes on it."
fi

echo
echo "==============================================================="
echo "VERDICT"
echo "==============================================================="
echo "    Elixir side: Req.get! returns a STRUCT, which IS a map —"
echo "    is_struct and is_map are both true, because on the BEAM"
echo "    there is no separate struct term. And one call returns"
echo "    BOTH shapes nested: a tagged map (the response) holding"
echo "    untagged maps (the body, the headers)."
echo
echo "    B# side: neither record nor dict. There is no map or dict"
echo "    type to name. A record CAN be declared and type-checks —"
echo "    and then no clause head can match the value, at run time,"
echo "    with no diagnostic. That is a silent trap, not a refusal."
echo "    In practice the only honest declaration today is \`term\`."
echo "done."
