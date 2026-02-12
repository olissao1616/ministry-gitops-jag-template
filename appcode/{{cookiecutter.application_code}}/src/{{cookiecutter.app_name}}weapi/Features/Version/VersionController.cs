
using Microsoft.AspNetCore.Mvc;

namespace {{cookiecutter.app_name}}webapi.Features.Version
{
    //[Authorize(Policy = Policies.JUSTINUSER)] enable this to test JUSTIN USER POLICY
    [ApiController]
    [Route("api/version")]
    public class VersionController(IWebHostEnvironment environment) : ControllerBase
    {
        private readonly IWebHostEnvironment _environment = environment;

        [HttpGet]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public IActionResult GetVersion()
        {
            // Get version information from assembly
            var version = typeof(Program).Assembly.GetName().Version;

            return Ok(new { version = version!.ToString(), environment = _environment.EnvironmentName });
        }
    }
}
