dera_datasets <- function(dataset) {
  dataset <- match.arg(dataset, c("dera", "dera_notes"))

  if (identical(dataset, "dera")) {
    return(list(
      dataset = "dera",
      schema = "dera",
      page_url = paste0(
        "https://www.sec.gov/data-research/sec-markets-data/",
        "financial-statement-data-sets"
      ),
      zip_base_url = paste0(
        "https://www.sec.gov/files/dera/data/",
        "financial-statement-data-sets/"
      ),
      table_specs = dera_table_specs(),
      period = function(file) stringr::str_remove(file, "\\.zip$")
    ))
  }

  list(
    dataset = "dera_notes",
    schema = "dera_notes",
    page_url = paste0(
      "https://www.sec.gov/data-research/",
      "financial-statement-notes-data-sets"
    ),
    zip_base_url = paste0(
      "https://www.sec.gov/files/dera/data/",
      "financial-statement-notes-data-sets/"
    ),
    table_specs = dera_notes_table_specs(),
    period = function(file) stringr::str_replace(file, "^(.*)_notes.*$", "\\1")
  )
}

dera_table_specs <- function() {
  list(
    sub = table_spec(
      source = "sub.txt",
      col_types = "cdcdcccccccccccccccccdcdccddcdcddcdc",
      date_cols = c("changed", "filed", "period"),
      datetime_cols = "accepted"
    ),
    tag = table_spec(
      source = "tag.txt",
      col_types = "ccddccccc"
    ),
    num = table_spec(
      source = "num.txt",
      col_types = "ccccdcccdc",
      date_cols = "ddate"
    ),
    pre = table_spec(
      source = "pre.txt",
      col_types = "ciiclccccl"
    )
  )
}

dera_notes_table_specs <- function() {
  list(
    sub_notes = table_spec(
      source = "sub.tsv",
      col_types = "cicccccccccccccccccccdclccdicdcllcicddci",
      date_cols = c("changed", "filed", "period", "floatdate"),
      datetime_cols = "accepted"
    ),
    tag_notes = table_spec(
      source = "tag.tsv",
      col_types = "ccllccccc",
      fallback_quote = "",
      repair_tabs = TRUE
    ),
    dim_notes = table_spec(
      source = "dim.tsv",
      col_types = "cci"
    ),
    num_notes = table_spec(
      source = "num.tsv",
      col_types = "cccdiccidciicddi",
      date_cols = "ddate",
      fallback_quote = ""
    ),
    txt_notes = table_spec(
      source = "txt.tsv",
      col_types = "cccdiiciddcicliicicc",
      date_cols = "ddate",
      fallback_quote = "",
      repair_tabs = TRUE
    ),
    ren_notes = table_spec(
      source = "ren.tsv",
      col_types = "ciccccccii",
      fallback_quote = ""
    ),
    pre_notes = table_spec(
      source = "pre.tsv",
      col_types = "ciiclccccl",
      fallback_quote = "",
      repair_tabs = TRUE
    ),
    cal_notes = table_spec(
      source = "cal.tsv",
      col_types = "ciiicccc"
    )
  )
}

table_spec <- function(source, col_types, date_cols = character(),
                       datetime_cols = character(), quote = "\"",
                       fallback_quote = NULL, repair_tabs = FALSE) {
  list(
    source = source,
    col_types = col_types,
    date_cols = date_cols,
    datetime_cols = datetime_cols,
    quote = quote,
    fallback_quote = fallback_quote,
    repair_tabs = repair_tabs
  )
}
