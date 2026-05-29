# Update SEC DERA Financial Statement and Notes Parquet files

Downloads new or changed SEC DERA Financial Statement and Notes zip
files and writes their component tables under `$DATA_DIR/dera_notes`.

## Usage

``` r
update_dera_notes(
  data_dir = NULL,
  user_agent = NULL,
  archive_orphans = TRUE,
  quiet = FALSE,
  cache = TRUE,
  force = FALSE
)
```

## Arguments

- data_dir:

  Root of the local Parquet repository. If omitted, resolved using
  [`dera_data_dir()`](https://iangow.github.io/dera_pq/reference/dera_data_dir.md).

- user_agent:

  Optional SEC-compliant user agent. If omitted, resolved using
  [`dera_user_agent()`](https://iangow.github.io/dera_pq/reference/dera_user_agent.md).

- archive_orphans:

  If `TRUE`, move Parquet files for periods no longer listed by the SEC
  into `$DATA_DIR/dera_notes/archive`.

- quiet:

  If `TRUE`, suppress progress messages.

- cache:

  If `TRUE`, cache downloaded zip files under
  `tools::R_user_dir("dera.pq", "cache")`. If a string, use that
  directory as the zip cache. If `FALSE`, download to a temporary file
  and delete it after processing.

- force:

  If `TRUE`, reprocess all SEC source zip files listed by the SEC even
  when the local Parquet files already appear current.

## Value

Invisibly, a tibble of source zip files that were updated.
