namespace {{cookiecutter.app_name}}webapi.Infrastructure.HttpClients;

using IdentityModel.Client;

public interface IAccessTokenClient
{
    Task<string> GetAccessTokenAsync(ClientCredentialsTokenRequest request);
}
