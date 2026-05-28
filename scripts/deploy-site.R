#!/usr/bin/env Rscript

# Build pkgdown locally and publish the rendered static site to gh-pages.
# This avoids running large SEC downloads or data summaries on GitHub Actions.
script_path <- commandArgs(FALSE)
script_path <- sub("^--file=", "", script_path[grepl("^--file=", script_path)][1])
pkg_dir <- if (!is.na(script_path)) {
  normalizePath(file.path(dirname(script_path), ".."))
} else {
  normalizePath(getwd())
}

pkgdown::deploy_to_branch(
  pkg = pkg_dir,
  branch = "gh-pages",
  remote = "origin",
  clean = TRUE,
  github_pages = TRUE,
  new_process = FALSE
)
