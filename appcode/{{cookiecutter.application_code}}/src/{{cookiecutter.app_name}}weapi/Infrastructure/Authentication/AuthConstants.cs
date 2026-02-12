namespace {{cookiecutter.app_name}}webapi.Infrastructure.Auth;

public static class Claims
{
    public const string Address = "address";
    public const string Birthdate = "birthdate";
    public const string Gender = "gender";
    public const string Email = "email";
    public const string FamilyName = "family_name";
    public const string GivenName = "given_name";
    public const string GivenNames = "given_names";
    public const string IdentityProvider = "identity_provider";
    public const string PreferredUsername = "preferred_username";
    public const string ResourceAccess = "resource_access";
    public const string RealmAcess = "realm_access";
    public const string Subject = "sub";
    public const string Roles = "roles";

    public const string JustinParticipant = "justin-participant";


}

public static class DefaultRoles
{
    
}

/// <summary>
/// Configure policy-based access control for controller
/// Add more policy as desired
/// </summary>

public static class Policies
{
    public const string BcscAuthentication = "bcsc-authentication-policy";
    public const string IdirAuthentication = "idir-authentication-policy";
    public const string SubAgencyIdentityProvider = "subgency-idp-policy";
    public const string VerifiedCredentialsProvider = "verified-credentials-authentication-policy";
    public const string BcpsAuthentication = "bcps-authentication-policy";
    public const string AdminAuthentication = "admin-authentication-policy";

    // JUSTIN POLICY
    public const string JUSTINUSER = "valid-justin-user";


}

/// <summary>
/// DIAM returns the IDP Alais to the client
/// </summary>
public static class ClaimValues
{
    public const string BCServicesCard = "bcsc";
    public const string Idir = "idir";
    public const string AzureAd = "azuread";
    public const string Bcps = "adfscert";


}
public static class Roles
{
    // {{cookiecutter.app_name}}webapi Role Placeholders
    public const string Admin = "ADMIN";
    public const string User = "USER";



}

