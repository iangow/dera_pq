parse_http_datetime_utc <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x) || !nzchar(x)) {
    return(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"))
  }
  parsed <- strptime(x, format = "%a, %d %b %Y %H:%M:%S GMT", tz = "GMT")
  structure(as.numeric(parsed), class = c("POSIXct", "POSIXt"), tzone = "UTC")
}

http_datetime_iso <- function(x) {
  parsed <- parse_http_datetime_utc(x)
  if (is.na(parsed)) {
    return("")
  }
  format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

http_datetime_equal <- function(x, y) {
  parsed_x <- parse_http_datetime_utc(x)
  parsed_y <- parse_http_datetime_utc(y)
  if (is.na(parsed_x) || is.na(parsed_y)) {
    return(FALSE)
  }
  identical(as.numeric(parsed_x), as.numeric(parsed_y))
}

dera_metadata <- function(dataset, file, source_url, last_modified) {
  list(
    dera_dataset = dataset,
    dera_source_file = file,
    dera_source_url = source_url,
    sec_last_modified = last_modified %||% "",
    last_modified = last_modified %||% "",
    last_modified_utc = http_datetime_iso(last_modified)
  )
}

write_parquet_with_metadata <- function(df, sink, metadata) {
  tab <- arrow::arrow_table(df)
  existing <- tab$schema$metadata
  if (is.null(existing)) {
    existing <- list()
  }
  tab <- tab$ReplaceSchemaMetadata(c(existing, metadata))
  arrow::write_parquet(tab, sink = sink)
}

read_parquet_metadata <- function(path) {
  if (!file.exists(path)) {
    return(list())
  }
  metadata <- tryCatch(
    arrow::open_dataset(path)$schema$metadata,
    error = function(e) NULL
  )
  if (is.null(metadata)) {
    list()
  } else {
    metadata
  }
}

#' Read DERA metadata embedded in a Parquet file
#'
#' @param path Path to a Parquet file written by this package.
#'
#' @return A named list of Parquet schema metadata.
#' @export
dera_file_metadata <- function(path) {
  read_parquet_metadata(path)
}

metadata_last_modified_utc <- function(path) {
  metadata <- read_parquet_metadata(path)
  value <- metadata[["last_modified_utc"]]
  if (is.null(value) || is.na(value) || !nzchar(value)) {
    return("")
  }
  value
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
