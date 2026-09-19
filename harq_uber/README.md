# `harq_uber` dbt Project

This directory contains the dbt layer of the Uber end-to-end data pipeline. The complete project overview, architecture, setup instructions, and security guidance are documented in the repository [README](../README.md).

## Scope

The dbt project manages:

- Databricks source declarations in `models/source/`
- Silver transformations in `models/silver/`
- Incremental processing for trips using `trip_id` and `last_updated_timestamp`
- Gold fact and dimension snapshots in `snapshots/`
- SCD Type 2 history for customer, driver, location, payment, and vehicle dimensions
- Gold reporting SQL and ad hoc analyses
- Schema generation through `macros/generate_schema.sql`

## Commands

Run these commands from this directory:

```powershell
dbt debug --profiles-dir ..
dbt compile --profiles-dir ..
dbt build --profiles-dir ..
dbt snapshot --profiles-dir ..
dbt test --profiles-dir ..
```

For a changed incremental model, rebuild its target table with:

```powershell
dbt build --select trips --full-refresh --profiles-dir ..
```

The active profile must provide a valid Databricks catalog, schema, host, HTTP path, and token through the `harq_uber` profile. Keep the token in an environment variable and never commit it to Git.
