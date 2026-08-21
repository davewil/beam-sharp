// 55a — C# 9 recursive patterns: does a property pattern take a TYPE in front
// and a BINDER after, in one pattern?
//
// This is the exact shape exemplar 25c asks for. Run it; do not reason about it.
//   dotnet run --project <csproj>   (or: dotnet script)
//
// What is being measured, in order:
//   1. Type prefix + property pattern + designation:  Frame { Type: X } f
//   2. The same WITHOUT the type prefix:              { Type: X } f
//   3. Whether the designation is usable in the arm body (it must bind the WHOLE
//      value, not the projected field).
//   4. Whether `var` is required in front of the designation.

using System;

enum FrameType { Method, Header, Body, Heartbeat }

record Frame(FrameType Type, int Channel, string Payload);

class Probe
{
    // (1) TYPE PREFIX + PROPERTY PATTERN + DESIGNATION
    static string WithTypePrefix(object o) => o switch
    {
        Frame { Type: FrameType.Method } f => $"method ch={f.Channel} payload={f.Payload}",
        Frame { Type: FrameType.Header } f => $"header ch={f.Channel}",
        _ => "other",
    };

    // (2) BARE PROPERTY PATTERN + DESIGNATION — no type named.
    //     C# allows this when the static type is already known.
    static string WithoutTypePrefix(Frame fr) => fr switch
    {
        { Type: FrameType.Method } f => $"bare-method ch={f.Channel}",
        { Type: FrameType.Header } f => $"bare-header ch={f.Channel}",
        _ => "bare-other",
    };

    // (3) Is the designation the WHOLE value or the projected field?
    //     If `f` were the field, `f.Channel` would not compile.
    static int WholeValue(object o) => o switch
    {
        Frame { Type: FrameType.Body } f => f.Channel,
        _ => -1,
    };

    // (4) Does the designation need a `var` keyword? Compare with a pure
    //     var-pattern, which DOES require it: `var f` binds anything.
    static string VarPattern(object o) => o switch
    {
        Frame { Channel: var ch } => $"var-in-position ch={ch}",
        _ => "no",
    };

    static void Main()
    {
        var m = new Frame(FrameType.Method, 7, "hello");
        var h = new Frame(FrameType.Header, 9, "");
        var b = new Frame(FrameType.Body, 11, "x");

        Console.WriteLine("1 type-prefix+designation : " + WithTypePrefix(m));
        Console.WriteLine("1 type-prefix+designation : " + WithTypePrefix(h));
        Console.WriteLine("2 bare+designation        : " + WithoutTypePrefix(m));
        Console.WriteLine("2 bare+designation        : " + WithoutTypePrefix(h));
        Console.WriteLine("3 designation is whole    : ch=" + WholeValue(b));
        Console.WriteLine("4 var inside position     : " + VarPattern(m));
    }
}
