using FluentValidation;
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using {{cookiecutter.app_name}}webapi.Data;
using {{cookiecutter.app_name}}webapi.Extensions;

namespace {{cookiecutter.app_name}}webapi.Features.WhoAmI;
public class WhoAmI
{
    public class Query : IQuery<List<Author>>
    {
        public int Id { get; set; }
    }

    [Table("author", Schema = "public")]
    public class Author
    {
        [Key]
        [Column("authorid")]
        public int AuthorId { get; set; }

        [Column("name")]
        public string Name { get; set; } = string.Empty;

        [Column("birthdate")] 
        public DateTime BirthDate { get; set; }

        [Column("email")]
        public string Email { get; set; } = string.Empty;
    }

    public class QueryValidator : AbstractValidator<Query>
    {
        public QueryValidator(IHttpContextAccessor accessor)
        {
            var user = accessor?.HttpContext?.User;
            Serilog.Log.Information($"Checking user {user.GetUserId()}");
            this.RuleFor(x => x.Id).NotNull().GreaterThan(1);
        }
    }

    public class QueryHandler : IQueryHandler<Query, List<Author>>
    {
        private readonly {{cookiecutter.app_name}}webapiDataContext context;

        public QueryHandler({{cookiecutter.app_name}}webapiDataContext context) => this.context = context;

        public async Task<List<Author>> HandleAsync(Query query)
        {

            var tt = await this.context.Authors.ToListAsync();
            return await this.context.Authors
                .Where(author => author.AuthorId == query.Id)
                .Select(author => new Author
                {
                    AuthorId = author.AuthorId, Name = author.Name, BirthDate = author.BirthDate, Email = author.Email
                })
                .ToListAsync();
        }
    }
}

