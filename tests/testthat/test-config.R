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
