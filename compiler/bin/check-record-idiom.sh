#!/usr/bin/env bash
#
# check-record-idiom.sh — a record is dispatched by naming its type, never by
# writing its minted tag.
#
# WHY THIS EXISTS (2026-09-03, ENG-307)
#
# Ticket 55 settled the spelling of a record pattern: `Order o`, or
# `Order { Id: i }` when a field matters. The tag a record erases to is MINTED
# from its qualified name, and the survey was unanimous that a programmer does
# not write it — C#, Erlang, Elixir and Gleam all name the type. Writing the
# tag by hand, `Which({ Kind: :'Shop.Order' })`, is the one place the surface
# makes an erasure detail load-bearing in source. It compiles. It is the
# escape hatch, and ticket 55 called it that.
#
# The corpus taught it as the idiom anyway. Measured on `9f4590c`: the flagship
# record example `examples/Shop/shop.bs` dispatched with the hatch, TOUR.md
# quoted those two clauses, F3's scenarios wrote them, the shared test fixture
# duplicated them, and the residual gate's own `RecordUnion` fixture — which
# exists to refuse the hatch when the PRINTER emits it — was written in it.
# Fifteen lines across seven files a clean-room reader learns from (this gate's
# first run, at `9f4590c`; the issue had counted ten sites and missed the two
# switch arms in `switch_tests.erl`), and not one gate looked, because
# `check-residual-pasteable.sh`'s `refused_spelling` judges what the compiler
# prints and nothing judged what the corpus ships.
#
# The defect matters more than style. Two records over identical field sets
# have NO structural handle — the tag is the only thing that separates them —
# so the type prefix is the only non-hatch way to discriminate in exactly the
# case the hatch was being taught for. `Shop`'s `Order` and `Invoice` are that
# case.
#
# THE RULE
#
# A hand-written minted tag in PATTERN position is refused. Textually: a line
# carrying `{ Kind: :'…' }` AND, after it, a clause arrow `->` or a switch
# arrow `=>`. The arrow is what separates a pattern from every legitimate use
# of the same text —
#
#   type Spelled = { Kind: :'Shop.Order', Id: int, Total: int }   a TYPE (F3.2)
#   atom Which({ Kind: :'Shop.Invoice', Id: int, … } | …)         --api output
#   Which "{ Kind = :'Shop.Invoice', Id = 2, Total = 9 }"          a VALUE, `=`
#
# — none of which teaches a reader to dispatch by hand.
#
# WHERE IT LOOKS: the files a reader copies from. `.bs` sources under
# `examples/` and `bin/fixtures/` (comment text stripped — a comment may
# describe the hatch, and `shop.bs` does); the FENCED blocks of `TOUR.md`,
# `LANGUAGE.md`, `README.md` and `features/F*.md` (prose may name the defect,
# a fence teaches it); and the string literals of `test/*.erl` (comment lines
# dropped), because since ENG-276 the tests are provenance a clean-room reader
# follows.
#
# NAMED EXCEPTIONS, each with its reason:
#
#   test/record_pattern_tests.erl   F22's own module. It builds both spellings
#                                   from one template and asserts they AGREE;
#                                   removing the hatch would remove the control.
#
# `bin/check-record-pattern.sh` holds the same control for the same reason and
# is outside the sweep already (no gate reads another gate's probes), as are
# `src/` comments, which explain the `p_map` clause the hatch IS an instance of,
# and `bench/`, which generates clause heads by the hundred.
#
# WHAT IT DOES NOT DECIDE. Whether the hatch stays LEGAL in source is ticket
# 55's open question (ENG-307 item 3) and this gate does not answer it: the
# compiler accepts the form, and this checks what the corpus teaches, not what
# the parser admits.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# The regex is ERE with no backslash so it survives `awk -v` unchanged. The
# braces are bracketed rather than escaped because BSD awk and GNU awk disagree
# about `\{` in a dynamic regex.
HATCH_RE="[{] *Kind *: *:'[^']*'[^}]*[}].*(->|=>)"

# The exception list, by basename. A function rather than a variable so the
# self-test drives the same lookup the run does.
exempt() {
  case "$1" in
    record_pattern_tests.erl) return 0 ;;
    # Outside the sweep today (no gate reads another gate's probes), and named
    # anyway so a future widening to `bin/*.sh` keeps the control it holds.
    check-record-pattern.sh)  return 0 ;;
    *) return 1 ;;
  esac
}

# Each scanner prints `LINE: TEXT` for every hit and nothing otherwise. They
# differ only in what they blank before matching.
scan_bs()  { awk -v re="$HATCH_RE" '{ l = $0; sub(/\/\/.*/, "", l); if (l ~ re) print NR ": " $0 }' "$1"; }
scan_erl() { awk -v re="$HATCH_RE" '/^[ \t]*%/ { next } $0 ~ re { print NR ": " $0 }' "$1"; }
# A fence inside a blockquote (`> ```) is still a fence: TOUR.md's dated
# corrections quote struck-out rows that way, and a quoted fence teaches
# exactly what an unquoted one does. The quote prefix is stripped first.
scan_md()  { awk -v re="$HATCH_RE" '{ l = $0; sub(/^[ \t]*(> ?)*/, "", l) } l ~ /^```/ { fence = !fence; next } fence && l ~ re { print NR ": " $0 }' "$1"; }

# judge ROOT — every hit under one tree, as `path:line: text`. A parameter so
# --self-test drives this function over fixtures rather than a copy of it.
judge() {
  local root="$1" f
  emit() { # emit FILE SCANNER
    local file="$1" scanner="$2" line
    exempt "$(basename "$file")" && return 0
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      printf '%s:%s\n' "${file#"$root"/}" "$line"
    done <<EOF
$("$scanner" "$file")
EOF
  }

  # Sources. `find` rather than a glob so a nested module directory is reached.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    emit "$f" scan_bs
  done <<EOF
$(find "$root/compiler/examples" "$root/compiler/bin/fixtures" -name '*.bs' -type f 2>/dev/null | sort)
EOF

  # Documents — fenced blocks only.
  for f in "$root/TOUR.md" "$root/LANGUAGE.md" "$root/README.md" "$root"/compiler/features/F*.md; do
    [ -f "$f" ] || continue
    emit "$f" scan_md
  done

  # Tests — string literals, comment lines dropped.
  for f in "$root"/compiler/test/*.erl; do
    [ -f "$f" ] || continue
    emit "$f" scan_erl
  done
}

# ---------------------------------------------------------------------------
# --self-test — six defects and six correct forms, each built as a small tree
# in the repo's layout and judged by the function above.
#
# The green half is not optional: a check that fires on everything passes the
# red half and is worthless. Each red stub is chosen for the clause it reaches:
#
#   head      the plain case — the thing found on the tree.
#   arm       the over-informed stub. A switch arm starts with `{`, not with a
#             function name, so a gate that recognises a clause head by its
#             leading identifier reads straight past it. `=>` is why the rule
#             names both arrows.
#   fixture   the hatch under `bin/fixtures/`, where the residual gate's own
#             input lived in it.
#   fence     a document teaching it inside a code fence.
#   quoted    the same fence inside a blockquote (`> ```), which a scanner that
#             recognises fences at column 1 reads as prose.
#   erl       a test fixture string. Same text as `prose`'s sentence, and it
#             must go the other way, because a test is copied and a sentence
#             is read.
#
# and each green control for the false positive it rules out:
#
#   prefix    the decided spelling, in all three file kinds.
#   prose     the hatch named in a sentence outside any fence — this file's own
#             header would be red under a gate that could not tell.
#   value     a construction (`Kind =`), a CLI argument, and `--api` output,
#             which carry the tag without an arrow.
#   comment   the hatch inside `//` in a `.bs` and `%%` in an `.erl`.
#   alias     F3.2's hand-written `type` with the same tag: a type, not a pattern.
#   exempt    the hatch inside `record_pattern_tests.erl`, and — the cry-wolf
#             half — the identical file under another name, which must be red.
# ---------------------------------------------------------------------------
self_test() {
  # Not `local`: the EXIT trap runs after a local would be gone.
  W="$(mktemp -d "${TMPDIR:-/tmp}/record-idiom.XXXXXX")"
  trap 'rm -rf "$W"' EXIT
  local failed=0
  indent() { while IFS= read -r l; do printf '    %s\n' "$l"; done; }

  tree() { # tree NAME — the repo layout, empty
    mkdir -p "$W/$1/compiler/examples/M" "$W/$1/compiler/bin/fixtures/residual/X" \
             "$W/$1/compiler/features" "$W/$1/compiler/test"
  }
  expect() { # expect NAME red|green [SUBSTRING]
    local name="$1" want="$2" needle="${3:-}" out rc=0
    out="$(judge "$W/$name")" || rc=$?
    # A judge that CRASHED prints nothing, which is what a green control looks
    # like. Under `set -e` a failing awk or find inside `judge` exits non-zero,
    # and that must be its own failure rather than a pass on the green half.
    if [ "$rc" -ne 0 ]; then
      echo "SELF-TEST FAILED: judging '$name' exited $rc; a crashed judge is not a verdict"; failed=1; return
    fi
    case "$want" in
      red)
        if [ -z "$out" ]; then
          echo "SELF-TEST FAILED: '$name' is a defect and the gate was silent on it"; failed=1
        elif [ -n "$needle" ] && ! printf '%s\n' "$out" | grep -qF -- "$needle"; then
          echo "SELF-TEST FAILED: '$name' was red, but not at '$needle':"; printf '%s\n' "$out" | indent; failed=1
        fi ;;
      green)
        if [ -n "$out" ]; then
          echo "SELF-TEST FAILED: '$name' is the correct form and the gate refused it:"; printf '%s\n' "$out" | indent; failed=1
        fi ;;
    esac
  }

  # --- red -----------------------------------------------------------------
  tree head
  printf "module M\nrecord Order { Id: int }\npublic atom Which(Order)\nWhich({ Kind: :'M.Order' }) -> :order\n" \
    > "$W/head/compiler/examples/M/m.bs"
  expect head red "compiler/examples/M/m.bs:4:"

  tree arm
  printf "module M\nrecord Order { Id: int }\npublic atom Which(Order o)\nWhich(o) -> o switch {\n    { Kind: :'M.Order' } => :order\n}\n" \
    > "$W/arm/compiler/examples/M/m.bs"
  expect arm red "compiler/examples/M/m.bs:5:"

  tree fixture
  printf "module X\nrecord Order { Id: int }\npublic atom Which(Order)\nWhich({ Kind: :'X.Order' }) -> :order\n" \
    > "$W/fixture/compiler/bin/fixtures/residual/X/X.bs"
  expect fixture red "compiler/bin/fixtures/residual/X/X.bs:4:"

  tree fence
  printf "# Tour\n\n\`\`\`\nWhich({ Kind: :'M.Order' }) -> :order\n\`\`\`\n" > "$W/fence/TOUR.md"
  expect fence red "TOUR.md:4:"

  # The quoted fence: a gate that only sees a fence at column 1 reads a
  # blockquoted one as prose and goes green over it.
  tree quoted_fence
  printf "> **Corrected.** The row was:\n>\n> \`\`\`\n> Which({ Kind: :'M.Order' }) -> :order\n> \`\`\`\n" > "$W/quoted_fence/TOUR.md"
  expect quoted_fence red "TOUR.md:4:"

  tree erl
  printf "shop_src() ->\n    \"Which({ Kind: :'M.Order' }) -> :order\\\\n\".\n" > "$W/erl/compiler/test/shop_tests.erl"
  expect erl red "compiler/test/shop_tests.erl:2:"

  # --- green ---------------------------------------------------------------
  tree prefix
  printf "module M\nrecord Order { Id: int }\npublic atom Which(Order)\nWhich(Order o) -> :order\nWhich(Order { Id: 1 }) -> :one\n" \
    > "$W/prefix/compiler/examples/M/m.bs"
  printf "\`\`\`\nWhich(Order o) -> :order\n\`\`\`\n" > "$W/prefix/TOUR.md"
  printf "src() -> \"Which(Order o) -> :order\\\\n\".\n" > "$W/prefix/compiler/test/a_tests.erl"
  expect prefix green

  tree prose
  printf "The hatch \`Which({ Kind: :'M.Order' }) -> :order\` compiles and is refused here.\n" > "$W/prose/TOUR.md"
  printf "# F3\n\nExpect \`Which({ Kind: :'M.Invoice' }) -> ...\` from the printer.\n" > "$W/prose/compiler/features/F3-records.md"
  expect prose green

  tree value
  printf "module M\nrecord Order { Id: int }\npublic Order New(int id)\nNew(id) -> Order{ Id = id }\n" \
    > "$W/value/compiler/examples/M/m.bs"
  printf "\`\`\`\n\$ bsc --src-root examples examples/M Which \"{ Kind = :'M.Order', Id = 2 }\"\n:order\n\$ bsc --api M\natom Which({ Kind: :'M.Invoice', Id: int } | { Kind: :'M.Order', Id: int })\n\`\`\`\n" \
    > "$W/value/TOUR.md"
  expect value green

  tree comment
  printf "module M\n// the hatch, Which({ Kind: :'M.Order' }) -> :order, is refused\nrecord Order { Id: int }\n" \
    > "$W/comment/compiler/examples/M/m.bs"
  printf "%%%% the hatch: Which({ Kind: :'M.Order' }) -> :order\nsrc() -> ok.\n" > "$W/comment/compiler/test/c_tests.erl"
  expect comment green

  tree alias
  printf "\`\`\`csharp\nrecord Order { Id: int }\ntype Spelled = { Kind: :'M.Order', Id: int }\ntype Either = Order | Spelled\n\`\`\`\n" \
    > "$W/alias/compiler/features/F3-records.md"
  expect alias green

  tree exempt
  printf "covering(kind) -> \"Which({ Kind: :'W.Method' }) -> :method\\\\n\".\n" \
    > "$W/exempt/compiler/test/record_pattern_tests.erl"
  expect exempt green
  tree exempt_cry_wolf
  cp "$W/exempt/compiler/test/record_pattern_tests.erl" "$W/exempt_cry_wolf/compiler/test/other_tests.erl"
  expect exempt_cry_wolf red "compiler/test/other_tests.erl:1:"

  if [ "$failed" -ne 0 ]; then
    echo "SELF-TEST FAILED"; return 1
  fi
  echo "self-test: refused the hatch in a clause head, a switch arm, a fixture, a fence,"
  echo "           a quoted fence and a test string; accepted the type prefix, prose, values, comments,"
  echo "           a type alias and the named exception, and refused that exception's"
  echo "           text under any other name"
}

if [ "${1:-}" = "--self-test" ]; then
  self_test
  exit $?
fi

hits="$(judge "$ROOT")"
if [ -n "$hits" ]; then
  n="$(printf '%s\n' "$hits" | grep -c .)"
  echo "$n line(s) dispatch on a hand-written minted tag. Name the type instead:"
  echo "    Which({ Kind: :'Shop.Order' }) -> ...      becomes      Which(Order o) -> ..."
  echo
  printf '%s\n' "$hits" | sed 's/^/  /'
  echo
  echo "Ticket 55 chose the type prefix; the tag is minted, and writing it makes an"
  echo "erasure detail load-bearing in source. See compiler/bin/check-record-idiom.sh."
  exit 1
fi
echo "ok: no clause head or switch arm in the corpus writes a minted tag by hand"
