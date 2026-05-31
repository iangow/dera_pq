#!/usr/bin/env Rscript

# One-time repair for Parquet files written before dera.pq 0.0.1.9000.
# Those files interpreted raw SEC accepted timestamps as UTC. Current package
# code reads them as America/New_York, so this script is only for legacy files.

suppressPackageStartupMessages({
  library(arrow)
  library(lubridate)
})

args <- commandArgs(trailingOnly = TRUE)
execute <- "--execute" %in% args
force <- "--force" %in% args
data_dir_arg <- grep("^--data-dir=", args, value = TRUE)
data_dir <- if (length(data_dir_arg) > 0L) {
  sub("^--data-dir=", "", data_dir_arg[[1]])
} else {
  Sys.getenv("DATA_DIR", unset = "")
}

if (!nzchar(data_dir)) {
  stop("Set DATA_DIR or pass --data-dir=/path/to/data.", call. = FALSE)
}

data_dir <- path.expand(data_dir)
if (!dir.exists(data_dir)) {
  stop("DATA_DIR does not exist: ", data_dir, call. = FALSE)
}

sec_tz <- "America/New_York"
repair_key <- "dera_accepted_timezone_repair"
last_updated_keys <- c("last_modified", "last_modified_utc")

accepted_files <- c(
  list.files(
    file.path(data_dir, "dera"),
    pattern = "^sub_.*\\.parquet$",
    full.names = TRUE
  ),
  list.files(
    file.path(data_dir, "dera_notes"),
    pattern = "^sub_notes_.*\\.parquet$",
    full.names = TRUE
  )
)

accepted_files <- accepted_files[file.exists(accepted_files)]

read_metadata <- function(path) {
  metadata <- tryCatch(
    arrow::open_dataset(path)$schema$metadata,
    error = function(e) NULL
  )
  if (is.null(metadata)) list() else metadata
}

write_with_metadata <- function(df, path, metadata) {
  tmp <- tempfile(pattern = paste0(basename(path), "-"), fileext = ".parquet")
  on.exit(unlink(tmp), add = TRUE)

  tab <- arrow::arrow_table(df)
  existing <- tab$schema$metadata
  if (is.null(existing)) {
    existing <- list()
  }
  metadata <- scalar_metadata(c(existing, metadata))
  tab <- tab$ReplaceSchemaMetadata(metadata)
  arrow::write_parquet(tab, sink = tmp)

  if (!file.rename(tmp, path)) {
    stop("Could not replace Parquet file: ", path, call. = FALSE)
  }
}

assert_last_updated_unchanged <- function(path, before) {
  after <- read_metadata(path)
  changed <- vapply(
    last_updated_keys,
    function(key) !identical(before[[key]], after[[key]]),
    logical(1)
  )

  if (any(changed)) {
    stop(
      "Last-updated metadata changed for ",
      path,
      ": ",
      paste(last_updated_keys[changed], collapse = ", "),
      call. = FALSE
    )
  }
}

scalar_metadata <- function(metadata) {
  keep <- vapply(
    metadata,
    function(x) is.atomic(x) && length(x) == 1L && !is.na(x),
    logical(1)
  )
  metadata <- lapply(metadata[keep], as.character)
  metadata[!duplicated(names(metadata), fromLast = TRUE)]
}

format_datetime_range <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0L) {
    return("all NA")
  }

  paste(format(range(x), "%Y-%m-%d %H:%M:%S %Z"), collapse = " to ")
}

repair_file <- function(path) {
  metadata <- read_metadata(path)
  already_repaired <- identical(metadata[[repair_key]], "utc_assumed_wall_time_to_America/New_York") ||
    identical(metadata[["dera_datetime_timezone"]], sec_tz)

  if (already_repaired && !force) {
    message("Skipping already repaired file: ", path)
    return(invisible(FALSE))
  }

  df <- arrow::read_parquet(path, as_data_frame = TRUE)
  if (!"accepted" %in% names(df)) {
    message("Skipping file without accepted column: ", path)
    return(invisible(FALSE))
  }

  old_range <- format_datetime_range(df$accepted)
  df$accepted <- lubridate::force_tz(df$accepted, tzone = sec_tz)
  new_range <- format_datetime_range(df$accepted)

  message("Repairing ", path)
  message("  accepted before: ", old_range)
  message("  accepted after:  ", new_range)

  if (!execute) {
    return(invisible(TRUE))
  }

  metadata[[repair_key]] <- "utc_assumed_wall_time_to_America/New_York"
  metadata[["dera_accepted_timezone_repaired_at_utc"]] <- format(
    Sys.time(),
    "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  )
  metadata[["dera_datetime_columns"]] <- "accepted"
  metadata[["dera_datetime_timezone"]] <- sec_tz

  write_with_metadata(df, path, metadata)
  assert_last_updated_unchanged(path, metadata)
  invisible(TRUE)
}

message(
  if (execute) "Executing accepted timestamp timezone repair."
  else "Dry run only. Re-run with --execute to rewrite files."
)
message("DATA_DIR: ", data_dir)
message("Candidate files: ", length(accepted_files))

changed <- vapply(accepted_files, repair_file, logical(1))

message(
  if (execute) "Rewritten files: " else "Files that would be rewritten: ",
  sum(changed)
)
