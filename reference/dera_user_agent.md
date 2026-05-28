# Resolve the SEC user agent

Resolves the SEC user agent from, in order, an explicit argument, the
`SEC_USER_AGENT` environment variable, and `getOption("HTTPUserAgent")`.

## Usage

``` r
dera_user_agent(user_agent = NULL, prompt = interactive())
```

## Arguments

- user_agent:

  Optional SEC user-agent override.

- prompt:

  If `TRUE`, prompt interactively when no user agent can be resolved.

## Value

A non-empty character string containing an email address.
