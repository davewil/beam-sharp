// Ticket 42 — what does C#'s `4..7` actually denote, and where is it legal?
//
// Run: dotnet run     (measured on dotnet 9.0.306, macOS, 2026-08-15)
//
// Measured output:
//   a[4..7]        = [4, 5, 6]
//   (4..7).Start   = 4   .End = 7
//   offset/length  = 4 / 3
//   Classify(7)    = reserved   (relational: 7 IS included)
//   Classify(255)  = reserved   (relational: 255 IS included)
//   Shape([1,2,3]) = head 1 then 2 more   (`..` here means THE REST)
//
// And, with the `foreach` at the bottom uncommented:
//   error CS1579: foreach statement cannot operate on variables of type 'Range'
//   because 'Range' does not contain a public instance or extension definition
//   for 'GetEnumerator'
//
// Conclusion: `4..7` is a slice specification over INDICES, not a set of
// integers. It is not enumerable and GetOffsetAndLength needs a collection
// length before it means anything — so "does 4..7 include 7" is a question the
// construct cannot answer. C#'s numeric-span construct is the RELATIONAL
// pattern, inclusive at both ends; and in PATTERN position C#'s `..` already
// means "the rest", which is what beam-sharp took in ticket 28 §5.

int[] a = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

// 1. `4..7` as a slice: which elements come back?
Console.WriteLine("a[4..7]        = [" + string.Join(", ", a[4..7]) + "]");

// 2. The Range value itself — note End is 7 but the length is 3.
System.Range r = 4..7;
Console.WriteLine("(4..7).Start   = " + r.Start + "   .End = " + r.End);
var (off, len) = r.GetOffsetAndLength(a.Length);
Console.WriteLine("offset/length  = " + off + " / " + len);

// 3. C#'s actual numeric-range PATTERN is relational, not `..`.
static string Classify(int n) => n switch
{
    1 => "method",
    2 => "header",
    3 => "body",
    8 => "heartbeat",
    0 => "reserved",
    >= 4 and <= 7 => "reserved",
    >= 9 and <= 255 => "reserved",
    _ => "out of range",
};

Console.WriteLine("Classify(7)    = " + Classify(7) + "   (relational: 7 IS included)");
Console.WriteLine("Classify(255)  = " + Classify(255) + "   (relational: 255 IS included)");

// 4. In PATTERN position, what does `..` mean in C#? The same thing
//    beam-sharp already uses it for.
static string Shape(int[] xs) => xs switch
{
    [var only] => "one element: " + only,
    [var first, .. var rest] => "head " + first + " then " + rest.Length + " more",
    [] => "empty",
};

Console.WriteLine("Shape([1,2,3]) = " + Shape(new[] { 1, 2, 3 }) + "   (`..` here means THE REST)");

// 5. Is a Range a set of VALUES? Uncomment to see CS1579 — it is not.
// foreach (var v in 4..7) { Console.WriteLine(v); }
