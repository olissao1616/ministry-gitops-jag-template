using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

using static {{cookiecutter.app_name }}webapi.Features.Participant.Agency;

namespace {{cookiecutter.app_name }}webapi.Features.Participant;

[ApiController]
[Authorize]
public class AgencyController : Controller
{

    [HttpGet]
    [Route("api/participants/agencyAssignments")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<List<TypeAgency>>> GetAuthors([FromServices] IQueryHandler<AgencyTypeQuery, List<TypeAgency>> handler)
   => await handler.HandleAsync(new AgencyTypeQuery());
}
