#' Resolve the SEC user agent
#'
#' Resolves the SEC user agent from, in order, an explicit argument, the
#' `SEC_USER_AGENT` environment variable, and `getOption("HTTPUserAgent")`.
#' In an interactive session, when no valid value can be resolved, the helper
#' asks for a user agent and offers to persist it in either project-level
#' `.Renviron` or user-level `~/.Renviron`.
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
    if (.is_valid_user_agent(env_user_agent)) {
      return(env_user_agent)
    }
    if (isTRUE(prompt)) {
      message("SEC_USER_AGENT does not contain an email address.")
      return(.prompt_user_agent())
    }
    return(.abort_invalid_resolved_user_agent("SEC_USER_AGENT"))
  }

  option_user_agent <- getOption("HTTPUserAgent", default = "")
  if (is.character(option_user_agent) && length(option_user_agent) == 1 &&
      nzchar(option_user_agent)) {
    if (.is_valid_user_agent(option_user_agent)) {
      return(option_user_agent)
    }
    if (isTRUE(prompt)) {
      message('getOption("HTTPUserAgent") does not contain an email address.')
      return(.prompt_user_agent())
    }
    return(.abort_invalid_resolved_user_agent('getOption("HTTPUserAgent")'))
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
  if (!.is_valid_user_agent(user_agent)) {
    rlang::abort("SEC user agent must be a single string containing an email address.")
  }
  user_agent
}

.is_valid_user_agent <- function(user_agent) {
  is.character(user_agent) &&
    length(user_agent) == 1 &&
    !is.na(user_agent) &&
    nzchar(user_agent) &&
    grepl("@", user_agent)
}

.abort_invalid_resolved_user_agent <- function(source) {
  rlang::abort(paste0(
    source,
    " is set, but it is not an SEC-compliant user agent because it does ",
    "not contain an email address. Set `SEC_USER_AGENT`, set ",
    '`options(HTTPUserAgent = "your_name@email.com")`, or run ',
    "`dera_set_user_agent()`."
  ))
}

.prompt_user_agent <- function() {
  message("SEC automated-access guidance asks for a user agent containing an email address.")
  user_agent <- trimws(readline("SEC user agent, including email address: "))
  if (!nzchar(user_agent)) {
    stop("SEC user agent cannot be empty.", call. = FALSE)
  }
  user_agent <- .validate_user_agent(user_agent)

  Sys.setenv(SEC_USER_AGENT = user_agent)
  options(HTTPUserAgent = user_agent)
  scope <- .prompt_user_agent_scope()
  if (!identical(scope, "none")) {
    .set_renviron_value(
      "SEC_USER_AGENT",
      user_agent,
      renviron = .renviron_path(scope)
    )
  }

  user_agent
}

.prompt_user_agent_scope <- function() {
  repeat {
    answer <- tolower(trimws(readline(
      paste0(
        "Store SEC_USER_AGENT in project .Renviron, user ~/.Renviron, or not at all? ",
        "[project/user/no] "
      )
    )))
    if (answer %in% c("p", "project")) {
      return("project")
    }
    if (answer %in% c("", "u", "user")) {
      return("user")
    }
    if (answer %in% c("n", "no", "none")) {
      return("none")
    }
    message("Enter 'project', 'user', or 'no'.")
  }
}
