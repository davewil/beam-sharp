using System.Runtime.InteropServices;

// Ticket 32 sub-question 1 / 3: does C#'s own FFI construct carry BOTH
// spellings, and is the declaration a signature with no body?
internal static partial class Native
{
    // Classic. The C# name is PascalCase; EntryPoint names the foreign symbol.
    [DllImport("libc", EntryPoint = "getpid")]
    internal static extern int GetProcessId();

    // No EntryPoint: the C# name IS the foreign symbol, verbatim, no mapping.
    [DllImport("libc")]
    internal static extern int getppid();

    // Modern source-generated form (.NET 7+): `partial`, not `extern`.
    [LibraryImport("libc", EntryPoint = "getuid")]
    internal static partial uint GetUserId();

    // Two C# names over ONE foreign symbol, with different return types.
    [DllImport("libc", EntryPoint = "getpid")]
    internal static extern long GetProcessIdAsLong();
}

internal static class Program
{
    private static void Main()
    {
        Console.WriteLine($"getpid  via EntryPoint : {Native.GetProcessId()}");
        Console.WriteLine($"getppid via name       : {Native.getppid()}");
        Console.WriteLine($"getuid  via LibraryImport: {Native.GetUserId()}");
        Console.WriteLine($"getpid  declared long  : {Native.GetProcessIdAsLong()}");
    }
}
