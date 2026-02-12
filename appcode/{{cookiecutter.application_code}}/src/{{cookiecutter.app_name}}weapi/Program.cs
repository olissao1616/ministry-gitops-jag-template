using Serilog.Events;
using Serilog;
using System.Reflection;
using {{cookiecutter.app_name}}webapi.Configuration;
using Serilog.Sinks.SystemConsole.Themes;
using Serilog.Formatting.Json;
using Microsoft.AspNetCore.HttpLogging;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using {{cookiecutter.app_name}}webapi.Data;
using {{cookiecutter.app_name}}webapi.Features;
using NodaTime;
using {{cookiecutter.app_name}}webapi.Infrastructure.HttpClients;
using {{cookiecutter.app_name}}webapi.Infrastructure.Auth;
using {{cookiecutter.app_name}}webapi.Middleware;
using {{cookiecutter.app_name}}webapi.Extensions;

static void CreateLogger()
{

    var environmentName = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");

    var path = Environment.GetEnvironmentVariable("LogFilePath") ?? "logs";

    var config = new ConfigurationBuilder()
     .AddJsonFile("appsettings.json", optional: true)
     .AddJsonFile($"appsettings.{environmentName}.json", optional: true)
     .Build();

    try
    {
        if ({{cookiecutter.app_name}}webapiConfiguration.IsDevelopment())
        {
            Directory.CreateDirectory(path);
        }
    }
    catch (Exception e)
    {
        Console.WriteLine("Creating the logging directory failed: {0}", e.ToString());
    }

    var name = Assembly.GetExecutingAssembly().GetName();
    var outputTemplate = "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}";

    var loggerConfiguration = new LoggerConfiguration()
        .MinimumLevel.Information()
        .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
        .MinimumLevel.Override("Microsoft.Hosting.Lifetime", LogEventLevel.Information)
        .MinimumLevel.Override("System", LogEventLevel.Warning)
        .Enrich.FromLogContext()
        .Enrich.WithMachineName()
        .Enrich.WithProperty("Assembly", $"{name.Name}")
        .Enrich.WithProperty("Version", $"{name.Version}")
        .WriteTo.Console(
            outputTemplate: outputTemplate,
            theme: AnsiConsoleTheme.Code)
        .WriteTo.Async(a => a.File(
            $@"{path}/{{cookiecutter.app_name}}webapi.log",
            outputTemplate: outputTemplate,
            rollingInterval: RollingInterval.Day,
            shared: true))
        .WriteTo.Async(a => a.File(
            new JsonFormatter(),
            $@"{path}/{{cookiecutter.app_name}}webapi.json",
            rollingInterval: RollingInterval.Day));



    Log.Logger = loggerConfiguration.CreateLogger();


}
CreateLogger();

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

var config = InitializeConfiguration(builder.Services);

builder.Services
        .AddHttpClients(config)
        .AddKeycloakAuth(config) // base DIAM authentication service
                                 //.AddScoped<I{{cookiecutter.app_name}}webapiAuthorizationService, {{cookiecutter.app_name}}webapiAuthorizationService>() // you can implement authorization middleware
        .AddSingleton<IClock>(SystemClock.Instance);


builder.Services.AddProblemDetails(options =>
  options.CustomizeProblemDetails = ctx =>
  {
      ctx.ProblemDetails.Extensions.Add("request-id", ctx.HttpContext.TraceIdentifier);
      ctx.ProblemDetails.Extensions.Add("instance", $"{ctx.HttpContext.Request.Method} {ctx.HttpContext.Request.Path}");
  });


builder.Services.AddExceptionHandler<ExceptionToProblemDetailsHandler>();


builder.Host.UseSerilog();


builder.Services.AddHttpLogging(loggingOptions =>
{
    loggingOptions.LoggingFields = builder.Environment.IsDevelopment() ? HttpLoggingFields.All : HttpLoggingFields.Request;
});



builder.Services.AddDbContext<{{cookiecutter.app_name}}webapiDataContext>(options => options
    .UseNpgsql(config.ConnectionStrings.{{cookiecutter.app_name}}webapiDatabase, npg => npg.UseNodaTime())
    .EnableSensitiveDataLogging(sensitiveDataLoggingEnabled: false));


builder.Services.Scan(scan => scan
    .FromAssemblyOf<Program>()
    .AddClasses(classes => classes.AssignableTo<IRequestHandler>())
    .AsImplementedInterfaces()
    .WithTransientLifetime());

builder.Services.AddSingleton<IHttpContextAccessor, HttpContextAccessor>();
builder.Services.AddHealthChecks();

{{cookiecutter.app_name}}webapiConfiguration InitializeConfiguration(IServiceCollection services)
{
    var config = new {{cookiecutter.app_name}}webapiConfiguration();
    builder.Configuration.Bind(config);
    services.AddSingleton(config);

    Log.Logger.Information("### App Version:{0} ###", Assembly.GetExecutingAssembly().GetName().Version);
    Log.Logger.Information("### Web Api Service Configuration:{0} ###", JsonSerializer.Serialize(config));

    return config;
}


builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

app.UseExceptionHandler();

app.UseSerilogRequestLogging(options => options.EnrichDiagnosticContext = (diagnosticContext, httpContext) =>
{
    var userId = httpContext.User.GetUserId();
    if (!userId.Equals(Guid.Empty))
    {
        diagnosticContext.Set("User", userId);
    }
});

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseRouting();

app.UseHttpsRedirection();

app.UseAuthentication();
app.UseAuthorization();

app.MapHealthChecks("/api/healthz").AllowAnonymous();


app.MapControllers();

app.Run();
