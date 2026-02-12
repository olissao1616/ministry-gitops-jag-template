namespace {{cookiecutter.app_name}}webapi.Infrastructure.HttpClients;

using IdentityModel.Client;
using {{cookiecutter.app_name}}webapi.Configuration;
using {{cookiecutter.app_name}}webapi.Extensions;
using {{cookiecutter.app_name}}webapi.Infrastructure.HttpClients.Keycloak;



public static class HttpClientSetup
{
    public static IServiceCollection AddHttpClients(this IServiceCollection services, {{cookiecutter.app_name}}webapiConfiguration config)
    {
        services.AddHttpClient<IAccessTokenClient, AccessTokenClient>();

        // Do you want to use CHES Email Service enable this

        //services.AddHttpClientWithBaseAddress<IChesClient, ChesClient>(config.ChesClient.Url)
        //    .WithBearerToken(new ChesClientCredentials
        //    {
        //        Address = config.ChesClient.TokenUrl,
        //        ClientId = config.ChesClient.ClientId,
        //        ClientSecret = config.ChesClient.ClientSecret
        //    });

        

        services.AddHttpClientWithBaseAddress<IKeycloakAdministrationClient, KeycloakAdministrationClient>(config.Keycloak.AdministrationUrl)
            .WithBearerToken(new KeycloakAdministrationClientCredentials
            {
                Address = config.Keycloak.TokenUrl,
                ClientId = config.Keycloak.AdministrationClientId,
                ClientSecret = config.Keycloak.AdministrationClientSecret
            });

        return services;
    }

    public static IHttpClientBuilder AddHttpClientWithBaseAddress<TClient, TImplementation>(this IServiceCollection services, string baseAddress)
        where TClient : class
        where TImplementation : class, TClient
        => services.AddHttpClient<TClient, TImplementation>(client => client.BaseAddress = new Uri(baseAddress.EnsureTrailingSlash()));

    public static IHttpClientBuilder WithBearerToken<T>(this IHttpClientBuilder builder, T credentials) where T : ClientCredentialsTokenRequest
    {
        builder.Services.AddSingleton(credentials)
            .AddTransient<BearerTokenHandler<T>>();

        builder.AddHttpMessageHandler<BearerTokenHandler<T>>();

        return builder;
    }
}
