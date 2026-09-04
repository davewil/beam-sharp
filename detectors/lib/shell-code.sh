#!/usr/bin/env bash
#
# SHELL CODE, WITH THE PROSE TAKEN OUT.
#
# Four detectors in this directory ask a question about what a gate script DOES:
# which commands it runs (`detect-unmanifested-tool.sh`), whether a control's
# exit status is neutralised (`detect-swallowed-status.sh`), whether a self-test
# reads an environment variable it never set (`detect-inherited-env.sh`), and
# whether a `sed` replacement carries an unescaped `&` (`detect-sed-mangle.sh`).
#
# Every one of them is defeated by the same thing, and it is not exotic: this
# repository's gates are more prose than code. A gate is typically a 60-line
# header comment, a `--self-test` that writes whole B# programs into heredocs,
# and several multi-line explanatory strings. Measured while this helper was
# being written, a naive scan of command positions over the 42 gate scripts
# reported 36 distinct "commands", of which 22 were English words and B#
# identifiers that happen to name a binary on macOS — `say`, `more`, `open`,
# `last`, `split`, `write`, `machine`, `quota`, and a B# type variable called
# `W` eight times over. A detector with that signal-to-noise ratio is one this
# repository would switch off, which `check-shell.sh`'s own header says in as
# many words about severity `style`.
#
# So the scan is given shell code and nothing else.
#
# TWO EARLIER DRAFTS GOT THIS WRONG IN OPPOSITE DIRECTIONS, and both failures
# are the reason this is a state machine rather than a stack of `gsub` calls.
#
#   Resetting the quote state at each newline left the second and later lines of
#   every multi-line explanatory string looking like bare code, which is where
#   all 22 false positives came from.
#
#   Blanking everything inside double quotes then lost `perl` and `shasum` —
#   BOTH OF THE REAL FINDINGS — because a gate writes `out="$(perl -e ... )"`,
#   and a command substitution inside a quoted span is code, not prose. A
#   stripper that cannot see into `$( )` reports a clean tree over the exact
#   defect it was written for, which is this repository's most-repeated failure
#   shape wearing a new hat.
#
# So the machine carries a CONTEXT STACK, not a pair of flags:
#
#   CODE  bare shell. `'` opens SQ, `"` opens DQ, `$(` opens a nested CODE,
#         `#` at a word boundary comments to end of line, `<<TAG` arms a heredoc.
#   SQ    single quotes: nothing is special until the next `'`. No escapes.
#   DQ    double quotes: `\` escapes the next character, `"` closes — and `$(`
#         opens a nested CODE, which is the half that matters.
#
# The stack survives across lines, because every one of these constructs may.
#
# Blanked rather than deleted: a removed span becomes spaces, so line numbers and
# column positions survive and a detector can cite `file:line` at the line the
# reader will actually find.
#
# THIS IS SHARED RATHER THAN COPIED, which is the opposite of the call the three
# document gates made about their four-line manifests. The reasoning there was
# that a reader meets the duplication and can see all of it; a state machine
# copied four times cannot be read that way, and a fix to one copy leaves three
# detectors quietly measuring something else. Its controls live in
# `detect-unmanifested-tool.sh --self-test`, which is the detector whose verdict
# depends on it most — including a control for each of the two failures above.

# shell_code FILE
# Writes FILE to stdout with heredoc bodies, quoted prose and comments blanked,
# and command substitutions inside quoted spans preserved.
shell_code() {
  awk '
    function blank(s,   i, out) { out=""; for (i=0; i<length(s); i++) out=out " "; return out }
    BEGIN { top=1; ctx[1]="CODE"; inhd=0 }
    {
      line = $0

      if (inhd) {
        stripped = line
        sub(/^[ \t]+/, "", stripped)
        sub(/[ \t]+$/, "", stripped)
        if (stripped == tag) inhd = 0
        print blank(line)
        next
      }

      out = ""
      i = 1
      n = length(line)
      pending_hd = 0

      while (i <= n) {
        c = substr(line, i, 1)
        here = ctx[top]

        # ARITHMETIC. `$(( ... ))` opens with the same two characters as a
        # command substitution, so without a context of its own
        # `$(( start - 1 ))` hands a scanner `start` at what looks like a
        # command position — and `start` is a real binary on macOS. Its closing
        # `))` also unbalanced the stack, which is why the arithmetic in
        # detect-shared-scratch.sh came out of an earlier draft as
        # `$(( start - 1 )`. Blanked entirely: nothing in arithmetic is a command.
        if (here == "ARITH") {
          if (c == ")" && substr(line, i, 2) == "))") { top--; out = out "  "; i += 2; continue }
          out = out " "; i++; continue
        }

        if (here == "SQ") {
          if (c == "\047") { top-- }
          out = out " "; i++; continue
        }

        if (here == "DQ") {
          if (c == "\\" && i < n) { out = out "  "; i += 2; continue }
          # The opener is emitted rather than blanked, exactly as it is in the
          # CODE branch. A scanner looks for command POSITIONS, and blanking the
          # `$(` leaves the command inside it preceded by whitespace and
          # therefore invisible — which is how the draft before this one lost
          # `perl` and `shasum`, the only two real findings in the tree.
          if (c == "$" && substr(line, i, 3) == "$((") { top++; ctx[top] = "ARITH"; out = out "   "; i += 3; continue }
          if (c == "$" && substr(line, i, 2) == "$(") {
            top++; ctx[top] = "CODE"
            out = out "$("; i += 2; continue
          }
          if (c == "\"") { top-- }
          out = out " "; i++; continue
        }

        # here == CODE
        if (c == "\\" && i < n) { out = out substr(line, i, 2); i += 2; continue }
        if (c == "\047") { top++; ctx[top] = "SQ"; out = out "~"; i++; continue }
        if (c == "\"")   { top++; ctx[top] = "DQ"; out = out "~"; i++; continue }
        if (c == "$" && substr(line, i, 3) == "$((") { top++; ctx[top] = "ARITH"; out = out "   "; i += 3; continue }
        if (c == "$" && substr(line, i, 2) == "$(") {
          top++; ctx[top] = "CODE"
          out = out "$("; i += 2; continue
        }
        if (c == ")" && top > 1) { top--; out = out ")"; i++; continue }
        if (c == "#") {
          prev = (i > 1) ? substr(line, i-1, 1) : " "
          if (i == 1 || prev == " " || prev == "\t" || prev == ";" || prev == "&" || prev == "(") {
            out = out blank(substr(line, i))
            i = n + 1
            continue
          }
          out = out c; i++; continue
        }
        if (c == "<" && substr(line, i, 2) == "<<") {
          rest = substr(line, i)
          if (match(rest, /^<<-?[ \t]*[\047"]?[A-Za-z_][A-Za-z0-9_]*[\047"]?/)) {
            t = substr(rest, RSTART, RLENGTH)
            gsub(/^<<-?[ \t]*/, "", t)
            gsub(/[\047"]/, "", t)
            tag = t
            pending_hd = 1
            out = out blank(substr(rest, 1, RLENGTH))
            i += RLENGTH
            continue
          }
        }
        out = out c
        i++
      }
      if (pending_hd) inhd = 1
      print out
    }
  ' "$1"
}
