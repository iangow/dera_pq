download_zip <- function(url, user_agent = NULL, quiet = FALSE) {
  user_agent <- dera_user_agent(user_agent)
  dest <- tempfile(fileext = ".zip")

  req <- httr2::request(url) |>
    httr2::req_user_agent(user_agent)

  httr2::req_perform(req, path = dest)
  if (!quiet) {
    message("Downloaded ", url)
  }
  dest
}

read_zip_table <- function(zip_file, spec, source_file = basename(zip_file),
                           table = spec$source) {
  parsing_warning <- FALSE
  df <- withCallingHandlers(
    readr::read_tsv(
      unz(zip_file, spec$source),
      col_types = spec$col_types,
      progress = FALSE,
      quote = spec$quote %||% "\""
    ),
    warning = function(cnd) {
      if (grepl("One or more parsing issues", conditionMessage(cnd), fixed = TRUE)) {
        parsing_warning <<- TRUE
        rlang::cnd_muffle(cnd)
      }
    }
  )

  problems <- .warn_parsing_problems(
    df = df,
    source_file = source_file,
    table = table,
    source = spec$source,
    parsing_warning = parsing_warning
  )
  attr(df, "dera_parse_problems") <- problems

  for (col in spec$date_cols) {
    df[[col]] <- lubridate::ymd(df[[col]])
  }
  for (col in spec$datetime_cols) {
    df[[col]] <- lubridate::ymd_hms(df[[col]])
  }

  df
}

.parsing_metadata <- function(df, table, source) {
  problems <- attr(df, "dera_parse_problems")
  if (is.null(problems)) {
    problems <- readr::problems(df)
  }

  list(
    dera_source_table = table,
    dera_source_inner_file = source,
    dera_parse_problem_count = as.character(nrow(problems)),
    dera_parse_problem_rows = paste(utils::head(problems$row, 50), collapse = ",")
  )
}

.warn_parsing_problems <- function(df, source_file, table, source,
                                   parsing_warning = FALSE) {
  problems <- readr::problems(df)
  if (!isTRUE(parsing_warning) && nrow(problems) == 0) {
    return(invisible(problems))
  }

  details <- .format_parsing_problems(problems)
  warning(
    paste0(
      "Parsing issues in SEC source file '", source_file, "', table '", table,
      "' (", source, "): ", nrow(problems), " issue(s).",
      details
    ),
    call. = FALSE
  )
  invisible(problems)
}

.format_parsing_problems <- function(problems, n = 5) {
  if (nrow(problems) == 0) {
    return("")
  }

  shown <- utils::head(problems, n)
  lines <- purrr::pmap_chr(shown, function(row, col, expected, actual, file, ...) {
    paste0(
      "\n  row ", row,
      ", col ", col,
      ": expected ", expected,
      ", actual ", actual
    )
  })

  more <- nrow(problems) - length(lines)
  if (more > 0) {
    lines <- c(lines, paste0("\n  ... and ", more, " more issue(s)"))
  }

  paste0(lines, collapse = "")
}

write_table_parquet <- function(df, table, period, pq_dir, metadata) {
  dir.create(pq_dir, recursive = TRUE, showWarnings = FALSE)
  pq_file <- file.path(pq_dir, paste0(table, "_", period, ".parquet"))
  write_parquet_with_metadata(df, sink = pq_file, metadata = metadata)

  pq_file
}

update_dataset_file <- function(file, dataset, data_dir = NULL,
                                user_agent = NULL, last_modified = NULL,
                                quiet = FALSE) {
  cfg <- dera_datasets(dataset)
  data_dir <- dera_data_dir(data_dir)
  user_agent <- dera_user_agent(user_agent)
  source_url <- paste0(cfg$zip_base_url, file)
  if (is.null(last_modified)) {
    last_modified <- get_last_modified(source_url, user_agent = user_agent)
  }
  zip_file <- download_zip(
    source_url,
    user_agent = user_agent,
    quiet = quiet
  )
  on.exit(unlink(zip_file), add = TRUE)

  period <- cfg$period(file)
  pq_dir <- file.path(data_dir, cfg$schema)
  metadata <- dera_metadata(
    dataset = cfg$dataset,
    file = file,
    source_url = source_url,
    last_modified = last_modified
  )

  out <- purrr::imap_chr(cfg$table_specs, function(spec, table) {
    df <- read_zip_table(
      zip_file,
      spec,
      source_file = file,
      table = table
    )
    write_table_parquet(
      df,
      table,
      period,
      pq_dir,
      metadata = c(metadata, .parsing_metadata(df, table, spec$source))
    )
  })

  tibble::tibble(
    dataset = cfg$dataset,
    file = file,
    period = period,
    table = names(out),
    parquet_file = unname(out)
  )
}

#' Update one SEC DERA Financial Statement Data Set source file
#'
#' Downloads one SEC DERA Financial Statement Data Set zip file and writes its
#' component Parquet files under `$DATA_DIR/dera`.
#'
#' @param file Zip file name from the SEC DERA page, such as `"2024q1.zip"`.
#' @param data_dir Root of the local Parquet repository. Defaults to `DATA_DIR`.
#' @param user_agent Optional SEC-compliant user agent. If omitted, resolved
#'   using `dera_user_agent()`.
#' @param quiet If `TRUE`, suppress progress messages.
#'
#' @return A tibble describing the Parquet files written.
#' @export
update_dera_file <- function(file, data_dir = NULL,
                             user_agent = NULL,
                             quiet = FALSE) {
  update_dataset_file(
    file = file,
    dataset = "dera",
    data_dir = data_dir,
    user_agent = user_agent,
    quiet = quiet
  )
}

#' Update one SEC DERA Financial Statement and Notes source file
#'
#' Downloads one SEC DERA Financial Statement and Notes zip file and writes its
#' component Parquet files under `$DATA_DIR/dera_notes`.
#'
#' @inheritParams update_dera_file
#'
#' @return A tibble describing the Parquet files written.
#' @export
update_dera_notes_file <- function(file, data_dir = NULL,
                                   user_agent = NULL,
                                   quiet = FALSE) {
  update_dataset_file(
    file = file,
    dataset = "dera_notes",
    data_dir = data_dir,
    user_agent = user_agent,
    quiet = quiet
  )
}
