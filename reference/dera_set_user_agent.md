# Store the SEC user agent for this session and optionally future sessions

Store the SEC user agent for this session and optionally future sessions

## Usage

``` r
dera_set_user_agent(
  user_agent,
  save = interactive(),
  renviron = file.path(path.expand("~"), ".Renviron")
)
```

## Arguments

- user_agent:

  SEC user agent containing an email address.

- save:

  If `TRUE`, store `SEC_USER_AGENT` in `~/.Renviron`.

- renviron:

  `.Renviron` path used when `save = TRUE`.

## Value

The user agent, invisibly.
