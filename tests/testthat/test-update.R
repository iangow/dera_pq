test_that("forced updates use all available SEC files", {
  available <- tibble::tibble(
    file = c("2024q1.zip", "2024q2.zip"),
    last_modified = c(
      "Wed, 15 Nov 2023 21:46:14 GMT",
      "Thu, 16 Nov 2023 21:46:14 GMT"
    ),
    last_modified_utc = c("2023-11-15T21:46:14Z", "2023-11-16T21:46:14Z")
  )
  current <- available

  expect_equal(nrow(files_to_update(available, current)), 0)
  expect_equal(
    files_to_process(available, current, force = TRUE)$file,
    c("2024q1.zip", "2024q2.zip")
  )
  expect_equal(nrow(files_to_process(available, current, force = FALSE)), 0)
})
