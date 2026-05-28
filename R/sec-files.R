get_last_modified <- function(url, user_agent = NULL) {
  user_agent <- dera_user_agent(user_agent)

  resp <- httr2::request(url) |>
    httr2::req_method("HEAD") |>
    httr2::req_user_agent(user_agent) |>
    httr2::req_perform()

  httr2::resp_headers(resp)[["last-modified"]]
}

#' List SEC DERA zip files available for download
#'
#' @param dataset One of `"dera"` or `"dera_notes"`.
#' @param user_agent Optional SEC-compliant user agent. If omitted, resolved
#'   using `dera_user_agent()`.
#'
#' @return A tibble with `file`, `last_modified`, and `last_modified_utc`.
#' @export
available_dera_files <- function(dataset = c("dera", "dera_notes"),
                                 user_agent = NULL) {
  cfg <- dera_datasets(dataset)
  user_agent <- dera_user_agent(user_agent)

  resp <- httr2::request(cfg$page_url) |>
    httr2::req_user_agent(user_agent) |>
    httr2::req_perform() |>
    httr2::resp_body_html() |>
    rvest::html_elements("body") |>
    rvest::html_elements("a") |>
    as.character()

  files <- tibble::tibble(value = resp) |>
    dplyr::filter(stringr::str_detect(.data$value, "zip")) |>
    dplyr::mutate(
      file = stringr::str_replace(.data$value, "^.*data-sets/(.*\\.zip).*$", "\\1")
    ) |>
    dplyr::distinct(.data$file) |>
    dplyr::arrange(.data$file)

  get_modified <- function(file) {
    get_last_modified(paste0(cfg$zip_base_url, file), user_agent = user_agent)
  }

  files |>
    dplyr::mutate(
      last_modified = purrr::map_chr(.data$file, get_modified),
      last_modified_utc = purrr::map_chr(.data$last_modified, http_datetime_iso)
    ) |>
    dplyr::select(.data$file, .data$last_modified, .data$last_modified_utc)
}

#' List SEC DERA Financial Statement Data Set source files
#'
#' @inheritParams available_dera_files
#'
#' @return A tibble with `file`, `last_modified`, and `last_modified_utc`.
#' @export
available_dera <- function(user_agent = NULL) {
  available_dera_files("dera", user_agent = user_agent)
}

#' List SEC DERA Financial Statement and Notes source files
#'
#' @inheritParams available_dera_files
#'
#' @return A tibble with `file`, `last_modified`, and `last_modified_utc`.
#' @export
available_dera_notes <- function(user_agent = NULL) {
  available_dera_files("dera_notes", user_agent = user_agent)
}

local_source_metadata <- function(available, cfg, data_dir) {
  if (nrow(available) == 0) {
    return(tibble::tibble(
      file = character(),
      last_modified = character(),
      last_modified_utc = character()
    ))
  }

  purrr::map_dfr(seq_len(nrow(available)), function(i) {
    source_file <- available$file[[i]]
    period <- cfg$period(source_file)
    paths <- purrr::imap_chr(cfg$table_specs, function(spec, table) {
      file.path(data_dir, cfg$schema, paste0(table, "_", period, ".parquet"))
    })
    local_modified <- purrr::map_chr(paths, metadata_last_modified_utc)
    all_present <- all(file.exists(paths))
    consistent <- length(unique(local_modified)) == 1L && nzchar(local_modified[[1]])

    tibble::tibble(
      file = source_file,
      last_modified = if (consistent) {
        read_parquet_metadata(paths[[1]])[["last_modified"]] %||% ""
      } else {
        ""
      },
      last_modified_utc = if (all_present && consistent) local_modified[[1]] else ""
    )
  })
}

files_to_update <- function(available, current) {
  available |>
    dplyr::left_join(
      current,
      by = "file",
      suffix = c("_new", "_old")
    ) |>
    dplyr::filter(
      is.na(.data$last_modified_old) |
        !purrr::map2_lgl(
          .data$last_modified_new,
          .data$last_modified_old,
          http_datetime_equal
        )
    ) |>
    dplyr::transmute(
      file = .data$file,
      last_modified = .data$last_modified_new,
      last_modified_utc = .data$last_modified_utc_new
    )
}
