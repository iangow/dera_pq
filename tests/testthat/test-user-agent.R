test_that("user agent resolves from SEC_USER_AGENT", {
  old_env <- Sys.getenv("SEC_USER_AGENT", unset = NA_character_)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("SEC_USER_AGENT") else Sys.setenv(SEC_USER_AGENT = old_env)
  }, add = TRUE)

  Sys.setenv(SEC_USER_AGENT = "Ian Gow iandgow@example.com")

  expect_equal(
    dera_user_agent(prompt = FALSE),
    "Ian Gow iandgow@example.com"
  )
})

test_that("invalid resolved user agents error when prompting is disabled", {
  old_env <- Sys.getenv("SEC_USER_AGENT", unset = NA_character_)
  old_option <- getOption("HTTPUserAgent")
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("SEC_USER_AGENT") else Sys.setenv(SEC_USER_AGENT = old_env)
    options(HTTPUserAgent = old_option)
  }, add = TRUE)

  Sys.setenv(SEC_USER_AGENT = "dera.pq")
  expect_error(
    dera_user_agent(prompt = FALSE),
    "SEC_USER_AGENT is set"
  )

  Sys.unsetenv("SEC_USER_AGENT")
  options(HTTPUserAgent = "R")
  expect_error(
    dera_user_agent(prompt = FALSE),
    'getOption\\("HTTPUserAgent"\\) is set'
  )
})

test_that("dera_set_user_agent persists SEC_USER_AGENT", {
  renviron <- tempfile()
  on.exit(unlink(renviron), add = TRUE)

  expect_invisible(dera_set_user_agent(
    "Ian Gow iandgow@example.com",
    save = TRUE,
    renviron = renviron
  ))

  expect_equal(
    readLines(renviron, warn = FALSE),
    "SEC_USER_AGENT=Ian Gow iandgow@example.com"
  )
})
