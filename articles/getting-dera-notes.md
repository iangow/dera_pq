# Getting SEC DERA XBRL data

The SEC publishes two bulk XBRL data sets that are useful for financial
statement research:

- [Financial Statement Data
  Sets](https://www.sec.gov/data-research/sec-markets-data/financial-statement-data-sets)
- [Financial Statement and Notes Data
  Sets](https://www.sec.gov/data-research/financial-statement-notes-data-sets)

The `dera.pq` package downloads those zip files and writes their
component tables as Parquet files in a local `DATA_DIR` repository. It
is based on the workflow originally described in Ian Gow’s note “Getting
SEC EDGAR XBRL data,” but packages the update logic and stores
source-file metadata in each Parquet file rather than in a separate
sidecar table.

## Setup

SEC automated-access guidance asks users to provide a descriptive user
agent that includes contact information. `dera.pq` resolves this value
from an explicit argument, the `SEC_USER_AGENT` environment variable, or
`getOption("HTTPUserAgent")`.

``` r

library(dera.pq)

dera_set_user_agent("your_name@email_provider.com")
```

The package writes Parquet files under a local data repository
identified by `DATA_DIR`. You can set this explicitly:

``` r

Sys.setenv(DATA_DIR = "~/Dropbox/pq_data")
```

or let
[`dera_data_dir()`](https://iangow.github.io/dera_pq/reference/dera_data_dir.md)
resolve or prompt for the directory:

``` r

dera_data_dir()
```

The resulting layout is:

``` text
<DATA_DIR>/dera/
<DATA_DIR>/dera_notes/
```

## Listing available source files

The file-listing helpers scrape the SEC pages and issue `HEAD` requests
for each zip file so the returned table includes source `Last-Modified`
metadata. The `last_modified_utc` column is a canonical UTC
representation used for timezone-stable update checks.

``` r

available_dera()
available_dera_notes()
```

For code that parameterizes over the two data sets, use:

``` r

available_dera_files("dera")
available_dera_files("dera_notes")
```

## Updating all files

The high-level update functions compare SEC source metadata with
metadata embedded in the local Parquet files. A zip file is downloaded
only when its SEC `Last-Modified` timestamp is newer or when one or more
expected Parquet files are missing.

``` r

update_dera()
update_dera_notes()
```

This replaces the manual workflow of downloading a zip file, opening
each tab-delimited file, specifying column types, converting date
fields, and writing each table to Parquet. Those details are still
important, but they now live in the package table specifications and
update functions rather than in an analysis script.

[`update_dera()`](https://iangow.github.io/dera_pq/reference/update_dera.md)
writes the standard Financial Statement Data Set tables: `sub`, `tag`,
`num`, and `pre`.

[`update_dera_notes()`](https://iangow.github.io/dera_pq/reference/update_dera_notes.md)
writes the Financial Statement and Notes tables: `sub_notes`,
`tag_notes`, `dim_notes`, `num_notes`, `txt_notes`, `ren_notes`,
`pre_notes`, and `cal_notes`.

## Updating one source file

The repository-level functions call lower-level functions that update a
single SEC zip file:

``` r

update_dera_file("2024q1.zip")
update_dera_notes_file("2024q1_notes.zip")
```

These are useful for testing a new period, repairing a missing period,
or building a small local sample.

## Embedded Parquet metadata

Each Parquet file written by `dera.pq` includes source metadata in the
Parquet schema metadata. The package stores the raw SEC header for
auditability and a parsed UTC timestamp for comparison.

``` r

path <- file.path(Sys.getenv("DATA_DIR"), "dera_notes", "sub_notes_2024q1.parquet")
dera_file_metadata(path)
```

Typical metadata fields include:

- `dera_dataset`
- `dera_source_file`
- `dera_source_url`
- `sec_last_modified`
- `last_modified`
- `last_modified_utc`

The UTC field avoids false update decisions when code is run in sessions
with different local time zones.

## Working with the Parquet files

Once created, the Parquet files can be read by Arrow, DuckDB, Polars, or
other tools. In R, Arrow can open all periods for a table with a
wildcard-like file listing:

``` r

library(arrow)
dplyr::open_dataset(
  list.files(
    file.path(Sys.getenv("DATA_DIR"), "dera_notes"),
    pattern = "^sub_notes_.*\\.parquet$",
    full.names = TRUE
  )
)
```

In Python Polars, the same repository can be scanned using `era_pl`:

``` python
from era_pl import load_parquet

sub = load_parquet("sub_notes_*", "dera_notes")
```
