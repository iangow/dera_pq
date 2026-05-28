update_dataset <- function(dataset, data_dir = NULL,
                           user_agent = NULL,
                           archive_orphans = FALSE, quiet = FALSE,
                           cache = TRUE, force = FALSE) {
  cfg <- dera_datasets(dataset)
  data_dir <- dera_data_dir(data_dir)
  user_agent <- dera_user_agent(user_agent)

  available <- available_dera_files(cfg$dataset, user_agent = user_agent)
  current <- if (isTRUE(force)) NULL else local_source_metadata(available, cfg, data_dir)
  todo <- files_to_process(available, current, force = force)

  if (nrow(todo) == 0) {
    if (!quiet) message("No updates needed for ", cfg$dataset, ".")
  } else {
    if (!quiet) {
      action <- if (isTRUE(force)) "Reprocessing " else "Updating "
      message(action, nrow(todo), " ", cfg$dataset, " zip file(s).")
    }
    purrr::pwalk(
      todo,
      function(file, last_modified, last_modified_utc) {
        update_dataset_file(
          file = file,
          dataset = cfg$dataset,
          data_dir = data_dir,
          user_agent = user_agent,
          last_modified = last_modified,
          quiet = quiet,
          cache = cache
        )
      }
    )
  }

  if (archive_orphans) {
    archive_orphaned_parquet(available, cfg, data_dir, quiet = quiet)
  }

  invisible(todo)
}

files_to_process <- function(available, current = NULL, force = FALSE) {
  if (isTRUE(force)) {
    return(available)
  }
  files_to_update(available, current)
}

#' Update SEC DERA Financial Statement Data Set Parquet files
#'
#' Downloads new or changed SEC DERA Financial Statement Data Set zip files and
#' writes `sub`, `tag`, `num`, and `pre` Parquet files under `$DATA_DIR/dera`.
#'
#' @param data_dir Root of the local Parquet repository. If omitted, resolved
#'   using `dera_data_dir()`.
#' @param user_agent Optional SEC-compliant user agent. If omitted, resolved
#'   using `dera_user_agent()`.
#' @param quiet If `TRUE`, suppress progress messages.
#' @param cache If `TRUE`, cache downloaded zip files under
#'   `tools::R_user_dir("dera.pq", "cache")`. If a string, use that directory
#'   as the zip cache. If `FALSE`, download to a temporary file and delete it
#'   after processing.
#' @param force If `TRUE`, reprocess all SEC source zip files listed by the SEC
#'   even when the local Parquet files already appear current.
#'
#' @return Invisibly, a tibble of source zip files that were updated.
#' @export
update_dera <- function(data_dir = NULL,
                        user_agent = NULL,
                        quiet = FALSE,
                        cache = TRUE,
                        force = FALSE) {
  update_dataset(
    dataset = "dera",
    data_dir = data_dir,
    user_agent = user_agent,
    archive_orphans = FALSE,
    quiet = quiet,
    cache = cache,
    force = force
  )
}

#' Update SEC DERA Financial Statement and Notes Parquet files
#'
#' Downloads new or changed SEC DERA Financial Statement and Notes zip files and
#' writes their component tables under `$DATA_DIR/dera_notes`.
#'
#' @inheritParams update_dera
#' @param archive_orphans If `TRUE`, move Parquet files for periods no longer
#'   listed by the SEC into `$DATA_DIR/dera_notes/archive`.
#'
#' @return Invisibly, a tibble of source zip files that were updated.
#' @export
update_dera_notes <- function(data_dir = NULL,
                              user_agent = NULL,
                              archive_orphans = TRUE,
                              quiet = FALSE,
                              cache = TRUE,
                              force = FALSE) {
  update_dataset(
    dataset = "dera_notes",
    data_dir = data_dir,
    user_agent = user_agent,
    archive_orphans = archive_orphans,
    quiet = quiet,
    cache = cache,
    force = force
  )
}

archive_orphaned_parquet <- function(available, cfg, data_dir, quiet = FALSE) {
  available_periods <- cfg$period(available$file)
  pq_dir <- file.path(data_dir, cfg$schema)

  if (!dir.exists(pq_dir)) {
    return(invisible(character()))
  }

  pattern <- if (identical(cfg$dataset, "dera_notes")) {
    "^[a-z]+_notes_.*\\.parquet$"
  } else {
    "^[a-z]+_.*\\.parquet$"
  }

  pq_files <- list.files(pq_dir, pattern = pattern)
  if (length(pq_files) == 0) {
    return(invisible(character()))
  }

  periods <- if (identical(cfg$dataset, "dera_notes")) {
    stringr::str_replace(pq_files, "^[a-z]+_notes_(.+)\\.parquet$", "\\1")
  } else {
    stringr::str_replace(pq_files, "^[a-z]+_(.+)\\.parquet$", "\\1")
  }

  orphaned <- pq_files[!periods %in% available_periods]
  if (length(orphaned) == 0) {
    return(invisible(character()))
  }

  archive_dir <- file.path(pq_dir, "archive")
  dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)

  if (!quiet) {
    message(
      "Archiving ", length(orphaned),
      " parquet file(s) whose source is no longer listed by the SEC."
    )
  }

  file.rename(
    file.path(pq_dir, orphaned),
    file.path(archive_dir, orphaned)
  )

  invisible(orphaned)
}
