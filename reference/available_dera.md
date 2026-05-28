# List SEC DERA Financial Statement Data Set source files

List SEC DERA Financial Statement Data Set source files

## Usage

``` r
available_dera(user_agent = NULL)
```

## Arguments

- user_agent:

  Optional SEC-compliant user agent. If omitted, resolved using
  [`dera_user_agent()`](https://iangow.github.io/dera_pq/reference/dera_user_agent.md).

## Value

A tibble with `file`, `last_modified`, and `last_modified_utc`.
