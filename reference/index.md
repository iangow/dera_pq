# Package index

## Source file metadata

Functions for listing SEC DERA source files and their Last-Modified
metadata.

- [`available_dera()`](https://iangow.github.io/dera_pq/reference/available_dera.md)
  : List SEC DERA Financial Statement Data Set source files
- [`available_dera_notes()`](https://iangow.github.io/dera_pq/reference/available_dera_notes.md)
  : List SEC DERA Financial Statement and Notes source files
- [`available_dera_files()`](https://iangow.github.io/dera_pq/reference/available_dera_files.md)
  : List SEC DERA zip files available for download

## Update Parquet repositories

High-level functions that update all current SEC DERA source files.

- [`update_dera()`](https://iangow.github.io/dera_pq/reference/update_dera.md)
  : Update SEC DERA Financial Statement Data Set Parquet files
- [`update_dera_notes()`](https://iangow.github.io/dera_pq/reference/update_dera_notes.md)
  : Update SEC DERA Financial Statement and Notes Parquet files

## Update one source file

Lower-level functions used by the repository updaters.

- [`update_dera_file()`](https://iangow.github.io/dera_pq/reference/update_dera_file.md)
  : Update one SEC DERA Financial Statement Data Set source file
- [`update_dera_notes_file()`](https://iangow.github.io/dera_pq/reference/update_dera_notes_file.md)
  : Update one SEC DERA Financial Statement and Notes source file

## Configuration and metadata

- [`dera_data_dir()`](https://iangow.github.io/dera_pq/reference/dera_data_dir.md)
  : Resolve the Parquet data repository directory
- [`dera_user_agent()`](https://iangow.github.io/dera_pq/reference/dera_user_agent.md)
  : Resolve the SEC user agent
- [`dera_set_user_agent()`](https://iangow.github.io/dera_pq/reference/dera_set_user_agent.md)
  : Store the SEC user agent for this session and optionally future
  sessions
- [`dera_file_metadata()`](https://iangow.github.io/dera_pq/reference/dera_file_metadata.md)
  : Read DERA metadata embedded in a Parquet file
