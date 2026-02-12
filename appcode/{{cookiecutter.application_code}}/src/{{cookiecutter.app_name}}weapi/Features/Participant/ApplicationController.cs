using Microsoft.AspNetCore.Mvc;

using static {{cookiecutter.app_name }}webapi.Features.Participant.Application;

namespace {{cookiecutter.app_name }}webapi.Features.Participant;

public class ApplicationController : Controller
{
    [HttpGet]
    [Route("api/participants/applications")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<List<ApplicationType>>> GetAuthors([FromServices] IQueryHandler<ApplicationQuery, List<ApplicationType>> handler)
   => await handler.HandleAsync(new ApplicationQuery());
}
