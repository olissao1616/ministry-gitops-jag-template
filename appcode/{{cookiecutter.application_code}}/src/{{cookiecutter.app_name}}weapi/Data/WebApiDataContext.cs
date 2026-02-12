using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json;
using NodaTime;
using {{cookiecutter.app_name}}webapi.Models;
using static {{cookiecutter.app_name}}webapi.Features.WhoAmI.WhoAmI;
using static {{cookiecutter.app_name}}webapi.Features.Participant.Agency;
using static {{cookiecutter.app_name}}webapi.Features.Participant.Application;

namespace {{cookiecutter.app_name}}webapi.Data;
public class {{cookiecutter.app_name}}webapiDataContext : DbContext
{
    private readonly IClock clock;

    public {{cookiecutter.app_name}}webapiDataContext(DbContextOptions<{{cookiecutter.app_name}}webapiDataContext> options, IClock clock) : base(options) => this.clock = clock;

    public DbSet<Author> Authors { get; set; } = default!;
    public DbSet<AgencyAssignment> AgencyAssignments { get; set; } = default!;
    public DbSet<ApplicationType> ApplicationTypes { get; set; } = default!;
    public DbSet<TypeAgency> TypeAgencies { get; set; } = default!;


public override int SaveChanges()
    {
        this.ApplyAudits();

        return base.SaveChanges();
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        this.ApplyAudits();

        return await base.SaveChangesAsync(cancellationToken);
    }

    private void ApplyAudits()
    {
        this.ChangeTracker.DetectChanges();
        var updated = this.ChangeTracker.Entries()
            .Where(x => x.Entity is BaseAuditable
                && (x.State == EntityState.Added || x.State == EntityState.Modified));

        var currentInstant = this.clock.GetCurrentInstant();

        foreach (var entry in updated)
        {
            entry.CurrentValues[nameof(BaseAuditable.Modified)] = currentInstant;

            if (entry.State == EntityState.Added)
            {
                entry.CurrentValues[nameof(BaseAuditable.Created)] = currentInstant;
            }
            else
            {
                entry.Property(nameof(BaseAuditable.Created)).IsModified = false;
            }
        }
    }



    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

    //modelBuilder.Entity<DigitalEvidence>().Property(x => x.AssignedRegions).
    //    HasConversion(
    //                  v => JsonConvert.SerializeObject(v, new JsonSerializerSettings { NullValueHandling = NullValueHandling.Ignore }),
    //        v => JsonConvert.DeserializeObject<List<AssignedRegion>>(v, new JsonSerializerSettings { NullValueHandling = NullValueHandling.Ignore })

    //    );

    //modelBuilder.Entity<IdempotentConsumer>()
    //    .ToTable("IdempotentConsumers")
    //    .HasKey(x => new { x.MessageId, x.Consumer });

    //modelBuilder.Entity<ExportedEvent>()
    //     .ToTable("OutBoxedExportedEvent");
    ////.Property(x => x.JsonEventPayload).HasColumnName("EventPayload");

    //modelBuilder.Entity<ExportedEvent>()
    //    .ToTable("OutBoxedExportedEvent");

    //// Adds Quartz.NET PostgreSQL schema to EntityFrameworkCore
    //modelBuilder.AddQuartz(builder => builder.UsePostgreSql());

    modelBuilder.Entity<AgencyAssignment>().ToTable("agencyassignment", schema: "public");
    modelBuilder.Entity<TypeAgency>()
   .HasKey("agencyassignmentid");
    modelBuilder.Entity<TypeAgency>().ToTable("type_agency", schema: "public");

    modelBuilder.ApplyConfigurationsFromAssembly(typeof({{cookiecutter.app_name}}webapiDataContext).Assembly);

    }


    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        if (Environment.GetEnvironmentVariable("LOG_SQL") != null && "true".Equals(Environment.GetEnvironmentVariable("LOG_SQL")))
        {
            optionsBuilder.LogTo(Console.WriteLine);
        }

    }
}
