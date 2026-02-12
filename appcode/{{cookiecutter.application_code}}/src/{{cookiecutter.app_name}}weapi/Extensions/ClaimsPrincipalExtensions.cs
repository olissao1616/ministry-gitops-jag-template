namespace {{cookiecutter.app_name}}webapi.Extensions;

using Newtonsoft.Json.Linq;
using NodaTime;
using NodaTime.Text;
using System.Security.Claims;
using System.Text.Json;

using {{cookiecutter.app_name}}webapi.Infrastructure.Auth;

public static class ClaimsPrincipalExtensions
{
    /// <summary>
    /// Returns the UserId of the logged in user (from the 'sub' claim). If there is no logged in user, this will return Guid.Empty
    /// </summary>
    public static Guid GetUserId(this ClaimsPrincipal? user)
    {
        var userId = user?.FindFirstValue(Claims.Subject);

        return Guid.TryParse(userId, out var parsed)
            ? parsed
            : Guid.Empty;
    }
    /// <summary>
    /// Get users Firstname
    /// </summary>
    /// <param name="user"></param>
    /// <returns></returns>
    public static string GetFirstName(this ClaimsPrincipal? user)
    {
        var userId = user?.FindFirstValue(Claims.GivenName);

        if (string.IsNullOrEmpty(userId))
        {
            throw new Exception($"Access token must contain a {Claims.GivenName} claim");
        }
        else
        {
            return userId;
        }
    }
    public static string GetLastName(this ClaimsPrincipal? user)
    {
        var userId = user?.FindFirstValue(Claims.FamilyName);

        if (string.IsNullOrEmpty(userId))
        {
            throw new Exception($"Access token must contain a {Claims.FamilyName} claim");
        }
        else
        {
            return userId;
        }
    }
    public static string GetEmail(this ClaimsPrincipal? user)
    {
        var userId = user?.FindFirstValue(Claims.Email);

        if (string.IsNullOrEmpty(userId))
        {
            throw new Exception($"Access token must contain a {Claims.Email} claim");
        }
        else
        {
            return userId;
        }
    }
    /// <summary>
    /// Returns the Birthdate Claim of the User, parsed in ISO format (yyyy-MM-dd)
    /// </summary>
    public static LocalDate? GetBirthdate(this ClaimsPrincipal user)
    {
        var birthdate = user.FindFirstValue(Claims.Birthdate);

        var parsed = LocalDatePattern.Iso.Parse(birthdate!);
        if (parsed.Success)
        {
            return parsed.Value;
        }
        else
        {
            return null;
        }
    }

    /// <summary>
    /// Returns the Gender Claim of the User, parsed in ISO format (M/F)
    /// </summary>
    public static string? GetGender(this ClaimsPrincipal user)
    {
        var gender = user.FindFirstValue(Claims.Gender);

        if (string.IsNullOrEmpty(gender))
            return null;

        return gender;
    }

    /// <summary>
    /// Returns the Identity Provider of the User, or null if User is null
    /// </summary>
    public static string? GetIdentityProvider(this ClaimsPrincipal? user) => user?.FindFirstValue(Claims.IdentityProvider);

    /// <summary>
    /// check wheather the user is a valid bcps user using ad groups
    /// </summary>
    /// <param name="user"></param>
    /// <returns></returns>
    public static IEnumerable<string> GetUserRoles(this ClaimsIdentity identity)
    {
        var roleClaim = identity.Claims
           .SingleOrDefault(claim => claim.Type == Claims.ResourceAccess)
           ?.Value;

        if (string.IsNullOrWhiteSpace(roleClaim))
        {
            return [];
        }

        try
        {


            var userRoles = JsonSerializer.Deserialize<Dictionary<string, ResourceAccess>>(roleClaim, new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase });

            return userRoles?.TryGetValue(roleClaim, out var access) == true
                ? access.Roles
                : Enumerable.Empty<string>();
        }
        catch
        {
            return Enumerable.Empty<string>();
        }
    }

    public static IEnumerable<string> GetKeycloakRoles(this ClaimsPrincipal? user)
    {
        if (user == null)
            return Enumerable.Empty<string>();

        var keycloakRoles = new List<string>();

        // Find claims representing Keycloak roles
        var roleClaims = user.Claims.Where(c => c.Type == Claims.RealmAcess || c.Type == Claims.ResourceAccess|| c.Type == Claims.JustinParticipant);

        foreach (var claim in roleClaims)
        {
            if (!string.IsNullOrEmpty(claim.Value))
            {
                var jsonObject = JObject.Parse(claim.Value);

                // If it's a realm_access claim, get the roles directly
                if (claim.Type == Claims.RealmAcess)
                {
                    var roles = jsonObject[Claims.Roles]?.ToObject<List<string>>();
                    if (roles != null)
                        keycloakRoles.AddRange(roles);
                }
                // If it's a resource_access claim, get the roles from each resource
                else if (claim.Type == Claims.ResourceAccess)
                {
                    foreach (var resource in jsonObject)
                    {
                        var roles = resource.Value![Claims.Roles]?.ToObject<List<string>>();
                        if (roles != null)
                            keycloakRoles.AddRange(roles);
                    }
                }

                // If it's a justin-participant claim, extract roles
                else if (claim.Type == Claims.JustinParticipant)
                {
                    var roles = jsonObject[Claims.Roles]?.ToObject<List<string>>();
                    if (roles != null)
                        keycloakRoles.AddRange(roles);
                }
            }
        }

        return keycloakRoles;
    }
    /// <summary>
    /// Parses the Resource Access claim and returns the roles for the given resource
    /// </summary>
    /// <param name="resourceName">The name of the resource to retrive the roles from</param>
    public static IEnumerable<string> GetResourceAccessRoles(this ClaimsIdentity identity, string resourceName)
    {
        var resourceAccessClaim = identity.Claims
            .SingleOrDefault(claim => claim.Type == Claims.ResourceAccess)
            ?.Value;

        if (string.IsNullOrWhiteSpace(resourceAccessClaim))
        {
            return Enumerable.Empty<string>();
        }

        try
        {
            var resources = JsonSerializer.Deserialize<Dictionary<string, ResourceAccess>>(resourceAccessClaim, new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase });

            return resources?.TryGetValue(resourceName, out var access) == true
                ? access.Roles
                : Enumerable.Empty<string>();
        }
        catch
        {
            return Enumerable.Empty<string>();
        }
    }

    private class ResourceAccess
    {
        public IEnumerable<string> Roles { get; set; } = Enumerable.Empty<string>();
    }
    public static JustinParticipant GetJustinParticipant(this ClaimsPrincipal user)
    {
        var justinParticipantClaim = user?.Claims.FirstOrDefault(c => c.Type == Claims.JustinParticipant);

        if (justinParticipantClaim == null)
        {
            return new JustinParticipant();
        }

        return JsonSerializer.Deserialize<JustinParticipant>(justinParticipantClaim.Value, new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase })!;
    }
    public class JustinParticipant
    {
        public decimal PartId { get; set; }
        public string UserId { get; set; } = string.Empty;
        public List<string> AgencyAssignments { get; set; } = [];
        public List<string> Roles { get; set; } = [];
    }
}
