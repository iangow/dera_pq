test_that("SEC HTTP datetimes are parsed as UTC instants", {
  old_tz <- Sys.getenv("TZ", unset = NA_character_)
  on.exit({
    if (is.na(old_tz)) Sys.unsetenv("TZ") else Sys.setenv(TZ = old_tz)
  }, add = TRUE)

  Sys.setenv(TZ = "America/New_York")
  ny_time <- parse_http_datetime_utc("Wed, 15 Nov 2023 21:46:14 GMT")

  Sys.setenv(TZ = "Pacific/Auckland")
  nz_time <- parse_http_datetime_utc("Wed, 15 Nov 2023 21:46:14 GMT")

  expect_equal(as.numeric(ny_time), as.numeric(nz_time))
  expect_equal(http_datetime_iso("Wed, 15 Nov 2023 21:46:14 GMT"),
               "2023-11-15T21:46:14Z")
  expect_true(http_datetime_equal(
    "Wed, 15 Nov 2023 21:46:14 GMT",
    "Wed, 15 Nov 2023 21:46:14 GMT"
  ))
})

test_that("update comparison uses parsed HTTP datetimes", {
  available <- tibble::tibble(
    file = "2024q1.zip",
    last_modified = "Wed, 15 Nov 2023 21:46:14 GMT",
    last_modified_utc = "2023-11-15T21:46:14Z"
  )
  current <- tibble::tibble(
    file = "2024q1.zip",
    last_modified = "Wed, 15 Nov 2023 21:46:14 GMT",
    last_modified_utc = "2023-11-15T21:46:14Z"
  )

  expect_equal(nrow(files_to_update(available, current)), 0)

  current$last_modified <- "Wed, 15 Nov 2023 21:46:13 GMT"
  expect_equal(files_to_update(available, current)$file, "2024q1.zip")
})

test_that("Arrow writer embeds SEC source metadata", {
  path <- tempfile(fileext = ".parquet")
  metadata <- dera_metadata(
    dataset = "dera",
    file = "2024q1.zip",
    source_url = "https://www.sec.gov/files/dera/data/financial-statement-data-sets/2024q1.zip",
    last_modified = "Wed, 15 Nov 2023 21:46:14 GMT"
  )

  write_parquet_with_metadata(data.frame(x = 1), path, metadata)
  pq_metadata <- dera_file_metadata(path)

  expect_equal(pq_metadata$dera_dataset, "dera")
  expect_equal(pq_metadata$dera_source_file, "2024q1.zip")
  expect_equal(pq_metadata$last_modified, "Wed, 15 Nov 2023 21:46:14 GMT")
  expect_equal(pq_metadata$last_modified_utc, "2023-11-15T21:46:14Z")
  expect_null(pq_metadata$downloaded_at_utc)
})
