using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using {{cookiecutter.app_name}}webapi.Data;
using {{cookiecutter.app_name}}webapi.Extensions;

namespace {{cookiecutter.app_name }}webapi.Features.Participant;

public class Agency
{
    public sealed record AgencyTypeQuery() : IQuery<List<TypeAgency>>;
    [Table("agencyassignment", Schema = "public")]
    public class AgencyAssignment
    {
        [Key]
        [Column("id")]
        public int Id { get; set; }
        [Column("agencyid")]
        public int AgencyId { get; set; }
        [Column("identifiercode")]
        public string IdentifierCode { get; set; } = string.Empty;
        [Column("agencyname")]
        public string AgencyName { get; set; } = string.Empty;
    }
    [Table("type_agency", Schema = "public")]
    public class TypeAgency
    {

        [Column("partid")]
        public int PartId { get; set; }
        [ForeignKey("agencyassignmentid")]
        public AgencyAssignment AgencyAssignment { get; set; } = new AgencyAssignment();
        [Column("paassequence")]
        public int PaasSequence { get; set; }
        [Column("paasadministratoryn")]
        public bool PaasAdministratorYN { get; set; }
        [Column("roles")]
        public List<string> Roles { get; set; } = [];
    }
    public class QueryHandler : IQueryHandler<AgencyTypeQuery, List<TypeAgency>>
    {
        private readonly {{cookiecutter.app_name}}webapiDataContext context;

        public QueryHandler({{cookiecutter.app_name}}webapiDataContext context) => this.context = context;

        public async Task<List<TypeAgency>> HandleAsync(AgencyTypeQuery query)
        {
            return await this.context.TypeAgencies
            .Include(ta => ta.AgencyAssignment) // Include related AgencyAssignment
            .ToListAsync();
        }
    }
}
