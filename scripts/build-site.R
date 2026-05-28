#!/usr/bin/env Rscript

# Build pkgdown locally. This is the right entry point when articles use
# locally available SEC DERA data under DATA_DIR.
script_path <- commandArgs(FALSE)
script_path <- sub("^--file=", "", script_path[grepl("^--file=", script_path)][1])
pkg_dir <- if (!is.na(script_path)) {
  normalizePath(file.path(dirname(script_path), ".."))
} else {
  normalizePath(getwd())
}

pkgdown::build_site(
  pkg = pkg_dir,
  preview = FALSE,
  new_process = FALSE
)
