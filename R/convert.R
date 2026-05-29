download_zip <- function(url, user_agent = NULL, quiet = FALSE,
                         cache_file = NULL, last_modified = NULL) {
  user_agent <- dera_user_agent(user_agent)
  dest <- cache_file %||% tempfile(fileext = ".zip")
  if (!is.null(cache_file) && .valid_zip_file(cache_file)) {
    if (.zip_cache_metadata_matches(cache_file, last_modified)) {
      if (!quiet) {
        message("Using cached ", cache_file)
      }
      return(cache_file)
    }
    if (!quiet) {
      message("Cached zip is stale; downloading ", url)
    }
  }

  if (!is.null(cache_file)) {
    dir.create(dirname(cache_file), recursive = TRUE, showWarnings = FALSE)
  }

  req <- httr2::request(url) |>
    httr2::req_user_agent(user_agent)

  httr2::req_perform(req, path = dest)
  if (!is.null(cache_file)) {
    .write_zip_cache_metadata(cache_file, url, last_modified)
  }
  if (!quiet) {
    message("Downloaded ", url)
  }
  dest
}

.valid_zip_file <- function(path) {
  file.exists(path) &&
    isTRUE(file.info(path)$size > 0) &&
    !inherits(try(utils::unzip(path, list = TRUE), silent = TRUE), "try-error")
}

.zip_cache_file <- function(file, cfg, data_dir = NULL, cache = TRUE) {
  if (isFALSE(cache) || is.null(cache)) {
    return(NULL)
  }

  cache_dir <- if (isTRUE(cache)) {
    file.path(tools::R_user_dir("dera.pq", "cache"), cfg$schema)
  } else {
    path.expand(cache)
  }

  file.path(cache_dir, basename(file))
}

.zip_cache_metadata_file <- function(cache_file) {
  paste0(cache_file, ".dcf")
}

.read_zip_cache_metadata <- function(cache_file) {
  metadata_file <- .zip_cache_metadata_file(cache_file)
  if (!file.exists(metadata_file)) {
    return(NULL)
  }

  metadata <- tryCatch(
    as.list(read.dcf(metadata_file)[1, ]),
    error = function(e) NULL
  )
  if (is.null(metadata)) {
    return(NULL)
  }
  metadata
}

.write_zip_cache_metadata <- function(cache_file, url, last_modified = NULL) {
  metadata_file <- .zip_cache_metadata_file(cache_file)
  dir.create(dirname(metadata_file), recursive = TRUE, showWarnings = FALSE)
  metadata <- list(
    URL = url,
    "Last-Modified" = last_modified %||% "",
    "Last-Modified-UTC" = http_datetime_iso(last_modified),
    "Downloaded-At-UTC" = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  write.dcf(as.data.frame(metadata, check.names = FALSE), metadata_file)
  invisible(metadata_file)
}

.zip_cache_metadata_matches <- function(cache_file, last_modified = NULL) {
  if (is.null(last_modified) || !nzchar(last_modified)) {
    return(TRUE)
  }

  metadata <- .read_zip_cache_metadata(cache_file)
  if (is.null(metadata)) {
    return(FALSE)
  }

  cached_modified <- metadata[["Last-Modified"]] %||% ""
  nzchar(cached_modified) && http_datetime_equal(cached_modified, last_modified)
}

read_zip_table <- function(zip_file, spec, source_file = basename(zip_file),
                           table = spec$source) {
  parsed <- .read_zip_table_once(
    unz(zip_file, spec$source),
    spec = spec
  )
  initial_problems <- parsed$problems
  repairs <- character()

  if (nrow(initial_problems) > 0 && !is.null(spec$fallback_quote)) {
    fallback_spec <- spec
    fallback_spec$quote <- spec$fallback_quote
    parsed_fallback <- .read_zip_table_once(
      unz(zip_file, spec$source),
      spec = fallback_spec
    )
    if (nrow(parsed_fallback$problems) <= nrow(parsed$problems)) {
      parsed <- parsed_fallback
      repairs <- c(repairs, "quote-fallback")
    }
  }

  if (nrow(parsed$problems) > 0 && isTRUE(spec$repair_tabs)) {
    repaired_input <- .repair_zip_table_tabs(zip_file, spec)
    repair_spec <- spec
    if (!is.null(spec$fallback_quote)) {
      repair_spec$quote <- spec$fallback_quote
    }
    parsed_repaired <- .read_zip_table_once(
      repaired_input,
      spec = repair_spec
    )
    if (nrow(parsed_repaired$problems) <= nrow(parsed$problems)) {
      parsed <- parsed_repaired
      repairs <- union(repairs, "tab-repair")
    }
  }

  df <- parsed$df

  problems <- .warn_parsing_problems(
    df = df,
    source_file = source_file,
    table = table,
    source = spec$source,
    parsing_warning = parsed$parsing_warning
  )
  attr(df, "dera_parse_problems") <- problems
  attr(df, "dera_initial_parse_problems") <- initial_problems
  attr(df, "dera_parse_repairs") <- repairs

  for (col in spec$date_cols) {
    df[[col]] <- lubridate::ymd(df[[col]])
  }
  for (col in spec$datetime_cols) {
    df[[col]] <- lubridate::ymd_hms(df[[col]])
  }

  df
}

.read_zip_table_once <- function(input, spec) {
  parsing_warning <- FALSE
  df <- withCallingHandlers(
    readr::read_tsv(
      input,
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

  list(
    df = df,
    problems = readr::problems(df),
    parsing_warning = parsing_warning
  )
}

.repair_zip_table_tabs <- function(zip_file, spec) {
  con <- unz(zip_file, spec$source)
  on.exit(close(con), add = TRUE)
  lines <- readLines(con, warn = FALSE)
  I(paste(.repair_tsv_lines(lines, nchar(spec$col_types)), collapse = "\n"))
}

.repair_tsv_lines <- function(lines, expected_cols) {
  vapply(lines, .repair_tsv_line, character(1), expected_cols = expected_cols)
}

.repair_tsv_line <- function(line, expected_cols) {
  fields <- strsplit(line, "\t", fixed = TRUE)[[1]]
  n_fields <- length(fields)

  if (n_fields == expected_cols) {
    return(line)
  }
  if (n_fields < expected_cols) {
    return(paste(c(fields, rep("", expected_cols - n_fields)), collapse = "\t"))
  }

  paste(
    c(fields[seq_len(expected_cols - 1L)],
      paste(fields[expected_cols:n_fields], collapse = " ")),
    collapse = "\t"
  )
}

.parsing_metadata <- function(df, table, source) {
  problems <- attr(df, "dera_parse_problems")
  if (is.null(problems)) {
    problems <- readr::problems(df)
  }
  initial_problems <- attr(df, "dera_initial_parse_problems")
  if (is.null(initial_problems)) {
    initial_problems <- problems
  }
  repairs <- attr(df, "dera_parse_repairs") %||% character()

  list(
    dera_source_table = table,
    dera_source_inner_file = source,
    dera_parse_problem_count = as.character(nrow(problems)),
    dera_parse_problem_rows = paste(utils::head(problems$row, 50), collapse = ","),
    dera_initial_parse_problem_count = as.character(nrow(initial_problems)),
    dera_initial_parse_problem_rows = paste(utils::head(initial_problems$row, 50), collapse = ","),
    dera_parse_repairs = paste(repairs, collapse = ",")
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
                                quiet = FALSE, cache = TRUE) {
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
    quiet = quiet,
    cache_file = .zip_cache_file(file, cfg, data_dir, cache = cache),
    last_modified = last_modified
  )
  if (isFALSE(cache) || is.null(cache)) {
    on.exit(unlink(zip_file), add = TRUE)
  }

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
#' @param cache If `TRUE`, cache downloaded zip files under
#'   `tools::R_user_dir("dera.pq", "cache")`. If a string, use that directory
#'   as the zip cache. If `FALSE`, download to a temporary file and delete it
#'   after processing.
#'
#' @return A tibble describing the Parquet files written.
#' @export
update_dera_file <- function(file, data_dir = NULL,
                             user_agent = NULL,
                             quiet = FALSE,
                             cache = TRUE) {
  update_dataset_file(
    file = file,
    dataset = "dera",
    data_dir = data_dir,
    user_agent = user_agent,
    quiet = quiet,
    cache = cache
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
                                   quiet = FALSE,
                                   cache = TRUE) {
  update_dataset_file(
    file = file,
    dataset = "dera_notes",
    data_dir = data_dir,
    user_agent = user_agent,
    quiet = quiet,
    cache = cache
  )
}
