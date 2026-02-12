namespace {{cookiecutter.app_name}}webapi.Infrastructure.HttpClients.Keycloak;

using global::Keycloak.Net.Models.RealmsAdmin;

public interface IKeycloakAdministrationClient
{
    /// <summary>
    /// Assigns a Client Role to the user, if it exists.
    /// Returns true if the operation was successful.
    /// </summary>
    /// <param name="userId"></param>
    /// <param name="clientId"></param>
    /// <param name="roleName"></param>
    Task<bool> AssignClientRole(Guid userId, string clientId, string roleName);

    /// <summary>
    /// Assigns a realm-level role to the user, if it exists.
    /// Returns true if the operation was successful.
    /// </summary>
    /// <param name="userId"></param>
    /// <param name="roleName"></param>
    Task<bool> AssignRealmRole(Guid userId, string roleName);

    /// <summary>
    /// Gets the Keycloak Client representation by ClientId.
    /// Returns null if unsuccessful.
    /// </summary>
    /// <param name="clientId"></param>
    Task<Client?> GetClient(string clientId);

    /// <summary>
    /// Gets the Keycloak Client Role representation by name.
    /// Returns null if unsuccessful or if no roles of that name exist on the client.
    /// </summary>
    /// <param name="clientId"></param>
    /// <param name="roleName"></param>
    Task<Role?> GetClientRole(string clientId, string roleName);

    /// <summary>
    /// Gets the Keycloak Role representation by name.
    /// Returns null if unsuccessful.
    /// </summary>
    /// <param name="roleName"></param>
    Task<Role?> GetRealmRole(string roleName);

    /// <summary>
    /// Gets the Keycloak User Representation for the user.
    /// Returns null if unsuccessful.
    /// </summary>
    /// <param name="userId"></param>
    Task<UserRepresentation?> GetUser(Guid userId);

    /// <summary>
    /// Removes the given Client Role from the User.
    /// Returns true if the operation was successful.
    /// </summary>
    /// <param name="userId"></param>
    /// <param name="role"></param>
    Task<bool> RemoveClientRole(Guid userId, Role role);

    /// <summary>
    /// Updates the User with the given Keycloak User Representation.
    /// Returns true if the operation was successful.
    /// </summary>
    /// <param name="userId"></param>
    /// <param name="userRep"></param>
    Task<bool> UpdateUser(Guid userId, UserRepresentation userRep);

    /// <summary>
    /// Fetches the User and updates with the given Action.
    /// Returns true if the operation was successful.
    /// </summary>
    /// <param name="userId"></param>
    /// <param name="updateAction"></param>
    Task<bool> UpdateUser(Guid userId, Action<UserRepresentation> updateAction);
    Task<bool> AddGrouptoUser(Guid userId, string groupName);


    Task<bool> RemoveUserFromGroup(Guid userId, string groupName);

    Task<List<Group>> GetUserGroups(Guid userId);

    Task<List<Role>?> GetUserClientRoles(Guid userId, Guid clientId);

    Task<Realm> GetRealm(string name);

    Task<IdentityProvider> GetIdentityProvider(string name);

    /// <summary>
    /// Get Identity providers within realm
    /// </summary>
    /// <returns></returns>
    Task<IEnumerable<IdentityProvider>> GetIdentityProviders();

}
