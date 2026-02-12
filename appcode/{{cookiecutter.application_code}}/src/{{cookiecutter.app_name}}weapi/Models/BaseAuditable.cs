using NodaTime;

namespace {{cookiecutter.app_name}}webapi.Models;


public abstract class BaseAuditable
{
    public Instant Created { get; set; }
    public Instant Modified { get; set; }
}


