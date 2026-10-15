#!/usr/bin/env bash
# CLAIMS: Elm's `exposed-modules` in a package's elm.json hides every other module from importers in OTHER packages,
#   at compile time, in the IMPORTER's build (callee-side list, package = the unit); and inside the SAME package
#   (application source-directories / the package itself) every module can import every other.
# REFUTED IF: app importing me/libpkg's hidden module compiles (exit 0), or the package's own exposed module cannot
#   import its hidden one. CONTROL: app importing the EXPOSED module compiles and prints.
# SETUP LIMIT: package.elm-lang.org and github archives are blocked (403), so the registry is faked offline:
#   elm/core 1.0.5 and elm/json 1.1.3 come from `git clone` of github.com/elm/*, `me/libpkg 1.0.0` is hand-installed in a
#   scratch ELM_HOME with a hand-written registry.dat (60_elm_registry.py). Elm's behaviour on the resolved packages is real.
. "$(dirname "$0")/env.sh"; D="$(cd "$(dirname "$0")" && pwd)"
S=$(mktemp -d /tmp/probe60elm.XXXXXX); export ELM_HOME=$S/home; P=$ELM_HOME/0.19.2/packages
mkdir -p $P/elm $P/me
git -c advice.detachedHead=false clone -q --depth 1 --branch 1.0.5 https://github.com/elm/core $P/elm/core/1.0.5 || exit 1
git -c advice.detachedHead=false clone -q --depth 1 --branch 1.1.3 https://github.com/elm/json $P/elm/json/1.1.3 || exit 1
rm -rf $P/elm/*/*/.git
L=$P/me/libpkg/1.0.0; mkdir -p $L/src/Lib/Internal
cat > $L/elm.json <<'T'
{"type":"package","name":"me/libpkg","summary":"scratch","license":"MIT","version":"1.0.0","exposed-modules":["Lib"],
 "elm-version":"0.19.0 <= v < 0.20.0","dependencies":{"elm/core":"1.0.0 <= v < 2.0.0"},"test-dependencies":{}}
T
cat > $L/src/Lib.elm <<'T'
module Lib exposing (open)
import Lib.Internal.Secret as Secret
open : Int
open = Secret.helper + 1
T
cat > $L/src/Lib/Internal/Secret.elm <<'T'
module Lib.Internal.Secret exposing (helper)
helper : Int
helper = 41
T
python3 "$D/60_elm_registry.py" $ELM_HOME me/libpkg@1.0.0 elm/core@1.0.5 elm/json@1.1.3
mkapp() { mkdir -p $S/$1/src; cat > $S/$1/elm.json <<'T'
{"type":"application","source-directories":["src"],"elm-version":"0.19.2",
 "dependencies":{"direct":{"elm/core":"1.0.5","elm/json":"1.1.3","me/libpkg":"1.0.0"},"indirect":{}},
 "test-dependencies":{"direct":{},"indirect":{}}}
T
cat > $S/$1/src/Main.elm; }
mkapp app <<'T'
module Main exposing (main)
import Lib.Internal.Secret as Secret
import Platform
main : Program () Int ()
main = Platform.worker { init = \_ -> ( Secret.helper, Cmd.none ), update = \_ m -> ( m, Cmd.none ), subscriptions = \_ -> Sub.none }
T
mkapp ctl <<'T'
module Main exposing (main)
import Lib
import Platform
main : Program () Int ()
main = Platform.worker { init = \_ -> ( Lib.open, Cmd.none ), update = \_ m -> ( m, Cmd.none ), subscriptions = \_ -> Sub.none }
T
echo "=== other package imports the HIDDEN module me/libpkg:Lib.Internal.Secret"
(cd $S/app && elm make src/Main.elm --output=/dev/null 2>&1 | sed -e 's/^/  /' | head -14; echo "exit ${PIPESTATUS[0]}")
echo "=== CONTROL: other package imports the exposed module Lib"
(cd $S/ctl && elm make src/Main.elm --output=/dev/null 2>&1 | sed -e 's/^/  /' | head -8; echo "exit ${PIPESTATUS[0]}")
echo "=== SAME package: build libpkg itself (Lib imports its hidden Lib.Internal.Secret)"
cp -r $L $S/libwork; (cd $S/libwork && elm make src/Lib.elm --output=/dev/null 2>&1 | tail -3; echo "exit ${PIPESTATUS[0]}")
