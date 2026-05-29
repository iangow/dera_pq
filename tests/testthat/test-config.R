test_that("dataset configuration resolves standard DERA data", {
  cfg <- dera_datasets("dera")

  expect_equal(cfg$dataset, "dera")
  expect_equal(cfg$schema, "dera")
  expect_named(cfg$table_specs, c("sub", "tag", "num", "pre"))
  expect_equal(cfg$period("2024q1.zip"), "2024q1")
})

test_that("dataset configuration resolves DERA notes data", {
  cfg <- dera_datasets("dera_notes")

  expect_equal(cfg$dataset, "dera_notes")
  expect_equal(cfg$schema, "dera_notes")
  expect_named(
    cfg$table_specs,
    c(
      "sub_notes", "tag_notes", "dim_notes", "num_notes",
      "txt_notes", "ren_notes", "pre_notes", "cal_notes"
    )
  )
  expect_equal(cfg$period("2024q1_notes.zip"), "2024q1")
})

test_that("presentation table specs use tighter integer and logical types", {
  expect_equal(dera_datasets("dera")$table_specs$pre$col_types, "ciiclccccl")
  expect_equal(
    dera_datasets("dera_notes")$table_specs$pre_notes$col_types,
    "ciiclccccl"
  )
})

test_that("calculation table spec uses integer relationship fields", {
  expect_equal(
    dera_datasets("dera_notes")$table_specs$cal_notes$col_types,
    "ciiicccc"
  )
})

test_that("sub_notes spec tightens integer and logical numeric fields", {
  expect_equal(
    dera_datasets("dera_notes")$table_specs$sub_notes$col_types,
    "cicccccccccccccccccccdclccdicdcllcicddci"
  )
})

test_that("remaining notes table specs tighten numeric metadata fields", {
  specs <- dera_datasets("dera_notes")$table_specs

  expect_equal(specs$tag_notes$col_types, "ccllccccc")
  expect_equal(specs$dim_notes$col_types, "cci")
  expect_equal(specs$num_notes$col_types, "cccdiccidciicddi")
  expect_equal(specs$txt_notes$col_types, "cccdiiciddcicliicicc")
  expect_equal(specs$ren_notes$col_types, "ciccccccii")
})
