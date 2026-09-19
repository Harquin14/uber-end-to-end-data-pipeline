# Uber End-to-End Data Pipeline

An end-to-end Uber data platform built around Databricks, PySpark, SQL, and dbt. The pipeline takes source data from Databricks Volumes through Bronze and Silver processing and publishes historized Gold dimensions, facts, and reporting outputs for analytics.

## Project Overview

The project is designed around a medallion architecture:

```text
Source files in Databricks Volumes
								|
								v
Databricks ingestion and Bronze tables
	- dynamic ingestion for source tables
	
								|
								v
Silver tables
	- table-specific transformations
	- duplicate removal
	- processing-date tracking
	- incremental trip processing with dbt
								|
								v
Gold tables and snapshots
	- fact and dimension outputs
	- SCD Type 2 history
	- driver performance reporting
```

The upstream Databricks ingestion and PySpark notebook work loads source data dynamically and applies shared quality logic across tables. The dbt project in `harq_uber/` manages the downstream SQL transformations, incremental processing, snapshots, and Gold reporting layer.

## Technology Stack

- **Databricks**: Lakehouse execution environment, Unity Catalog, Delta tables, and SQL warehouse
- **PySpark**: Dynamic ingestion and reusable table-processing logic
- **SQL**: Source and table-specific transformations
- **dbt Core / dbt-databricks**: Model dependency management, incremental builds, snapshots, and documentation metadata
- **Python and uv**: Local project and dependency management

## Data Architecture

### Source and Bronze

Source data is loaded dynamically into Databricks from the source catalog and Volume locations. The Bronze processing pattern is intended to be reusable across tables and includes:

- Dynamic handling of multiple source tables
- Persistence of raw or lightly standardized Delta data in the Bronze layer

The source definitions currently used by dbt are in [harq_uber/models/source/source.yml](harq_uber/models/source/source.yml). They reference the `uber_dbt` catalog and the `bronze`, `silver`, and `gold` schemas.

### Silver

Silver models apply table-specific business transformations. The implemented dbt trip model is [harq_uber/models/silver/trips.sql](harq_uber/models/silver/trips.sql). It:


- Duplicate removal through shared PySpark processing logic
- Addition of a `processing_date` column for operational traceability
- Reads from `uber_dbt.bronze.trips`
- Selects the required trip columns
- Uses `trip_id` as the incremental model key
- Processes only rows newer than the current maximum `last_updated_timestamp`

The model is configured as an incremental model with a `trip_id` unique key. A full refresh should be used when the target Delta table schema changes:

```powershell
dbt build --select trips --full-refresh --project-dir . --profiles-dir ..
```

### Gold

Gold outputs are designed for analytics and reporting. The project includes:

- `FactTrips`, a timestamp-based snapshot of trip facts
- `DimCustomers`, `DimDrivers`, `DimLocation`, `DimPayments`, and `DimVehicles`, configured as SCD Type 2 snapshots
- `gold_report.sql`, a driver performance report built from the Gold fact and driver dimension sources

The SCD Type 2 snapshots use each entity's business key and `last_updated_timestamp` to preserve historical versions. dbt validity columns identify when each version became active and inactive, with open-ended records configured to use `9999-12-31`.

The reporting model calculates driver rating tiers, driver segments, total trips, total earnings, total distance, active months, days since the last trip, and average monthly earnings.

## dbt Project Structure

```text
harq_uber/
├── analyses/             Ad hoc SQL analyses
├── macros/               Reusable dbt macros, including schema generation
├── models/
│   ├── source/           Source declarations
│   └── silver/           Silver transformations
├── snapshots/            Gold fact and SCD Type 2 snapshots
├── tests/                dbt test directory
├── dbt_project.yml       Project configuration
└── README.md             dbt-specific notes
```

The project uses a custom `generate_schema_name` macro in [harq_uber/macros/generate_schema.sql](harq_uber/macros/generate_schema.sql). When a model does not specify a custom schema, it uses the target schema from the active dbt profile. When a custom schema is specified, the macro uses that schema directly.

## Prerequisites

1. Python 3.11 or later
2. A Databricks workspace and SQL warehouse
3. Access to the `uber_dbt` catalog and the required schemas
4. Source Delta tables or files loaded into the expected Databricks locations
5. A Databricks personal access token or other supported authentication method

The repository does not contain credentials. Set the token as an environment variable instead of committing it to a profile:

```powershell
$env:DATABRICKS_TOKEN = "<your-token>"
```

Do not commit tokens, host credentials, generated `target/` files, or local virtual environments.

## Setup

From the repository root, create or activate the environment and install the project dependencies:

```powershell
uv sync
```

The dbt profile must use the `harq_uber` profile name and a valid catalog. A minimal profile shape is:

```yaml
harq_uber:
	target: dev
	outputs:
		dev:
			type: databricks
			catalog: uber_dbt
			schema: source
			host: <databricks-host>
			http_path: <sql-warehouse-http-path>
			token: "{{ env_var('DATABRICKS_TOKEN') }}"
			threads: 1
```

Keep credentials in the local dbt profiles location or environment variables, not in source control.

## Running the Pipeline

Run these commands from `harq_uber/`:

```powershell
dbt debug --profiles-dir ..
dbt compile --profiles-dir ..
dbt build --profiles-dir ..
```

Useful scoped commands:

```powershell
dbt build --select trips --profiles-dir ..
dbt build --select trips --full-refresh --profiles-dir ..
dbt snapshot --profiles-dir ..
dbt test --profiles-dir ..
```

Run `dbt snapshot` after the upstream Silver tables are available so the SCD Type 2 Gold tables can be maintained.

## Operational Considerations

- Confirm the active profile and catalog with `dbt debug` before running a build.
- Treat the source catalog/schema/table names in `source.yml` as contracts with the Databricks ingestion process.
- Use a full refresh when an incremental model's output schema changes or an old target table contains incompatible columns.
- Ensure every incremental model has a stable unique key and a reliable update timestamp.
- Add dbt schema tests for primary keys, non-null fields, accepted values, and source freshness as the pipeline matures.
- Keep source ingestion notebooks, SQL transformations, and dbt models versioned together where possible so schema changes are traceable.

## Current Repository Scope

This repository contains the Python package scaffold and the downstream dbt project. The Databricks ingestion notebooks and reusable PySpark deduplication classes described in the architecture are upstream execution assets and are not currently included in the tracked source tree. They should be added to the repository, or linked from their owning workspace, if the project is intended to be fully reproducible from Git.

## License

No license has been specified for this repository.
