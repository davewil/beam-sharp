#!/usr/bin/env bash
# NEIGHBOUR (installed, measured): Java modules' QUALIFIED EXPORT `exports pkg to friend;` is a
# callee-declared NAMED LIST, enforced by javac. It is the shape of candidate B.
# REFUTED (as an enforcing named list) IF: javac accepts `stranger` importing the qualified-exported package.
. "$(dirname "$0")/lib.sh"
J="$WORK/java"; rm -rf "${J:?}"; mkdir -p "$J"/src/{lib/lib/api,lib/lib/internal,friend/friend,stranger/stranger}; cd "$J" || exit 1
javac -version 2>&1 | grep -v JAVA_TOOL
export JAVA_TOOL_OPTIONS=
cat > src/lib/module-info.java <<'EOT'
module lib {
    exports lib.api;
    exports lib.internal to friend;
}
EOT
cat > src/lib/lib/api/Api.java <<'EOT'
package lib.api;
public class Api { public static int total(int[] xs) { return lib.internal.Calc.recompute(xs); } }
EOT
cat > src/lib/lib/internal/Calc.java <<'EOT'
package lib.internal;
public class Calc { public static int recompute(int[] xs) { int s = 0; for (int x : xs) s += x; return s; } }
EOT
for m in friend stranger; do
cat > src/$m/module-info.java <<EOT
module $m { requires lib; }
EOT
cat > src/$m/$m/Use.java <<EOT
package $m;
public class Use { public static int peek(int[] xs) { return lib.internal.Calc.recompute(xs); } }
EOT
done
echo '--- javac, module-source-path, all three modules (friend is listed; stranger is not)'
javac -d out --module-source-path src $(find src -name '*.java') 2>&1 | head -12; rc=${PIPESTATUS[0]}; echo "exit=$rc"
echo '--- friend alone (control)'
javac -d out2 --module-source-path src $(find src/lib src/friend -name '*.java') 2>&1 | head; echo "exit=${PIPESTATUS[0]}"
[ "$rc" -ne 0 ]; verdict "java-qualified-export-is-an-enforced-named-list" $?
