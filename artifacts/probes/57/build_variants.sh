#!/usr/bin/env bash
# Build variants A (parser fold) and B (checker fold) in work/, never touching compiler/.
# The generated bs_parser.erl / bs_lexer.erl are NOT copied, so yecc/leex rerun on the patched grammar.
export PATH=$HOME/.nix-profile/bin:$PATH
HERE="$(cd "$(dirname "$0")" && pwd)"; W="$HERE/work"
C=/home/user/beam-sharp/compiler
for v in A B C; do
  mkdir -p "$W/$v"
  (cd $C && tar cf - --exclude=src/bs_parser.erl --exclude=src/bs_lexer.erl src test examples rebar.config rebar.lock) | (cd "$W/$v" && tar xf -)
  mkdir -p "$W/$v/features"
  [ $v != C ] && bash "$HERE/variant$v.patch.sh" "$W/$v"
  (cd "$W/$v" && rebar3 escriptize 2>&1 | tail -3)
done
