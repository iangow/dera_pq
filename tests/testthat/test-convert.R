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

test_that("pre_notes presentation columns are parsed as integer and logical", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  writeLines(
    c(
      paste(
        c("adsh", "report", "line", "stmt", "inpth", "tag",
          "version", "prole", "plabel", "negating"),
        collapse = "\t"
      ),
      paste(
        c("0000000000-00-000000", "4", "12", "CF", "0", "NetIncomeLoss",
          "us-gaap/2024", "http://example.com", "Net income", "1"),
        collapse = "\t"
      )
    ),
    file.path(tmp, "pre.tsv")
  )
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", "pre.tsv", flags = "-q")

  df <- read_zip_table(
    "source.zip",
    dera_datasets("dera_notes")$table_specs$pre_notes,
    source_file = "test_notes.zip",
    table = "pre_notes"
  )

  expect_type(df$report, "integer")
  expect_type(df$line, "integer")
  expect_type(df$inpth, "logical")
  expect_type(df$negating, "logical")
  expect_false(df$inpth[[1]])
  expect_true(df$negating[[1]])
})

test_that("cal_notes relationship columns are parsed as integers", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  writeLines(
    c(
      paste(
        c("adsh", "grp", "arc", "negative", "ptag", "pversion", "ctag", "cversion"),
        collapse = "\t"
      ),
      paste(
        c("0000000000-00-000000", "4", "12", "-1",
          "NetCashProvidedByUsedInOperatingActivities", "us-gaap/2024",
          "NetIncomeLoss", "us-gaap/2024"),
        collapse = "\t"
      )
    ),
    file.path(tmp, "cal.tsv")
  )
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", "cal.tsv", flags = "-q")

  df <- read_zip_table(
    "source.zip",
    dera_datasets("dera_notes")$table_specs$cal_notes,
    source_file = "test_notes.zip",
    table = "cal_notes"
  )

  expect_type(df$grp, "integer")
  expect_type(df$arc, "integer")
  expect_type(df$negative, "integer")
  expect_equal(df$negative[[1]], -1L)
})

test_that("sub_notes numeric columns are parsed with tighter types", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  cols <- c(
    "adsh", "cik", "name", "sic", "countryba", "stprba", "cityba", "zipba",
    "bas1", "bas2", "baph", "countryma", "stprma", "cityma", "zipma",
    "mas1", "mas2", "countryinc", "stprinc", "ein", "former", "changed",
    "afs", "wksi", "fye", "form", "period", "fy", "fp", "filed", "accepted",
    "prevrpt", "detail", "instance", "nciks", "aciks", "pubfloatusd",
    "floatdate", "floataxis", "floatmems"
  )
  values <- c(
    "0000000000-00-000000", "123456", "Example Inc.", "2834", "US", "CA",
    "San Francisco", "94105", "1 Main St", "", "415-555-1212", "US", "CA",
    "San Francisco", "94105", "1 Main St", "", "US", "DE", "12-3456789",
    "", "20240101", "1-LAF", "1", "1231", "10-K", "20231231", "2023",
    "FY", "20240215", "2024-02-15 16:01:02", "0", "1", "example.htm",
    "2", "", "1234.56", "20230630", "PublicFloatAxis", "3"
  )

  writeLines(
    c(paste(cols, collapse = "\t"), paste(values, collapse = "\t")),
    file.path(tmp, "sub.tsv")
  )
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", "sub.tsv", flags = "-q")

  df <- read_zip_table(
    "source.zip",
    dera_datasets("dera_notes")$table_specs$sub_notes,
    source_file = "test_notes.zip",
    table = "sub_notes"
  )

  expect_type(df$cik, "integer")
  expect_type(df$wksi, "logical")
  expect_type(df$fy, "integer")
  expect_type(df$prevrpt, "logical")
  expect_type(df$detail, "logical")
  expect_type(df$nciks, "integer")
  expect_type(df$pubfloatusd, "double")
  expect_type(df$floatmems, "integer")
  expect_true(df$wksi[[1]])
  expect_false(df$prevrpt[[1]])
  expect_true(df$detail[[1]])
})

test_that("num_notes numeric metadata columns are parsed with tighter types", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  writeLines(
    c(
      paste(
        c("adsh", "tag", "version", "ddate", "qtrs", "uom", "dimh", "iprx",
          "value", "footnote", "footlen", "dimn", "coreg", "durp", "datp",
          "dcml"),
        collapse = "\t"
      ),
      paste(
        c("0000000000-00-000000", "Revenue", "us-gaap/2024", "20231231",
          "4", "USD", "0x0", "2", "1234.56", "", "5", "3", "",
          "0.25", "-4.5", "-6"),
        collapse = "\t"
      )
    ),
    file.path(tmp, "num.tsv")
  )
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", "num.tsv", flags = "-q")

  df <- read_zip_table(
    "source.zip",
    dera_datasets("dera_notes")$table_specs$num_notes,
    source_file = "test_notes.zip",
    table = "num_notes"
  )

  expect_type(df$qtrs, "integer")
  expect_type(df$iprx, "integer")
  expect_type(df$value, "double")
  expect_type(df$footlen, "integer")
  expect_type(df$dimn, "integer")
  expect_type(df$durp, "double")
  expect_type(df$datp, "double")
  expect_type(df$dcml, "integer")
})

test_that("txt_notes numeric metadata columns are parsed with tighter types", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  writeLines(
    c(
      paste(
        c("adsh", "tag", "version", "ddate", "qtrs", "iprx", "lang",
          "dcml", "durp", "datp", "dimh", "dimn", "coreg", "escaped",
          "srclen", "txtlen", "footnote", "footlen", "context", "value"),
        collapse = "\t"
      ),
      paste(
        c("0000000000-00-000000", "TextBlock", "us-gaap/2024", "20231231",
          "4", "2", "en-US", "32767", "0.25", "-4.5", "0x0", "3", "",
          "1", "100", "80", "", "5", "ctx", "Some text"),
        collapse = "\t"
      )
    ),
    file.path(tmp, "txt.tsv")
  )
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", "txt.tsv", flags = "-q")

  df <- read_zip_table(
    "source.zip",
    dera_datasets("dera_notes")$table_specs$txt_notes,
    source_file = "test_notes.zip",
    table = "txt_notes"
  )

  expect_type(df$qtrs, "integer")
  expect_type(df$iprx, "integer")
  expect_type(df$dcml, "integer")
  expect_type(df$durp, "double")
  expect_type(df$datp, "double")
  expect_type(df$dimn, "integer")
  expect_type(df$escaped, "logical")
  expect_type(df$srclen, "integer")
  expect_type(df$txtlen, "integer")
  expect_type(df$footlen, "integer")
  expect_true(df$escaped[[1]])
})

test_that("tag dim and ren notes numeric columns are parsed with tighter types", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  writeLines(
    c(
      paste(c("tag", "version", "custom", "abstract", "datatype",
              "iord", "crdr", "tlabel", "doc"), collapse = "\t"),
      paste(c("Revenue", "us-gaap/2024", "1", "0", "monetary",
              "I", "credit", "Revenue", "Documentation"), collapse = "\t")
    ),
    file.path(tmp, "tag.tsv")
  )
  writeLines(
    c(
      paste(c("dimhash", "segments", "segt"), collapse = "\t"),
      paste(c("0x0", "", "0"), collapse = "\t")
    ),
    file.path(tmp, "dim.tsv")
  )
  writeLines(
    c(
      paste(c("adsh", "report", "rfile", "menucat", "shortname", "longname",
              "roleuri", "parentroleuri", "parentreport", "ultparentrpt"),
            collapse = "\t"),
      paste(c("0000000000-00-000000", "4", "H", "Statements", "Cash flows",
              "Statement - Cash flows", "role", "", "2", "1"), collapse = "\t")
    ),
    file.path(tmp, "ren.tsv")
  )
  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", c("tag.tsv", "dim.tsv", "ren.tsv"), flags = "-q")

  specs <- dera_datasets("dera_notes")$table_specs
  tag <- read_zip_table("source.zip", specs$tag_notes, "test_notes.zip", "tag_notes")
  dim <- read_zip_table("source.zip", specs$dim_notes, "test_notes.zip", "dim_notes")
  ren <- read_zip_table("source.zip", specs$ren_notes, "test_notes.zip", "ren_notes")

  expect_type(tag$custom, "logical")
  expect_type(tag$abstract, "logical")
  expect_true(tag$custom[[1]])
  expect_false(tag$abstract[[1]])
  expect_type(dim$segt, "integer")
  expect_type(ren$report, "integer")
  expect_type(ren$parentreport, "integer")
  expect_type(ren$ultparentrpt, "integer")
})

test_that("standard DERA sub tag num and pre columns parse with tighter types", {
  skip_if(Sys.which("zip") == "")

  tmp <- tempfile()
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

  sub_cols <- c(
    "adsh", "cik", "name", "sic", "countryba", "stprba", "cityba", "zipba",
    "bas1", "bas2", "baph", "countryma", "stprma", "cityma", "zipma",
    "mas1", "mas2", "countryinc", "stprinc", "ein", "former", "changed",
    "afs", "wksi", "fye", "form", "period", "fy", "fp", "filed", "accepted",
    "prevrpt", "detail", "instance", "nciks", "aciks"
  )
  sub_values <- c(
    "0000000000-00-000000", "123456", "Example Inc.", "2834", "US", "CA",
    "San Francisco", "94105", "1 Main St", "", "415-555-1212", "US", "CA",
    "San Francisco", "94105", "1 Main St", "", "US", "DE", "12-3456789",
    "", "20240101", "1-LAF", "1", "1231", "10-K", "20231231", "2023",
    "FY", "20240215", "2024-02-15 16:01:02", "0", "1", "example.htm",
    "2", ""
  )
  writeLines(
    c(paste(sub_cols, collapse = "\t"), paste(sub_values, collapse = "\t")),
    file.path(tmp, "sub.txt")
  )
  writeLines(
    c(
      paste(c("tag", "version", "custom", "abstract", "datatype",
              "iord", "crdr", "tlabel", "doc"), collapse = "\t"),
      paste(c("Revenue", "us-gaap/2024", "1", "0", "monetary",
              "I", "credit", "Revenue", "Documentation"), collapse = "\t")
    ),
    file.path(tmp, "tag.txt")
  )
  writeLines(
    c(
      paste(c("adsh", "tag", "version", "ddate", "qtrs", "uom",
              "segments", "coreg", "value", "footnote"), collapse = "\t"),
      paste(c("0000000000-00-000000", "Revenue", "us-gaap/2024", "20231231",
              "4", "USD", "", "", "1234.56", ""), collapse = "\t")
    ),
    file.path(tmp, "num.txt")
  )
  writeLines(
    c(
      paste(c("adsh", "report", "line", "stmt", "inpth", "rfile",
              "tag", "version", "plabel", "negating"), collapse = "\t"),
      paste(c("0000000000-00-000000", "4", "12", "CF", "0", "H",
              "NetIncomeLoss", "us-gaap/2024", "Net income", "1"), collapse = "\t")
    ),
    file.path(tmp, "pre.txt")
  )

  old_wd <- setwd(tmp)
  on.exit(setwd(old_wd), add = TRUE)
  utils::zip("source.zip", c("sub.txt", "tag.txt", "num.txt", "pre.txt"), flags = "-q")

  specs <- dera_datasets("dera")$table_specs
  sub <- read_zip_table("source.zip", specs$sub, "test.zip", "sub")
  tag <- read_zip_table("source.zip", specs$tag, "test.zip", "tag")
  num <- read_zip_table("source.zip", specs$num, "test.zip", "num")
  pre <- read_zip_table("source.zip", specs$pre, "test.zip", "pre")

  expect_type(sub$cik, "integer")
  expect_type(sub$sic, "integer")
  expect_type(sub$wksi, "logical")
  expect_type(sub$fy, "integer")
  expect_type(sub$prevrpt, "logical")
  expect_type(sub$detail, "logical")
  expect_type(sub$nciks, "integer")
  expect_type(tag$custom, "logical")
  expect_type(tag$abstract, "logical")
  expect_type(num$qtrs, "integer")
  expect_type(num$value, "double")
  expect_type(pre$report, "integer")
  expect_type(pre$line, "integer")
  expect_type(pre$inpth, "logical")
  expect_type(pre$negating, "logical")
})
