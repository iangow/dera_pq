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
