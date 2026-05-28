#' Resolve the SEC user agent
#'
#' Resolves the SEC user agent from, in order, an explicit argument, the
#' `SEC_USER_AGENT` environment variable, and `getOption("HTTPUserAgent")`.
#'
#' @param user_agent Optional SEC user-agent override.
#' @param prompt If `TRUE`, prompt interactively when no user agent can be
#'   resolved.
#'
#' @return A non-empty character string containing an email address.
#' @export
dera_user_agent <- function(user_agent = NULL, prompt = interactive()) {
  if (!is.null(user_agent) && nzchar(user_agent)) {
    return(.validate_user_agent(user_agent))
  }

  env_user_agent <- Sys.getenv("SEC_USER_AGENT", unset = "")
  if (nzchar(env_user_agent)) {
    return(.validate_user_agent(env_user_agent))
  }

  option_user_agent <- getOption("HTTPUserAgent", default = "")
  if (is.character(option_user_agent) && length(option_user_agent) == 1 &&
      nzchar(option_user_agent)) {
    return(.validate_user_agent(option_user_agent))
  }

  if (isTRUE(prompt)) {
    return(.prompt_user_agent())
  }

  rlang::abort(paste0(
    'Could not resolve an SEC user agent. Provide `user_agent`, set ',
    '`SEC_USER_AGENT`, or run `dera_set_user_agent()`.'
  ))
}

#' Store the SEC user agent for this session and optionally future sessions
#'
#' @param user_agent SEC user agent containing an email address.
#' @param save If `TRUE`, store `SEC_USER_AGENT` in `~/.Renviron`.
#' @param renviron `.Renviron` path used when `save = TRUE`.
#'
#' @return The user agent, invisibly.
#' @export
dera_set_user_agent <- function(user_agent, save = interactive(),
                                renviron = file.path(path.expand("~"), ".Renviron")) {
  user_agent <- .validate_user_agent(user_agent)
  Sys.setenv(SEC_USER_AGENT = user_agent)
  options(HTTPUserAgent = user_agent)

  if (isTRUE(save)) {
    .set_renviron_value("SEC_USER_AGENT", user_agent, renviron = renviron)
  }

  invisible(user_agent)
}

.validate_user_agent <- function(user_agent) {
  if (!is.character(user_agent) || length(user_agent) != 1 ||
      is.na(user_agent) || !grepl("@", user_agent)) {
    rlang::abort("SEC user agent must be a single string containing an email address.")
  }
  user_agent
}

.prompt_user_agent <- function() {
  user_agent <- trimws(readline("SEC user agent, including email address: "))
  if (!nzchar(user_agent)) {
    stop("SEC user agent cannot be empty.", call. = FALSE)
  }
  user_agent <- .validate_user_agent(user_agent)

  Sys.setenv(SEC_USER_AGENT = user_agent)
  options(HTTPUserAgent = user_agent)
  answer <- tolower(trimws(readline(
    "Store SEC_USER_AGENT in ~/.Renviron for future R sessions? [Y/n] "
  )))
  if (answer %in% c("", "y", "yes")) {
    .set_renviron_value(
      "SEC_USER_AGENT",
      user_agent,
      renviron = file.path(path.expand("~"), ".Renviron")
    )
  }

  user_agent
}
