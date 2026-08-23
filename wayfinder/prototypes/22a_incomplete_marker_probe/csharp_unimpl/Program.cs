// Ticket 22 probe, C# half — the cases that COMPILE. The two that do not are
// held in ../variants/ and swapped in by run_csharp.sh.
//
// B# is C#-family, so C# is tier 1 on spelling. The question is position, and
// C# is the one surveyed language with genuine declaration-position members
// that have no body. This file measures whether any of them is used to mean
// "unfinished", and whether the compiler ever SAYS so.

using System;

public partial class Ledger
{
    // OLD-STYLE partial: no accessibility modifier, must return void. This is
    // the only bodiless declaration C# will leave unimplemented — and when it
    // is unimplemented the compiler says NOTHING and ERASES every call to it.
    // Silence is the opposite of what 23 §7 wants from a stub.
    partial void Audit(int order);

    public void Run(int order)
    {
        Audit(order); // erased at compile time if never implemented
    }
}

public abstract class Report
{
    // Declaration position, no body, and legal. But `abstract` means "a
    // subclass MUST supply this" — a contract, not an admission that the
    // author has not finished. Nothing greps it as incomplete.
    public abstract string Render();
}

public class Invoice
{
    // The idiom every C# codebase actually uses for "not written yet".
    // It is an EXPRESSION IN THE BODY; it typechecks at any return type
    // because `throw` is bottom-typed; and the compiler is silent at build
    // time. The failure is deferred to runtime.
    public int Total() => throw new NotImplementedException();
}

public static class Program
{
    public static void Main()
    {
        Console.WriteLine("built");
    }
}
