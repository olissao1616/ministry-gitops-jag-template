namespace {{cookiecutter.app_name}}webapi.Exceptions;
public class JustinUserException : Exception
{
    public string Details { get; }

    public JustinUserException(string message, string details) : base(message)
    {
        Details = details;
    }

    public JustinUserException(string message, string details, Exception innerException) : base(message, innerException)
    {
        Details = details;
    }
}
