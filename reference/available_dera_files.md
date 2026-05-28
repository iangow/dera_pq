# List SEC DERA zip files available for download

List SEC DERA zip files available for download

## Usage

``` r
available_dera_files(dataset = c("dera", "dera_notes"), user_agent = NULL)
```

## Arguments

- dataset:

  One of `"dera"` or `"dera_notes"`.

- user_agent:

  Optional SEC-compliant user agent. If omitted, resolved using
  [`dera_user_agent()`](https://iangow.github.io/dera_pq/reference/dera_user_agent.md).

## Value

A tibble with `file`, `last_modified`, and `last_modified_utc`.
