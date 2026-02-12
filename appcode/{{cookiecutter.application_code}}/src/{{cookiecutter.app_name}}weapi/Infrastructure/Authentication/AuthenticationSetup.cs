namespace {{cookiecutter.app_name}}webapi.Infrastructure.Auth;

using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using {{cookiecutter.app_name}}webapi.Configuration;
using {{cookiecutter.app_name}}webapi.Exceptions;
using {{cookiecutter.app_name}}webapi.Extensions;

public static class AuthenticationSetup
{
    public static IServiceCollection AddKeycloakAuth(this IServiceCollection services, {{cookiecutter.app_name}}webapiConfiguration config)
    {

        services.ThrowIfNull(nameof(services));
        config.ThrowIfNull(nameof(config));

        // fix for dotnet 8
        Microsoft.IdentityModel.JsonWebTokens.JsonWebTokenHandler.DefaultInboundClaimTypeMap.Clear();

        //JwtSecurityTokenHandler.DefaultInboundClaimTypeMap.Clear();

        _ = services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options =>
        {
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                ValidateAudience = false,
                ValidateIssuer = true,
                ValidAlgorithms = ["RS256"],
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes("your-signing-key")) // for prod, get valid signing key from DIAM

            };
            options.Authority = config.Keycloak.RealmUrl;
            options.IncludeErrorDetails = true;
            options.RequireHttpsMetadata = true;
            options.Audience = config.Keycloak.{{cookiecutter.app_name}}webapiClientId;
            options.MetadataAddress = config.Keycloak.WellKnownConfig;

            options.RequireHttpsMetadata = !{{cookiecutter.app_name}}webapiConfiguration.IsDevelopment();
            options.Events = new JwtBearerEvents
            {
                OnTokenValidated = async context => await OnTokenValidatedAsync(context, config.Keycloak.{{cookiecutter.app_name}}webapiClientId),
                OnAuthenticationFailed = async context => await OnAuthenticationFailedAsync(context),
                OnForbidden = context =>
                {
                    return Task.CompletedTask;
                },
                OnChallenge = async context => await OnChallengeAsync(context)
            };
        });


        // DIAM Certificate logins
        services.AddAuthorizationBuilder().AddPolicy(Policies.BcpsAuthentication, policy => policy.RequireAuthenticatedUser()
                          .RequireClaim(Claims.IdentityProvider, ClaimValues.Bcps));

        // DIAM : Is JUSTIN USER Policy
        services.AddAuthorizationBuilder().AddPolicy(Policies.JUSTINUSER, policy => policy.RequireAuthenticatedUser().RequireAssertion(context =>
        {
            var hasRole = context.User.IsInRole(Roles.Admin);
            var hasClaim = context.User.HasClaim(c => c.Type == Claims.IdentityProvider &&
                                                       (
                                                        c.Value == ClaimValues.Bcps));
            return hasRole && hasClaim;
        }));

        services.AddAuthorizationBuilder()
            .AddPolicy(Policies.JUSTINUSER, policy =>
            {
                policy.RequireAuthenticatedUser();
                policy.RequireAssertion(context =>
                {
                    // Check if the user has the "justin-participant" claim
                    var justinParticipantClaim = context.User.Claims.FirstOrDefault(c => c.Type == Claims.JustinParticipant);

                    if (justinParticipantClaim != null)
                    {
                        // Deserialize the JSON string into a JObject
                        var jsonClaimValue = justinParticipantClaim.Value;
                        var jsonObject = JObject.Parse(jsonClaimValue);

                        // Read the value of "partId" property. This claim also contain JUSTIN ROLES, you can check for role
                        var partIdValue = jsonObject["partId"];

                        // Check if "partId" exists and is not null or empty
                        if (partIdValue != null && !string.IsNullOrEmpty(partIdValue.ToString()))
                        {
                            // Optionally, you can parse the "partId" to the appropriate data type if needed
                            // Example: int partId = int.Parse(partIdValue.ToString());

                            return true; // Return true if "partId" exists and is not null or empty

                        }
                    }

                    throw new JustinUserException(
                        message: $"User {context.User.Claims.FirstOrDefault(c => c.Type == Claims.GivenName)!.Value} is not a valid JUSTIN user.",
                        details: $"User {context.User.Claims.FirstOrDefault(c => c.Type == Claims.GivenName)!.Value} lacks required justin-participant claims or data."
                        ); // Return false if "partId" does not exist or is null but we thrown excpetion that will be handled by the middleware
                });
            });


        // DIAM BC services card policy
        services.AddAuthorizationBuilder().AddPolicy(Policies.BcscAuthentication, policy => policy.RequireAuthenticatedUser().RequireClaim(Claims.IdentityProvider, ClaimValues.BCServicesCard));


        // requires IDIR login
        services.AddAuthorizationBuilder().AddPolicy(Policies.IdirAuthentication, policy => policy.RequireAuthenticatedUser()
                        .RequireClaim(Claims.IdentityProvider, ClaimValues.Idir));


        // admin users
        services.AddAuthorizationBuilder().AddPolicy(Policies.AdminAuthentication, policy => policy.RequireAuthenticatedUser().RequireAssertion(context =>
        {
            var hasRole = context.User.IsInRole(Roles.Admin);
            var hasClaim = context.User.HasClaim(c => c.Type == Claims.IdentityProvider &&
                                                       (
                                                        c.Value == ClaimValues.Bcps));
            return hasRole && hasClaim;
        }));



        // fallback policy
        services.AddAuthorizationBuilder().AddFallbackPolicy("fallback", policy => policy.RequireAuthenticatedUser());


        return services;
    }

    private static Task OnForbidden(ForbiddenContext context)
    {
        Serilog.Log.Warning($"Authentication challenge");
        return Task.CompletedTask;
    }

    private static Task OnChallengeAsync(JwtBearerChallengeContext context)
    {

        context.HandleResponse();
        context.Response.StatusCode = StatusCodes.Status401Unauthorized;
        context.Response.ContentType = "application/json";
        if (string.IsNullOrEmpty(context.Error))
            context.Error = "invalid_token";
        if (string.IsNullOrEmpty(context.ErrorDescription))
            context.ErrorDescription = "This request requires a valid JWT access token to be provided";

        return context.Response.WriteAsync(JsonConvert.SerializeObject(new
        {
            error = context.Error,
            error_description = context.ErrorDescription
        }));

    }

    private static Task OnAuthenticationFailedAsync(AuthenticationFailedContext context)
    {
        context.Response.OnStarting(async () =>
        {
            context.NoResult();
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            context.Response.ContentType = "application/json";
            string response = JsonConvert.SerializeObject("The access token provided is not valid.");

            if (context.Exception is SecurityTokenExpiredException)
            {
                context.Response.Headers.Append("Token-Expired", "true");
                response = JsonConvert.SerializeObject("The access token provided has expired.");
            }

            await context.Response.WriteAsync(response);
        });

        return Task.CompletedTask;
    }


    private static Task OnAuthenticationFailure(AuthenticationFailedContext context)
    {
        Serilog.Log.Warning($"Authentication failure {context.HttpContext.Request.Path}");
        return Task.CompletedTask;
    }

    private static Task OnTokenValidatedAsync(TokenValidatedContext context, string clientId)
    {
        if (context.Principal?.Identity is ClaimsIdentity identity
            && identity.IsAuthenticated)
        {
            // Flatten the Resource Access claim and add to identity. You can use the this later
            identity.AddClaims(identity.GetResourceAccessRoles(clientId)
                .Select(role => new Claim(ClaimTypes.Role, role)));
        }

        return Task.CompletedTask;
    }


}
