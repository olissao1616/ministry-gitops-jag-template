using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using {{cookiecutter.app_name}}webapi.Extensions;

namespace {{cookiecutter.app_name}}webapi.Features.WhoAmI;


//[Authorize(Policy = Policies.JUSTINUSER)] enable this to test JUSTIN USER POLICY
[ApiController]
[Authorize]
public class WhoAmIController : Controller
{

    /// <summary>
    /// Who is the client using this API
    /// </summary>
    /// <returns></returns>
    [HttpGet]
    [Route("/api/me")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public IActionResult GetWhoAmI()
    {
        var userIdentity = HttpContext.User;

        return Ok(new { id= userIdentity.GetUserId(), firstName = userIdentity!.GetFirstName(), lastName = userIdentity.GetLastName(), email = userIdentity.GetEmail(), role = userIdentity!.GetKeycloakRoles(), justin_participant = userIdentity!.GetJustinParticipant() });
    }

    /// <summary>
    /// Test DB connection by grabbing static data stored in the database
    /// </summary>
    /// <param name="handler"></param>
    /// <param name="query"></param>
    /// <returns></returns>

    [HttpGet]
    [Route("api/authors/static-data/{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<List<WhoAmI.Author>>> GetAuthors([FromServices] IQueryHandler<WhoAmI.Query, List<WhoAmI.Author>> handler,
                                                                [FromRoute] WhoAmI.Query query)
    => await handler.HandleAsync(query);
}
