#!/usr/bin/env Rscript

# Thin CLI wrapper for imurun.
#
# This script does no model logic of its own: it parses arguments, ensures the
# imuRUN package is available, and delegates to imuRUN::cli_run_fit(). All loading,
# validation, and fitting lives in the exported package functions so it can be
# tested and reused from R directly.
#
# Usage: imurun <input_dir> [output_dir]
#        imurun -h <input_dir>          (validate only, no model fitting)
#        imurun -h | --help             (show this message)
#
# Exit codes: 0=success, 1=validation, 2=model (reserved), 3=I/O.

# --- Package guard -----------------------------------------------------------

if (!requireNamespace("imuRUN", quietly = TRUE)) {
  stop(
    "Package 'imuRUN' required. Install with: remotes::install_github(\"ACCIDDA/imuRUN\")"
  )
}

# --- Entry guard -------------------------------------------------------------

if (!interactive()) {
  status <- imuRUN::cli_run_fit(commandArgs(trailingOnly = TRUE))
  quit(status = status, save = "no")
}
