# Update one SEC DERA Financial Statement Data Set source file

Downloads one SEC DERA Financial Statement Data Set zip file and writes
its component Parquet files under `$DATA_DIR/dera`.

## Usage

``` r
update_dera_file(file, data_dir = NULL, user_agent = NULL, quiet = FALSE)
```

## Arguments

- file:

  Zip file name from the SEC DERA page, such as `"2024q1.zip"`.

- data_dir:

  Root of the local Parquet repository. Defaults to `DATA_DIR`.

- user_agent:

  Optional SEC-compliant user agent. If omitted, resolved using
  [`dera_user_agent()`](https://iangow.github.io/dera_pq/reference/dera_user_agent.md).

- quiet:

  If `TRUE`, suppress progress messages.

## Value

A tibble describing the Parquet files written.
