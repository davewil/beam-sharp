#!/usr/bin/env bash
#
# The Syntect projection colours a compiling Beam# program construct by
# construct, and the scopes it emits are the ones `editor/vscode/` records.
#
# WHY THERE IS A FOURTH GRAMMAR AT ALL
# Codex highlights with Syntect and its grammar database is the immutable
# `two_face` bundle. A `csharp` or an `elixir` fence therefore colours only
# incidental overlap: `Classify(...)` is not a function head to either of them
# and `Octet` is not a type. Making Beam# a language Codex recognises means a
# `.sublime-syntax`, which is a fourth hand-written copy of part of
# `compiler/src/bs_lexer.xrl` -- so it joins the bargain `editor/README.md`
# already strikes for the other two: THE COPIES ARE UNAVOIDABLE AND ONLY THE
# DRIFT IS.
#
# WHAT THIS CHECKS THAT `check-tokens.sh` CANNOT
# That gate asks whether a token has a RULE. It says so itself: "a rule can be
# present and wrong, and only looking at a coloured file catches that." This
# gate looks at the coloured file. It runs the real highlighter -- syntect, the
# crate Codex links -- over the same `compiler/examples/` corpus the compiler
# must run, and asks what scope came out for each construct.
#
# It is therefore the first check in `editor/` that can fail on a rule that
# EXISTS. `check-tokens.sh` is green on a grammar whose every rule emits
# `comment`.
#
# THE OBLIGATIONS ARE HERE AND NOT IN THE RUST.
# `editor/syntect/scope-dump/` prints what syntect saw and holds no opinion
# about any of it. If the expected scope names lived beside the code that
# produced them this gate would agree with itself -- and a gate that agrees
# only with itself is the failure `bin/check-gates-wired.sh`'s header is about.
# Every scope below is copied from `beam-sharp.tmLanguage.json`.
#
# Usage:  editor/bin/check-syntect.sh [--self-test]

set -euo pipefail

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$SELF/.." && pwd)"

# `CHECK_SYNTECT_ROOT` exists for the self-test and names a tree holding the two
# things this gate reads: `editor/syntect/` and `compiler/examples/`. Nothing
# else sets it. The dumper is NEVER taken from there -- a control able to
# rebuild it would be measuring the control's own Rust, and cargo would run four
# times for a check that needs it once.
ROOT="${CHECK_SYNTECT_ROOT:-$REPO}"
SYNTAX_DIR="$ROOT/editor/syntect"
CORPUS="$ROOT/compiler/examples"
DUMPER="$SELF/syntect/scope-dump"

# The three spellings a fence or a filename may use.
TOKENS="beam-sharp,bsharp,bs"

# Named once because two checks need it: part 2 rejects a row satisfied from
# inside a comment, and part 3 is about nothing else.
COMMENT_SCOPE="comment.line.double-slash.beam-sharp"

# ---------------------------------------------------------------------------
# THE OBLIGATIONS. `label;;mode;;text;;required scope`, where mode is `is` for
# an exact region and `starts` for a prefix.
#
# Each row says: somewhere in the corpus, syntect scoped this text and the stack
# it emitted contained this scope. Exact text rather than a pattern, because "a
# token starting with `:`" is satisfied by a grammar that colours the sigil and
# drops the name. `starts` is used once, for the comment, whose region is a
# whole line of prose that no gate should be pinned to.
#
# Every scope name here is `beam-sharp.tmLanguage.json`'s. The grammars are a
# projection of one intent, and this is where that stops being a claim.
# ---------------------------------------------------------------------------
OBLIGATIONS=(
  "comment;;starts;;//;;comment.line.double-slash.beam-sharp"
  "atom;;is;;:method;;constant.other.symbol.beam-sharp"
  # NO ROW FOR THE QUOTED ATOM, and the absence is a measurement rather than an
  # oversight. `:'Shop.Order'` is a real construct -- F49 mints every record tag
  # in that spelling -- but grepped on 2026-09-20 EVERY occurrence of `:'` under
  # `compiler/examples/` is inside a `//` line, in the `bsc ...` invocation the
  # file's header prints. No compiling example spells one, so an obligation for
  # it would be red on a clean tree. The rule is in the grammar; the corpus
  # cannot yet exercise it, and that is the examples corpus's gap to close.
  #
  # THE DECLARATION KEYWORDS ARE ENUMERATED, not sampled, and the reason is
  # `check-tokens.sh`'s blind spot rather than thoroughness for its own sake.
  # That gate looks for a keyword ANYWHERE in the grammar file, so one named in
  # the file's own prose survives the deletion of its rule. It is stripped of
  # comments for the Syntect column now, but a row here is the stronger answer:
  # a rule that is present and wrong passes a presence check however it greps.
  # `type`, `with`, `or`, `atom` and `result` were the five that had neither.
  "module;;is;;module;;keyword.declaration.beam-sharp"
  "record;;is;;record;;keyword.declaration.beam-sharp"
  "refinement;;is;;where;;keyword.declaration.beam-sharp"
  "type;;is;;type;;keyword.declaration.beam-sharp"
  "with;;is;;with;;keyword.declaration.beam-sharp"
  "using;;is;;using;;keyword.declaration.beam-sharp"
  "public;;is;;public;;keyword.declaration.beam-sharp"
  "private;;is;;private;;keyword.declaration.beam-sharp"
  "var;;is;;var;;keyword.declaration.beam-sharp"
  "behaviour;;is;;behaviour;;keyword.declaration.beam-sharp"
  #
  # NO ROW FOR `or`, and like the quoted atom above, the absence is a
  # measurement. Grepped 2026-09-20: every `or` under `compiler/examples/` is
  # inside a `//` line. `and` carries the conjunction row; the disjunction has
  # no compiling example, so an obligation for it would be red on a clean tree.
  "atom type;;is;;atom;;support.type.beam-sharp"
  "term type;;is;;term;;support.type.beam-sharp"
  "bool type;;is;;bool;;support.type.beam-sharp"
  "option;;is;;option;;support.type.beam-sharp"
  "result;;is;;result;;support.type.beam-sharp"
  "false;;is;;false;;constant.language.beam-sharp"
  "switch;;is;;switch;;keyword.control.beam-sharp"
  "guard;;is;;when;;keyword.control.beam-sharp"
  "raise;;is;;raise;;keyword.control.exception.beam-sharp"
  "arrow type;;is;;fn;;keyword.type.beam-sharp"
  "conjunction;;is;;and;;keyword.operator.logical.beam-sharp"
  "keyword atom;;is;;true;;constant.language.beam-sharp"
  "builtin type;;is;;int;;support.type.beam-sharp"
  "parametric;;is;;list;;support.type.beam-sharp"
  "integer;;is;;255;;constant.numeric.integer.beam-sharp"
  "float;;is;;0.0;;constant.numeric.float.beam-sharp"
  "field;;is;;Id;;variable.other.property.beam-sharp"
  "function head;;is;;Classify;;entity.name.function.beam-sharp"
  "user type;;is;;Octet;;entity.name.type.beam-sharp"
  "variable;;is;;value;;variable.other.beam-sharp"
  "wildcard;;is;;_;;variable.language.wildcard.beam-sharp"
  "clause arrow;;is;;->;;keyword.operator.arrow.beam-sharp"
  "switch arrow;;is;;=>;;keyword.operator.arrow.beam-sharp"
  "rest;;is;;..;;keyword.operator.rest.beam-sharp"
  "pipe;;is;;|>;;keyword.operator.pipe.beam-sharp"
  "valve;;is;;|?>;;keyword.operator.pipe.beam-sharp"
  "binary pattern;;is;;<<;;keyword.operator.binary.beam-sharp"
  "relational;;is;;>=;;keyword.operator.comparison.beam-sharp"
)

# ---------------------------------------------------------------------------
# --self-test
#
# SIX CONTROLS, ONE PER ASSERTION THIS GATE MAKES. Controls 4, 5 and 6 arrived a
# day after the other three, when a review built the leaking grammar control 4
# now builds and found that the check named for it could not fire. Every
# assertion this gate makes needs one; the first version made four and had
# three.
#
#   1. A RULE THAT EXISTS AND IS WRONG. The whole reason for a fourth gate: the
#      function-name rule is deleted, so `Classify` falls through to the
#      type-name rule and is coloured `entity.name.type`. Every token still has
#      a rule, so `check-tokens.sh` is perfectly green on that tree -- and the
#      distinction ENG-262 names first is gone.
#   2. A SPELLING CODEX CANNOT FIND. `bsharp` is dropped from
#      `file_extensions`. The grammar is otherwise identical and every scope
#      obligation still passes; the language is simply unreachable under one of
#      the three names a fence may use.
#   3. NOTHING WAS CHECKED. An empty corpus. `check-corpus.sh` learnt this one
#      the hard way -- zero examples, zero errors, a green run -- and the count
#      is what makes it a failure here.
#
# The controls copy the committed grammar and the committed corpus. A fixture
# grammar would contain whatever the control put in it, which proves only that
# `grep` works.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  # Captured, not piped: a control run is meant to exit 1, and `pipefail` would
  # report that status even when the marker was found.
  control() {
    CHECK_SYNTECT_ROOT="$1" "${BASH_SOURCE[0]}" 2>&1 || true
  }
  fresh() {
    rm -rf "$1"
    mkdir -p "$1/editor/syntect" "$1/editor/vscode/syntaxes" "$1/compiler"
    cp "$SELF/syntect/BeamSharp.sublime-syntax"           "$1/editor/syntect/"
    cp "$SELF/vscode/syntaxes/beam-sharp.tmLanguage.json" "$1/editor/vscode/syntaxes/"
    cp -R "$REPO/compiler/examples" "$1/compiler/examples"
  }

  st_fail=0
  GRAMMAR_REL="editor/syntect/BeamSharp.sublime-syntax"

  # CONTROL 1 — the function-name rule removed. It is found by the
  # `# <<function-name>>` marker the committed grammar carries, and the control
  # checks it actually went: a `perl` that matched nothing would leave a
  # perfect grammar and a green run that measured no defect at all.
  fresh "$CTL/wrong-rule"
  perl -0pi -e 's/^[ \t]*#[ \t]*<<function-name>>\n(?:.*\n){2}//m' \
      "$CTL/wrong-rule/$GRAMMAR_REL"
  if grep -q 'entity\.name\.function' "$CTL/wrong-rule/$GRAMMAR_REL"; then
    echo "SELF-TEST FAILED: the control did not remove the function-name rule, so it"
    echo "                  measured nothing. The \`# <<function-name>>\` marker it"
    echo "                  deletes from has moved or gone."
    st_fail=1
  else
    case "$(control "$CTL/wrong-rule")" in
      *MISSING*function\ head*) ;;
      *) echo "SELF-TEST FAILED: a grammar with no function-name rule was accepted. Every"
         echo "                  token still HAS a rule there, so check-tokens.sh is green"
         echo "                  on it — catching a present-and-wrong rule is the only"
         echo "                  reason this gate exists."
         st_fail=1 ;;
    esac
  fi

  # CONTROL 2 — one of the three identifiers dropped.
  fresh "$CTL/unreachable"
  perl -pi -e 's/^[ \t]*-[ \t]*bsharp[ \t]*$//' "$CTL/unreachable/$GRAMMAR_REL"
  case "$(control "$CTL/unreachable")" in
    *UNRESOLVED*bsharp*) ;;
    *) echo "SELF-TEST FAILED: a spelling Codex cannot resolve was not reported. The"
       echo "                  grammar is then perfect and unreachable, which is the same"
       echo "                  as absent to anyone writing a fence."
       st_fail=1 ;;
  esac

  # CONTROL 3 — nothing to colour. Must be a failure, not a green run.
  fresh "$CTL/empty"
  rm -rf "$CTL/empty/compiler/examples"
  mkdir -p "$CTL/empty/compiler/examples"
  case "$(control "$CTL/empty")" in
    *EMPTY*) ;;
    *) echo "SELF-TEST FAILED: an empty corpus was accepted. This gate reports what it"
       echo "                  coloured, so colouring nothing is a failure rather than a"
       echo "                  clean run."
       st_fail=1 ;;
  esac

  # CONTROL 4 — A GRAMMAR THAT MATCHES INSIDE ITS OWN COMMENTS, which is the
  # defect part 3 names and which part 3 COULD NOT SEE when it was written. The
  # comment rule is replaced by one that pushes a context carrying the comment
  # scope as a `meta_scope` and including `main`, so every token in every `//`
  # line matches again underneath it. Measured on that grammar before this
  # control existed: 4,315 scoped regions became 13,842 and the gate printed
  # "nothing matched inside a comment" and exited 0.
  #
  # It is the sharpest control here because the grammar is not obviously broken
  # — the comment still colours, the roster still passes, and only the position
  # of the scope on the stack tells the two apart.
  #
  # The YAML quotes are written `\x27` so the whole perl program fits in one
  # single-quoted shell string and nothing has to be escaped twice.
  fresh "$CTL/leaky"
  leaky='s{- match: \x27//\.\*\$\x27\n      scope: (\S+)\n}'
  leaky="$leaky"'{- match: \x27//\x27\n      push:\n        - meta_scope: $1\n'
  leaky="$leaky"'        - match: \$\n          pop: true\n        - include: main\n}'
  perl -0pi -e "$leaky" "$CTL/leaky/$GRAMMAR_REL"
  if ! grep -q 'meta_scope' "$CTL/leaky/$GRAMMAR_REL"; then
    echo "SELF-TEST FAILED: the control did not build the leaking grammar, so it"
    echo "                  measured nothing. The comment rule it rewrites has moved."
    st_fail=1
  else
    case "$(control "$CTL/leaky")" in
      *LEAK*) ;;
      *) echo "SELF-TEST FAILED: a grammar that matches tokens INSIDE its comments was"
         echo "                  accepted. Every positive obligation passes on that"
         echo "                  grammar — part 3 is the only thing that can see it, and"
         echo "                  a containment test never can, because a nested match"
         echo "                  INHERITS the comment scope."
         st_fail=1 ;;
    esac
  fi

  # CONTROL 5 — the two projections disagree about a scope name. Renamed in the
  # TextMate file alone, which is the direction nothing else in `editor/`
  # watches: `check-tokens.sh` reads that file only for keyword presence, and
  # until part 0 existed this gate did not read it at all, so the roster's claim
  # to be quoting it was true only on the day it was typed.
  fresh "$CTL/diverged"
  sed -i.bak 's/entity\.name\.type\.beam-sharp/entity.name.klass.beam-sharp/' \
      "$CTL/diverged/editor/vscode/syntaxes/beam-sharp.tmLanguage.json"
  rm -f "$CTL/diverged/editor/vscode/syntaxes/beam-sharp.tmLanguage.json.bak"
  case "$(control "$CTL/diverged")" in
    *DIVERGED*) ;;
    *) echo "SELF-TEST FAILED: a scope renamed in the TextMate grammar alone was not"
       echo "                  reported. The roster here is hand-copied from that file,"
       echo "                  so without this it goes stale in silence."
       st_fail=1 ;;
  esac

  # CONTROL 6 — the grammar stops claiming the `.bs` extension. It still loads
  # and still resolves by name, so nothing is obviously wrong with it; it simply
  # colours no file. Without the count comparison the summary would report a
  # pass "across 0 examples", which is control 3's failure wearing a different
  # hat — that one is an empty corpus, this one is a full corpus nothing reads.
  fresh "$CTL/unclaimed"
  perl -pi -e 's/^[ \t]*-[ \t]*bs[ \t]*$//' "$CTL/unclaimed/$GRAMMAR_REL"
  case "$(control "$CTL/unclaimed")" in
    *UNCOLOURED*) ;;
    *) echo "SELF-TEST FAILED: a grammar that colours no file at all was not reported"
       echo "                  as such. The examples count in this gate's summary is"
       echo "                  quoted as evidence, so it has to be one."
       st_fail=1 ;;
  esac

  # NEGATIVE CONTROL — the grammar and the corpus as committed.
  fresh "$CTL/clean"
  if CHECK_SYNTECT_ROOT="$CTL/clean" "${BASH_SOURCE[0]}" >/dev/null 2>&1; then :; else
    echo "SELF-TEST FAILED: the committed grammar was rejected, so this gate would fail"
    echo "                  every clean tree and be removed."
    st_fail=1
  fi

  if [ "$st_fail" -eq 0 ]; then
    echo "self-test: named the present-but-wrong rule, the unresolvable spelling, the"
    echo "           empty corpus, the grammar that matches inside its own comments, the"
    echo "           scope renamed in the TextMate file alone and the grammar that"
    echo "           colours nothing; accepted the committed grammar — the gate"
    echo "           discriminates"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
for f in "$SYNTAX_DIR/BeamSharp.sublime-syntax" "$DUMPER/Cargo.toml"; do
  [ -f "$f" ] || { echo "missing: $f" >&2; exit 2; }
done

# A MISSING CARGO IS A FAILURE HERE RATHER THAN A SKIP, unlike `check-corpus.sh`
# and its tree-sitter CLI. `.tool-versions` lists cargo among the tools this
# repository requires, and `bin/check-toolchain.sh --env` already fails without
# one, so a skip here would be a second and quieter answer to a question the
# toolchain gate has already answered.
command -v cargo >/dev/null 2>&1 || {
  echo "cargo not found. The Syntect projection is checked by running syntect," >&2
  echo "which is a Rust crate: there is no other way to ask a highlighter what" >&2
  echo "colour it produced.  (brew install rust, or https://rustup.rs)" >&2
  exit 2
}

# `--locked` so the committed `Cargo.lock` decides which syntect this was
# measured against. Without it a fresh resolve can take a newer one and the
# scopes above become a claim about whatever crates.io served that morning.
if ! cargo build --locked --quiet --manifest-path "$DUMPER/Cargo.toml" 2>/dev/null; then
  echo "the scope dumper does not build:" >&2
  cargo build --locked --manifest-path "$DUMPER/Cargo.toml" >&2 || true
  exit 2
fi
BIN="$DUMPER/target/debug/scope-dump"

# `exemplars/` is excluded for the reason `check-corpus.sh` gives: they are the
# compiler's target rather than its test suite, and `bsc` does not compile them
# either. Holding a grammar to them is holding it to a language nothing
# implements.
FILES=()
while IFS= read -r f; do
  FILES+=("$f")
done < <(find "$CORPUS" \
              -path "$CORPUS/exemplars" -prune -o \
              -name '*.bs' -print | sort)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "  EMPTY    no .bs files under $CORPUS"
  echo "           this gate reports what it coloured, so colouring nothing is a"
  echo "           failure rather than a clean run."
  exit 1
fi

DUMP="$(mktemp)"
trap 'rm -f "$DUMP"' EXIT
"$BIN" --syntax "$SYNTAX_DIR" --tokens "$TOKENS" -- "${FILES[@]}" > "$DUMP"

fail=0

# --- 0. The two projections declare the same scope names ---------------------
# THE ROSTER ABOVE IS HAND-COPIED, AND A HAND-COPIED LIST GOES STALE SILENTLY.
# Without this the gate's own claim -- "the scopes it emits are the ones
# `editor/vscode/` records" -- is only true of the day it was written: rename a
# scope in the TextMate JSON alone and nothing here goes red, because nothing
# here reads that file. `check-tokens.sh` reads both, but only for keyword
# presence.
#
# So compare the SETS. Every `"name"` in the TextMate repository is a scope, and
# every `scope:` in the `.sublime-syntax` is one; the grammar's own root
# declaration is spelled `scopeName` there and `scope:` at the top level here,
# so the one at column zero is dropped from this side and the top-level
# `"name": "beam-sharp"` from that one. What is left must match exactly, in both
# directions: a scope in one and not the other is a dialect, which criterion 4
# of ENG-262 forbids in those words.
TM="$ROOT/editor/vscode/syntaxes/beam-sharp.tmLanguage.json"
if [ ! -f "$TM" ]; then
  echo "missing: $TM" >&2
  exit 2
fi
tm_scopes="$(grep -oE '"name": "[a-z][a-zA-Z0-9._-]*\.beam-sharp"' "$TM" \
             | sed -E 's/.*"name": "(.*)"/\1/' | sort -u)"
sb_scopes="$(grep -oE '^ +scope: .*' "$SYNTAX_DIR/BeamSharp.sublime-syntax" \
             | sed -E 's/^ +scope: //' | sort -u)"

echo "Scope names, TextMate against Sublime:"
if [ -z "$tm_scopes" ] || [ -z "$sb_scopes" ]; then
  echo "  EMPTY    one of the two grammars declared no scopes at all, so this"
  echo "           comparison found nothing to compare."
  fail=1
elif diff_out="$(diff <(printf '%s\n' "$tm_scopes") <(printf '%s\n' "$sb_scopes"))"; then
  printf '  %-9s %s scope names, identical in both projections\n' \
         "ok" "$(printf '%s\n' "$tm_scopes" | wc -l | tr -d ' ')"
else
  echo "  DIVERGED the two projections do not declare the same scopes"
  printf '%s\n' "$diff_out" | sed 's/^/           /'
  echo "           (< only in vscode/, > only in syntect/ — one of them is a"
  echo "            dialect, and ENG-262 criterion 4 forbids exactly that)"
  fail=1
fi
echo

# --- 1. Codex can find the language by all three spellings -------------------
echo "Resolving the language:"
resolved=0
name_seen=""
while IFS=$'\t' read -r _ token name; do
  if [ "$name" = "NONE" ]; then
    printf '  %-12s %s  -- no syntax in the set answers to this\n' "UNRESOLVED" "$token"
    fail=1
    continue
  fi
  printf '  %-12s %s -> %s\n' "ok" "$token" "$name"
  resolved=$((resolved + 1))
  if [ -z "$name_seen" ]; then
    name_seen="$name"
  elif [ "$name_seen" != "$name" ]; then
    printf '  %-12s %s resolves to %s, not to %s\n' "SPLIT" "$token" "$name" "$name_seen"
    fail=1
  fi
done < <(awk -F'\t' '$1 == "resolve" { print }' "$DUMP")

# A spelling this gate forgot to ask about is not a spelling that works, so the
# count is part of the claim -- the rule `bin/check-toolchain.sh` states at
# length and for the same reason: a grep that finds nothing reads exactly like a
# grep that agrees.
asked="$(echo "$TOKENS" | tr ',' '\n' | grep -c .)"
if [ "$resolved" -ne "$asked" ]; then
  echo "  $resolved of $asked spellings resolve."
  fail=1
fi

# --- 2. Every construct keeps its recorded scope -----------------------------
echo
echo "Scoping the corpus:"
for row in "${OBLIGATIONS[@]}"; do
  label="${row%%;;*}"; rest="${row#*;;}"
  mode="${rest%%;;*}";  rest="${rest#*;;}"
  text="${rest%%;;*}"
  scope="${rest#*;;}"

  # Field 4 is the text syntect scoped and field 5 the stack it emitted. ONE awk
  # answers both questions -- where the row is satisfied, and, when it is not,
  # what the corpus produced instead -- because two programs carrying the same
  # filter drift apart and the second one is only ever read on a red run.
  #
  # TWO PROPERTIES, AND A GRAMMAR THAT LEAKS SATISFIES NEITHER.
  #
  #   THE REQUIRED SCOPE IS THE LAST ELEMENT, not merely present. A stack is
  #   outermost-first -- `source.beam-sharp`, then the rule that matched -- so
  #   the innermost match is last, and that is what decides the colour.
  #
  #   THE REGION IS NOT INSIDE A COMMENT: the comment scope appears nowhere
  #   BEFORE the last element. Without this, a grammar whose comment rule
  #   pushes a context satisfies the roster out of its own prose -- measured,
  #   `binary pattern` was satisfied at `frame.bs:4`, which is a `//` line, and
  #   `rest` and `pipe` likewise. The comment row itself is unaffected: its
  #   scope IS the last element, so it is never "inside" one.
  IFS=$'\t' read -r hit got <<EOF
$(awk -F'\t' -v OFS='\t' -v t="$text" -v s="$scope" -v m="$mode" -v c="$COMMENT_SCOPE" '
      $1 != "scope" { next }
      m == "is"     && $4 != t { next }
      m == "starts" && index($4, t) != 1 { next }
      {
        n = split($5, parts, " ")
        for (i = 1; i < n; i++) if (parts[i] == c) next   # inside a comment
        if (parts[n] == s) { print $2 ":" $3, "-"; exit }
        if (got == "") got = $5
      }
      END { if (got != "") print "-", got }' "$DUMP")
EOF

  if [ -n "$hit" ] && [ "$hit" != "-" ]; then
    printf '  %-9s %-15s %-42s %s\n' "ok" "$label" "$scope" "${hit#"$ROOT"/}"
  else
    # What it got instead, which is the line a grammar author needs.
    [ -n "$got" ] && [ "$got" != "-" ] || got="(the corpus never scoped this text outside a comment)"
    printf '  %-9s %-15s `%s` is not %s\n' "MISSING" "$label" "$text" "$scope"
    printf '  %-9s %-15s got: %s\n' "" "" "$got"
    fail=1
  fi
done

# --- 3. Nothing leaks out of a comment ---------------------------------------
# Every grammar here puts the comment rule where nothing can match inside one,
# and all three headers say so. It is the one claim a roster of positive
# obligations cannot make, because it is about what must NOT be scoped: a
# grammar that colours `//` as two division operators and the prose after it as
# variables satisfies every row above.
#
# A REGION IS INSIDE A COMMENT WHEN THE COMMENT SCOPE IS ON ITS STACK AND IS NOT
# THE LAST ELEMENT. That is the test, and the first version of this check got it
# wrong in both halves: it looked only at regions whose TEXT began `//`, which a
# nested match's never does, and it asked whether the comment scope was absent
# from the stack, which for a nested match it is not -- it is inherited. Both
# mistakes point the same way, so the check could not fire at all. Control 4
# builds exactly that grammar.
# Capped at ten inside awk rather than piped through `head`, which closes the
# pipe early and gives the writer a SIGPIPE -- the fault `check-corpus.sh`
# documents at length, where it aborted the whole gate under `pipefail`.
leaks="$(awk -F'\t' -v c="$COMMENT_SCOPE" -v root="$ROOT/" '
    $1 != "scope" { next }
    {
      n = split($5, parts, " ")
      inside = 0
      for (i = 1; i < n; i++) if (parts[i] == c) inside = 1
      if (!inside && !(index($4, "//") == 1 && parts[n] != c)) next
      total++
      if (total <= 10) {
        f = $2; sub("^" root, "", f)
        print "  LEAK      " f ":" $3 "  " $4 "  ->  " $5
      }
    }
    END { if (total > 10) print "  ... and " (total - 10) " more" }' "$DUMP")"
if [ -n "$leaks" ]; then
  echo
  echo "Tokens matched inside a comment:"
  printf '%s\n' "$leaks"
  fail=1
fi

coloured="$(awk -F'\t' '$1 == "files" { print $2 }' "$DUMP")"
scoped="$(awk -F'\t' '$1 == "scope"' "$DUMP" | wc -l | tr -d ' ')"

# EVERY FILE HANDED OVER MUST HAVE BEEN COLOURED. `scope-dump` counts only the
# files it found a syntax for, so this is the difference between "25 examples"
# being evidence and being a number. A grammar that stops claiming `.bs` still
# loads, still resolves by name, and colours nothing -- and without this the
# summary would say "across 0 examples" in the same breath as a pass.
if [ "$coloured" -ne "${#FILES[@]}" ]; then
  echo
  printf '  %-9s %s of %s examples resolved to a syntax; the rest were handed to\n' \
         "UNCOLOURED" "$coloured" "${#FILES[@]}"
  echo "             syntect and came back with none, so nothing about them was checked."
  fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "${#OBLIGATIONS[@]} constructs keep their recorded scope across $coloured examples"
  echo "  ($scoped scoped regions, nothing matched inside a comment; the tree-sitter"
  echo "   grammar is check-corpus.sh's and the two regex grammars are"
  echo "   check-tokens.sh's — this gate reads neither)"
else
  echo "the Syntect projection does not colour what editor/vscode/ says it should."
  exit 1
fi
