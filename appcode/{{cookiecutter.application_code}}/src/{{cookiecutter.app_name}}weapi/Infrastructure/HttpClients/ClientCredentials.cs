namespace {{cookiecutter.app_name}}webapi.Infrastructure.HttpClients;

using IdentityModel.Client;

public class ChesClientCredentials : ClientCredentialsTokenRequest { }
public class KeycloakAdministrationClientCredentials : ClientCredentialsTokenRequest { }
public class InternalHttpRequestCredentials : ClientCredentialsTokenRequest { }
