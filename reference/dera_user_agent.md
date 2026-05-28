# Resolve the SEC user agent

Resolves the SEC user agent from, in order, an explicit argument, the
`SEC_USER_AGENT` environment variable, and `getOption("HTTPUserAgent")`.
In an interactive session, when no valid value can be resolved, the
helper asks for a user agent and offers to persist it in either
project-level `.Renviron` or user-level `~/.Renviron`.

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
