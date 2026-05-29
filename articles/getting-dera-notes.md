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
`getOption("HTTPUserAgent")`. In an interactive session, if no valid
value can be resolved, the package asks for one and offers to store it
in project-level `.Renviron` or user-level `~/.Renviron`.

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
other tools.

### Using R

In R, you could use
[`load_parquet()`](https://rdrr.io/pkg/farr/man/load_parquet.html) from
my `farr` package.

``` r

library(dplyr, warn.conflicts = FALSE)
library(farr, warn.conflicts = FALSE)
library(DBI)

db <- dbConnect(duckdb::duckdb())

sub_notes <- load_parquet(db, "sub_notes_*", "dera_notes")

sub_notes |> 
  arrange(desc(accepted)) |> 
  select(adsh, cik, name, form, accepted)
```

See the [published R edition](https://iangow.github.io/far_book/) of
*Empirical Research in Accounting: Tools and Methods* for more examples
using `farr` and Parquet files.

### Using Python Polars

In Python Polars, the same repository can be scanned using `era_pl`:

``` python
from era_pl import load_parquet

sub_notes = load_parquet("sub_notes_*", "dera_notes")

(
    sub_notes
    .sort("accepted", descending=True) 
    .select("adsh", "cik", "name", "form", "accepted")
    .show()
)
#> shape: (5, 5)
#> ┌──────────────────────┬─────────┬─────────────────────────────┬─────────┬─────────────────────────┐
#> │ adsh                 ┆ cik     ┆ name                        ┆ form    ┆ accepted                │
#> │ ---                  ┆ ---     ┆ ---                         ┆ ---     ┆ ---                     │
#> │ str                  ┆ i32     ┆ str                         ┆ str     ┆ datetime[μs, UTC]       │
#> ╞══════════════════════╪═════════╪═════════════════════════════╪═════════╪═════════════════════════╡
#> │ 0001493152-26-020705 ┆ 1624326 ┆ PAVMED INC.                 ┆ DEF 14A ┆ 2026-05-01 09:29:00 UTC │
#> │ 0001193125-26-197921 ┆ 1613780 ┆ DBV TECHNOLOGIES S.A.       ┆ 8-K     ┆ 2026-04-30 17:31:00 UTC │
#> │ 0001213900-26-050440 ┆ 1997201 ┆ PS INTERNATIONAL GROUP LTD. ┆ 20-F    ┆ 2026-04-30 17:31:00 UTC │
#> │ 0001193125-26-197916 ┆ 1045609 ┆ PROLOGIS, INC.              ┆ 8-K     ┆ 2026-04-30 17:30:00 UTC │
#> │ 0001193125-26-197914 ┆ 1602842 ┆ ORION DIGITAL CORP.         ┆ 20-F    ┆ 2026-04-30 17:30:00 UTC │
#> └──────────────────────┴─────────┴─────────────────────────────┴─────────┴─────────────────────────┘
```

See the [Python Polars edition](https://iangow.github.io/era_pl_book/)
of *Empirical Research in Accounting: Tools and Methods* for more
examples using `era_pl` and Parquet files.
