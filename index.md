# dera.pq

`dera.pq` downloads SEC DERA Financial Statement Data Sets and Financial
Statement and Notes Data Sets, then stores their component tables as
Parquet files in a local `DATA_DIR` repository.

The package is based on the scripts `get_dera.R` and `get_dera_notes.R`
from `~/git/notes/published`.

## Installation

Install the development version from GitHub with `pak`:

``` r

install.packages("pak")
pak::pak("iangow/dera_pq")
```

## Setup

``` r

dera_set_user_agent("your_name@email.com")
dera_data_dir()
```

In interactive sessions, `dera.pq` prompts for missing configuration and
offers to store `SEC_USER_AGENT` and `DATA_DIR` in either project-level
`.Renviron` or user-level `~/.Renviron`.

## Usage

``` r

library(dera.pq)

available_dera()
available_dera_notes()

update_dera()
update_dera_notes()

update_dera_file("2024q1.zip")
update_dera_notes_file("2024q1_notes.zip")
```

The standard financial-statement files are written under
`$DATA_DIR/dera`. The financial-statement-and-notes files are written
under `$DATA_DIR/dera_notes`.

## Website

The pkgdown site is intended to be rendered locally, not in GitHub
Actions. That allows articles to include examples and summaries based on
the local SEC DERA Parquet repository without making CI download many
gigabytes of data.

Build the site locally:

``` sh
Rscript scripts/build-site.R
```

Publish the rendered static site to the `gh-pages` branch:

``` sh
Rscript scripts/deploy-site.R
```

Keep `docs/` ignored on `main`;
[`pkgdown::deploy_to_branch()`](https://pkgdown.r-lib.org/reference/deploy_to_branch.html)
handles the rendered website branch.
