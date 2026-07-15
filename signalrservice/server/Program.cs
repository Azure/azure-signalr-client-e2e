using IntegrationTest.Hubs;
#if USE_AZURE_SIGNALR
using Microsoft.Azure.SignalR;
#endif

var builder = WebApplication.CreateBuilder(args);
builder.Services
    .AddSignalR()
#if USE_AZURE_SIGNALR
    .AddAzureSignalR(options =>
    {
        // Use a unique ApplicationName per CI run to isolate hub namespaces
        // in Azure SignalR Service, preventing cross-run message leaks.
        var appName = Environment.GetEnvironmentVariable("ASRS_APP_NAME");
        if (!string.IsNullOrEmpty(appName))
        {
            options.ApplicationName = appName;
        }
    })
#endif
    .AddMessagePackProtocol();

#if USE_AZURE_SIGNALR
builder.Services.AddControllers();
#endif

var app = builder.Build();

app.UseRouting();
app.MapHub<TestHub>("/test");
app.MapHub<TestHubJava>("/test-java");
app.MapHub<TestHubSwift>("/test-swift");

app.Run();