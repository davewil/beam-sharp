// 31b — Is ASP.NET Core's middleware pipeline assembled at compile time or at run time?
//
// Plug.Builder and Phoenix's pipe_through are macros: the stage set is fixed when the module
// compiles. The claim under test is that the C# half of beam-sharp's audience does it the other
// way — a pipeline built at run time out of function values.
//
// The probe assembles the stage set from an environment variable, which no compile-time
// mechanism can see, and prints what actually ran.

using System.Text;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
var app = builder.Build();

var log = new StringBuilder();

// A stage is a VALUE of type Func<HttpContext, RequestDelegate, Task>.
// Note the halt mechanism: a stage halts by NOT invoking `next`. Halting is control flow,
// not a value in a union and not a field on the request.
var catalogue = new Dictionary<string, Func<HttpContext, RequestDelegate, Task>>
{
    ["auth"] = async (ctx, next) =>
    {
        log.Append("auth>");
        if (!ctx.Request.Headers.ContainsKey("authorization"))
        {
            ctx.Response.StatusCode = 401;      // halt: produce a response
            await ctx.Response.WriteAsync("unauthorized");
            return;                             // ...and never call next
        }
        await next(ctx);
    },
    ["quota"] = async (ctx, next) =>
    {
        log.Append("quota>");
        await next(ctx);
    },
    ["trace"] = async (ctx, next) =>
    {
        log.Append("trace>");
        await next(ctx);
    },
};

// THE MEASUREMENT: the stage set is read from the environment at run time, after all
// compilation is done. Nothing here is knowable to a macro.
var configured = (Environment.GetEnvironmentVariable("STAGES") ?? "auth")
    .Split(',', StringSplitOptions.RemoveEmptyEntries);

foreach (var name in configured)
{
    app.Use(catalogue[name]);               // a function value, held in a dictionary, applied in a loop
}

app.Run(async ctx =>
{
    log.Append("router");
    await ctx.Response.WriteAsync($"ran: {log}");
});

// Drive one request in-process and print the result, rather than serving.
app.Urls.Add("http://127.0.0.1:5199");
_ = app.RunAsync();
await Task.Delay(1200);

using var client = new HttpClient();
var req = new HttpRequestMessage(HttpMethod.Get, "http://127.0.0.1:5199/");
if (Environment.GetEnvironmentVariable("AUTHED") == "1")
    req.Headers.Add("authorization", "bearer x");

var resp = await client.SendAsync(req);
Console.WriteLine($"STAGES={Environment.GetEnvironmentVariable("STAGES") ?? "auth"} " +
                  $"AUTHED={Environment.GetEnvironmentVariable("AUTHED") ?? "0"} " +
                  $"-> {(int)resp.StatusCode} {await resp.Content.ReadAsStringAsync()}");
await app.StopAsync();
