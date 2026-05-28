# Update SEC DERA Financial Statement Data Set Parquet files

Downloads new or changed SEC DERA Financial Statement Data Set zip files
and writes `sub`, `tag`, `num`, and `pre` Parquet files under
`$DATA_DIR/dera`.

## Usage

``` r
update_dera(data_dir = NULL, user_agent = NULL, quiet = FALSE)
```

## Arguments

- data_dir:

  Root of the local Parquet repository. If omitted, resolved using
  [`dera_data_dir()`](https://iangow.github.io/dera_pq/reference/dera_data_dir.md).

- user_agent:

  Optional SEC-compliant user agent. If omitted, resolved using
  [`dera_user_agent()`](https://iangow.github.io/dera_pq/reference/dera_user_agent.md).

- quiet:

  If `TRUE`, suppress progress messages.

## Value

Invisibly, a tibble of source zip files that were updated.
