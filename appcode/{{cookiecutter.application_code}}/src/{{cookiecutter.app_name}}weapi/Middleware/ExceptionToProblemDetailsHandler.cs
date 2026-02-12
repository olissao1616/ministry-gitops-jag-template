using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Npgsql;
using SendGrid.Helpers.Errors.Model;
using System.Diagnostics;
using System.Net.Sockets;
using {{cookiecutter.app_name}}webapi.Exceptions;

namespace {{cookiecutter.app_name}}webapi.Middleware;


public class ExceptionToProblemDetailsHandler(IOptions<ApiBehaviorOptions> options, IProblemDetailsService problemDetailsService) : IExceptionHandler
{
    private readonly ApiBehaviorOptions _option = options.Value ?? throw new ArgumentNullException(nameof(options));
    private readonly IProblemDetailsService _problemDetailsService = problemDetailsService;

    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var statusCode = GetStatusCode(exception);
        httpContext.Response.StatusCode = statusCode;

        var problemDetails = new ProblemDetails
        {
            Title = GetTitle(exception),
            Detail = GetDetail(exception),
            Status = statusCode
        };

        if (_option.ClientErrorMapping.TryGetValue(statusCode, out var clientErrorData))
        {
            problemDetails.Title ??= clientErrorData!.Title;
            problemDetails.Type ??= clientErrorData!.Link;
            problemDetails.Extensions["additionalDetails"] = new Dictionary<string, object>
      {
            { "exceptionType", exception.GetType().Name }
        };
        }

        var traceId = Activity.Current?.Id ?? httpContext?.TraceIdentifier;
        if (traceId != null)
        {
            problemDetails.Extensions["traceId"] = traceId;
        }

        return await _problemDetailsService.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext!,
            ProblemDetails = problemDetails,
            Exception = exception
        });
    }
    private static string GetTitle(Exception exception) =>
      exception switch
      {
          ApplicationException applicationException => applicationException.Message,
          BadHttpRequestException badHttpRequestException => badHttpRequestException.Message,
          PostgresException sqlException => sqlException.Message,
          ValidationException validation => validation.Message,
          JustinUserException justinUserException => justinUserException.Message,
          NpgsqlException npgsqlException => npgsqlException.Message,
          SocketException socketException => socketException.Message,
          InvalidOperationException invalidOperationException => GetInnerExceptionMessage(invalidOperationException),
          _ => "Internal Server Error"
      };
    private static string GetDetail(Exception? exception)
    {
        return exception switch
        {

            PostgresException sqlException => $"SQL error number: {sqlException.Detail}",
            JustinUserException justinUserException => justinUserException.Details,
            NpgsqlException  npgsqlException => $"SQL error number: {npgsqlException.Data}",
            _ => exception?.Message ?? "An error occurred"
        };
    }

    private static int GetStatusCode(Exception? exception) =>
      exception switch
      {
          ForbiddenException => StatusCodes.Status403Forbidden,
          NotFoundException => StatusCodes.Status404NotFound,
          UnauthorizedAccessException => StatusCodes.Status401Unauthorized,
          ValidationException => StatusCodes.Status422UnprocessableEntity,
          JustinUserException => StatusCodes.Status401Unauthorized,
          BadHttpRequestException => StatusCodes.Status400BadRequest,
          UnsupportedMediaTypeException => StatusCodes.Status415UnsupportedMediaType,
          PostgresException sqlException => GetSqlStatusCode(sqlException),
          NpgsqlException npgsqlException => GetSqlStatusCodenq(npgsqlException),
          _ => StatusCodes.Status500InternalServerError
      };

    private static int GetSqlStatusCode(PostgresException sqlException)
    {
        switch (sqlException.SqlState)
        {
            case "23502": // Invalid database
                return StatusCodes.Status400BadRequest;
            case "18456": // Login failed
                return StatusCodes.Status401Unauthorized; // Unauthorized... we can handle database exceptions here as we want TODO
            case "547": // Foreign key violation ?? db expert thought ??
            case "23505": // Unique constraint violation ??
                return StatusCodes.Status409Conflict; // Conflict
                                                      //Add more SQL error codes and corresponding status codes as needed
            default:
                return StatusCodes.Status500InternalServerError; // Default to internal Server Error
        }
    }
      private static int GetSqlStatusCodenq(NpgsqlException sqlException)
    {
        switch (sqlException.SqlState)
        {
            case "23502": // Invalid database
                return StatusCodes.Status400BadRequest;
            case "18456": // Login failed
                return StatusCodes.Status401Unauthorized; // Unauthorized... we can handle database exceptions here as we want TODO
            case "547": // Foreign key violation ?? db expert thought ??
            case "23505": // Unique constraint violation ??
                return StatusCodes.Status409Conflict; // Conflict
                                                      //Add more SQL error codes and corresponding status codes as needed
            default:
                return StatusCodes.Status500InternalServerError; // Default to internal Server Error
        }
    }
    private static IEnumerable<ValidationFailure> GetErrors(Exception exception)
    {
        // for security reason we might not want to return the entire error to the client but we can return only validation errors ??? TODO thoughts??
        IEnumerable<ValidationFailure> errors = null!;
        if (exception is ValidationException validationException)
        {
            errors = validationException.Errors;
        }
        //if (exception is SqlException sqlException) {
        //  errors =  sqlException.Errors;
        //}
        return errors;
    }
    private static string GetInnerExceptionMessage(Exception exception)
    {
        while (exception.InnerException != null)
        {
            if (exception.InnerException is NpgsqlException npgsqlException)
            {
                // Return message from NpgsqlException
                return npgsqlException.Message;
            }
            exception = exception.InnerException;
        }
        // If NpgsqlException is not found in inner exceptions, return default message
        return "Internal Server Error";
    }
}