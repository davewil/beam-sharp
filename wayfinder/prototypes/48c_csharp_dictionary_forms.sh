#!/usr/bin/env bash
# PROTOTYPE 48c — what C# offers on maps: a pattern form, and a name.
#
# Throwaway. Ticket 48, the C# arm of the borrow survey.
#
# Ticket 48's survey stub says of C#: "Dictionary<K,V> and the frozen
# collections; no pattern form worth borrowing, but the *naming* question
# (`map` versus `dict`) is a tier-1 borrow decision."
#
# Both halves are claims. This runs them:
#
#   1. CONTROL — does C# enforce exhaustiveness at all? (if it does not, C#
#      is not a source for 48's hard question and the arm must say so)
#   2. Is there a pattern form over a Dictionary — property, indexer, list?
#   3. What does the BCL actually NAME these types? (reflection, not memory)
#   4. What does C# name the map FUNCTION — the collision beam-sharp will
#      hit the day it gets List.Map?
#
#   ./48c_csharp_dictionary_forms.sh
#
# Requires: dotnet SDK (measured on 9.0.306). Runs in a temp dir.
set -uo pipefail

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK" || exit 1

echo "creating a scratch console project..."
dotnet new console -o probe48 --force >/dev/null 2>&1 || { echo "dotnet new failed"; exit 1; }
cd probe48 || exit 1

# Overwrite Program.cs with one body and build. The compiler's own text is
# the evidence, so error lines are printed verbatim.
cs_probe () {
    local name="$1" body="$2"
    printf '%s\n' "$body" > Program.cs
    echo "--- $name ---"
    if dotnet build --nologo -v q 2>&1 | grep -E "error|warning CS" | sed 's/^/    /' | head -12; then
        :
    fi
    if dotnet build --nologo -v q >/dev/null 2>&1; then
        echo "    COMPILES"
    else
        echo "    REFUSED (text above)"
    fi
    echo
}

echo "==============================================================="
echo "1. CONTROL — does C# enforce exhaustiveness?"
echo "==============================================================="
echo "    Gleam refuses an incomplete case outright. If C# only warns, then"
echo "    C# never had to answer 48's question and cannot be cited on it."

cs_probe "a switch expression over an enum, one case MISSING" '
enum Colour { Red, Green, Blue }

class P {
    static string Describe(Colour c) => c switch {
        Colour.Red => "red",
        Colour.Green => "green",
    };
    static void Main() => System.Console.WriteLine(Describe(Colour.Red));
}
'

echo "==============================================================="
echo "2. Is there a pattern form over a Dictionary?"
echo "==============================================================="

cs_probe "property pattern on Count" '
using System.Collections.Generic;

class P {
    static string F(Dictionary<string,int> d) => d switch {
        { Count: 0 } => "empty",
        _ => "not empty",
    };
    static void Main() => System.Console.WriteLine(F(new Dictionary<string,int>()));
}
'

cs_probe "indexer pattern — matching on a KEY" '
using System.Collections.Generic;

class P {
    static string F(Dictionary<string,int> d) => d switch {
        { ["a"]: var v } => "a = " + v,
        _ => "no a",
    };
    static void Main() => System.Console.WriteLine(F(new Dictionary<string,int>()));
}
'

cs_probe "list pattern over a Dictionary" '
using System.Collections.Generic;

class P {
    static string F(Dictionary<string,int> d) => d switch {
        [] => "empty",
        [_, ..] => "some",
        _ => "other",
    };
    static void Main() => System.Console.WriteLine(F(new Dictionary<string,int>()));
}
'

echo "==============================================================="
echo "3 + 4. What does the BCL NAME these things?"
echo "==============================================================="
echo "    Reflection over the loaded framework, not recollection."

cat > Program.cs <<'CSEOF'
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

class P {
    static void Main() {
        // Force the relevant assemblies to load before we enumerate them.
        _ = new Dictionary<string,int>();
        _ = System.Collections.Immutable.ImmutableDictionary<string,int>.Empty;
        _ = System.Collections.Frozen.FrozenDictionary<string,int>.Empty;
        _ = new System.Collections.Concurrent.ConcurrentDictionary<string,int>();

        Console.WriteLine("  --- 3. every public BCL type whose name says Dictionary or Map ---");
        var names = AppDomain.CurrentDomain.GetAssemblies()
            .SelectMany(a => { try { return a.GetExportedTypes(); }
                               catch { return Array.Empty<Type>(); } })
            .Select(t => t.Name)
            .Where(n => n.Contains("Dictionary") || n.Contains("Map") || n == "ILookup`2")
            .Select(n => n.Split('`')[0])
            .Distinct()
            .OrderBy(n => n)
            .ToList();

        foreach (var n in names.Where(n => n.Contains("Dictionary")))
            Console.WriteLine("      " + n);

        var mapNamed = names.Where(n => n.Contains("Map")).ToList();
        Console.WriteLine("      types named *Map*: " +
            (mapNamed.Count == 0 ? "(none)" : string.Join(", ", mapNamed)));

        Console.WriteLine();
        Console.WriteLine("  --- 4. what is the map FUNCTION called in LINQ? ---");
        var linq = typeof(Enumerable).GetMethods(BindingFlags.Public | BindingFlags.Static)
            .Select(m => m.Name).Distinct().ToList();
        Console.WriteLine("      Enumerable.Select exists?  " + linq.Contains("Select"));
        Console.WriteLine("      Enumerable.Map exists?     " + linq.Contains("Map"));
        Console.WriteLine("      Enumerable.ToDictionary?   " + linq.Contains("ToDictionary"));
        Console.WriteLine();
        Console.WriteLine("      So C# has no name collision to resolve: the TYPE is");
        Console.WriteLine("      Dictionary and the FUNCTION is Select. It never had to");
        Console.WriteLine("      choose between them.");
    }
}
CSEOF

# The reflection probe needs the immutable/frozen packages present.
dotnet add package System.Collections.Immutable >/dev/null 2>&1
echo
dotnet run --nologo -v q 2>&1 | sed 's/^/  /'

echo
echo "done."
