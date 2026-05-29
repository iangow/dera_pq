test_that("read_zip_table warnings identify source file and table", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  writeLines(c("x", "not-a-number"), file.path(tmp, "num.tsv"))
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", "num.tsv", flags = "-q")

  spec <- table_spec(source = "num.tsv", col_types = "d")
  expect_warning(
    read_zip_table(
      "source.zip",
      spec,
      source_file = "2025_04_notes.zip",
      table = "num_notes"
    ),
    paste0(
      "Parsing issues in SEC source file '2025_04_notes.zip', ",
      "table 'num_notes' \\(num.tsv\\): 1 issue\\(s\\).*row 2"
    )
  )
})

test_that("read_zip_table treats quotes in SEC TSV text as literal characters", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  writeLines(
    c(
      paste(c("shortname", "longname"), collapse = "\t"),
      paste(c(
        "\"SUNWIN STEVIA INTERNATIONAL, INC.",
        "000030 - Statement - \"SUNWIN STEVIA INTERNATIONAL, INC."
      ), collapse = "\t")
    ),
    file.path(tmp, "ren.tsv")
  )
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", "ren.tsv", flags = "-q")

  spec <- table_spec(source = "ren.tsv", col_types = "cc", quote = "")
  expect_warning(
    df <- read_zip_table(
      "source.zip",
      spec,
      source_file = "2018q3_notes.zip",
      table = "ren_notes"
    ),
    NA
  )

  expect_equal(ncol(df), 2)
  expect_match(df$shortname, '^"SUNWIN')
  expect_match(df$longname, 'Statement - "SUNWIN')
})

test_that("read_zip_table keeps quoted tabs when quote parsing is enabled", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  writeLines(
    c(
      paste(c("dimhash", "segments", "segt"), collapse = "\t"),
      paste(c(
        "0x43d8827a2096af5f7f8b960b569b3bdb",
        "\"InvestmentIdentifier=Ocular Therapeutix, Inc.,\tPharma-ceuticals;\"",
        "0"
      ), collapse = "\t")
    ),
    file.path(tmp, "dim.tsv")
  )
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", "dim.tsv", flags = "-q")

  spec <- table_spec(source = "dim.tsv", col_types = "ccd")
  expect_warning(
    df <- read_zip_table(
      "source.zip",
      spec,
      source_file = "2024q4_notes.zip",
      table = "dim_notes"
    ),
    NA
  )

  expect_equal(ncol(df), 3)
  expect_match(df$segments, "Ocular Therapeutix")
  expect_equal(df$segt, 0)
})

test_that("tab repair folds extra trailing text fields", {
  line <- paste(c("a", "b", "text", "with", "tabs"), collapse = "\t")

  expect_equal(
    .repair_tsv_line(line, expected_cols = 3),
    paste(c("a", "b", "text with tabs"), collapse = "\t")
  )
  expect_equal(
    .repair_tsv_line("a\tb", expected_cols = 3),
    "a\tb\t"
  )
})

test_that("read_zip_table repairs embedded tabs in trailing text columns", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  writeLines(
    c(
      paste(c("a", "b", "value"), collapse = "\t"),
      paste(c("x", "y", "text", "with", "tabs"), collapse = "\t")
    ),
    file.path(tmp, "txt.tsv")
  )
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", "txt.tsv", flags = "-q")

  spec <- table_spec(
    source = "txt.tsv",
    col_types = "ccc",
    fallback_quote = "",
    repair_tabs = TRUE
  )
  expect_warning(
    df <- read_zip_table(
      "source.zip",
      spec,
      source_file = "test_notes.zip",
      table = "txt_notes"
    ),
    NA
  )

  expect_equal(df$value, "text with tabs")
  expect_equal(nrow(attr(df, "dera_initial_parse_problems")), 1)
  expect_equal(nrow(attr(df, "dera_parse_problems")), 0)
  expect_equal(attr(df, "dera_parse_repairs"), c("quote-fallback", "tab-repair"))
  expect_equal(
    .parsing_metadata(df, "txt_notes", "txt.tsv")$dera_initial_parse_problem_count,
    "1"
  )
  expect_equal(
    .parsing_metadata(df, "txt_notes", "txt.tsv")$dera_parse_repairs,
    "quote-fallback,tab-repair"
  )
})

test_that("fallback quote parsing is only used after an initial problem", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  writeLines(
    c(
      paste(c("id", "text"), collapse = "\t"),
      paste(c("1", "\"quoted text\""), collapse = "\t")
    ),
    file.path(tmp, "tag.tsv")
  )
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", "tag.tsv", flags = "-q")

  spec <- table_spec(source = "tag.tsv", col_types = "cc", fallback_quote = "")
  expect_warning(
    df <- read_zip_table(
      "source.zip",
      spec,
      source_file = "test_notes.zip",
      table = "tag_notes"
    ),
    NA
  )

  expect_equal(df$text, "quoted text")
  expect_equal(attr(df, "dera_parse_repairs"), character())
})

test_that("parse problem metadata is available for parquet writes", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  writeLines(c("x", "not-a-number"), file.path(tmp, "num.tsv"))
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", "num.tsv", flags = "-q")

  spec <- table_spec(source = "num.tsv", col_types = "d")
  df <- suppressWarnings(read_zip_table(
    "source.zip",
    spec,
    source_file = "2025_04_notes.zip",
    table = "num_notes"
  ))

  expect_equal(
    .parsing_metadata(df, "num_notes", "num.tsv")$dera_parse_problem_count,
    "1"
  )
  expect_equal(
    .parsing_metadata(df, "num_notes", "num.tsv")$dera_parse_problem_rows,
    "2"
  )
})

test_that("zip cache path defaults under user cache directory and schema", {
  cfg <- dera_datasets("dera_notes")

  expect_equal(
    .zip_cache_file("2024q1_notes.zip", cfg, "/tmp/data", cache = TRUE),
    file.path(
      tools::R_user_dir("dera.pq", "cache"),
      "dera_notes",
      "2024q1_notes.zip"
    )
  )
  expect_null(.zip_cache_file("2024q1_notes.zip", cfg, "/tmp/data", cache = FALSE))
  expect_equal(
    .zip_cache_file("2024q1_notes.zip", cfg, "/tmp/data", cache = "/tmp/cache"),
    file.path("/tmp/cache", "2024q1_notes.zip")
  )
})

test_that("valid zip cache detection rejects missing and invalid files", {
  missing <- tempfile(fileext = ".zip")
  invalid <- tempfile(fileext = ".zip")
  writeLines("not a zip", invalid)
  on.exit(unlink(invalid), add = TRUE)

  expect_false(.valid_zip_file(missing))
  expect_false(.valid_zip_file(invalid))
})

test_that("zip cache metadata records Last-Modified values", {
  cache_file <- tempfile(fileext = ".zip")
  metadata_file <- .zip_cache_metadata_file(cache_file)
  on.exit(unlink(c(cache_file, metadata_file)), add = TRUE)

  last_modified <- "Wed, 15 Nov 2023 21:46:14 GMT"
  .write_zip_cache_metadata(
    cache_file,
    "https://www.sec.gov/files/example.zip",
    last_modified
  )

  metadata <- .read_zip_cache_metadata(cache_file)
  expect_equal(metadata$URL, "https://www.sec.gov/files/example.zip")
  expect_equal(metadata[["Last-Modified"]], last_modified)
  expect_equal(metadata[["Last-Modified-UTC"]], "2023-11-15T21:46:14Z")
  expect_true(.zip_cache_metadata_matches(cache_file, last_modified))
  expect_false(.zip_cache_metadata_matches(
    cache_file,
    "Thu, 16 Nov 2023 21:46:14 GMT"
  ))
})

test_that("cached zips without metadata are replaced when Last-Modified is known", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  writeLines(c("x", "1"), file.path(tmp, "x.tsv"))
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", "x.tsv", flags = "-q")

  last_modified <- "Wed, 15 Nov 2023 21:46:14 GMT"
  expect_false(.zip_cache_metadata_matches("source.zip", last_modified))

  .write_zip_cache_metadata("source.zip", "https://www.sec.gov/files/source.zip", last_modified)
  expect_true(.zip_cache_metadata_matches("source.zip", last_modified))
})
