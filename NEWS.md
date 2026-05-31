# dera.pq 0.0.1.9000 (2026-05-31)

## Bug fixes

* Interpret raw SEC `accepted` timestamps as `America/New_York` rather than UTC.
* Add a one-time repair script for legacy Parquet files written with the old
  `accepted` timestamp timezone assumption.
* Stop writing duplicate `sec_last_modified` Parquet metadata; `last_modified`
  and `last_modified_utc` are retained.

# dera.pq 0.0.0.9000 (2026-05-29)

## Initial version

* Add helpers to list available SEC DERA Financial Statement Data Sets and
  Financial Statement and Notes Data Sets.
* Add update helpers that download SEC source zip files and write component
  tables as Parquet files under a local `DATA_DIR` repository.
* Store SEC source metadata in Parquet schema metadata for update checks and
  auditability.
* Add configuration helpers for `SEC_USER_AGENT` and `DATA_DIR`.
