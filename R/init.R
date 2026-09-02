#' Locate the bundled blank template workbook
#'
#' @description Resolves the path to the blank `.xlsx` template shipped with
#' imurun (one sheet per input plus an instructions sheet), via
#' [base::system.file()].
#'
#' @return character; absolute path to `imurun_template.xlsx`, or `""` if the
#'   package is not installed.
#'
#' @examples
#' imurun_template()
#'
#' @export
imurun_template <- function() {
  system.file("templates", "imurun_template.xlsx", package = "imuRUN")
}

#' Locate the bundled filled example workbook
#'
#' @description Resolves the path to the small, realistic example `.xlsx`
#' workbook shipped with imuRUN (derived from 'imuGAP''s `*_sim` datasets), via
#' [base::system.file()].
#'
#' @return character; absolute path to `imurun_example.xlsx`, or `""` if the
#'   package is not installed.
#'
#' @examples
#' imurun_example()
#'
#' @export
imurun_example <- function() {
  system.file("extdata", "imurun_example.xlsx", package = "imuRUN")
}

#' Copy a bundled workbook into a target directory
#'
#' @param src character; path to the bundled workbook.
#' @param path character; destination directory.
#' @param name character; optional file name. If missing or without `.xlsx`
#'   extension, `.xlsx` is appended.
#' @param overwrite logical; overwrite an existing file?
#' @param label character; human label used in messages ("template"/"example").
#'
#' @return Invisibly, the resolved path to the copied file.
#'
#' @keywords internal
copy_bundled_workbook <- function(
  src,
  path = ".",
  name = NULL,
  overwrite = FALSE,
  label = "workbook"
) {
  if (!nzchar(src) || !file.exists(src)) {
    stop(
      "Cannot find the bundled ",
      label,
      ". Is imuRUN installed correctly?",
      call. = FALSE
    )
  }
  if (!dir.exists(path)) {
    ok <- dir.create(path, recursive = TRUE)
    if (!ok) {
      stop("Could not create directory: ", path, call. = FALSE)
    }
  }
  filename <- if (is.null(name) || !nzchar(trimws(name))) {
    basename(src)
  } else {
    fname <- trimws(name)
    if (!grepl("\\.xlsx$", fname, ignore.case = TRUE)) {
      paste0(fname, ".xlsx")
    } else {
      fname
    }
  }
  dest <- normalizePath(file.path(path, filename), mustWork = FALSE)
  if (file.exists(dest) && !overwrite) {
    stop(
      "File already exists: ",
      dest,
      "\nRe-run with overwrite = TRUE to replace it.",
      call. = FALSE
    )
  }
  ok <- file.copy(src, dest, overwrite = overwrite)
  if (!ok) {
    stop("Failed to copy ", label, " to ", dest, call. = FALSE)
  }
  invisible(dest)
}

#' Initialize an imurun input workbook
#'
#' @description Copies the bundled blank template workbook into a target
#' directory so users can fill in their own data. The template has one sheet per
#' input (`observations`, `locations`) with the exact required headers, plus an
#' `instructions` sheet.
#'
#' @param path character; destination directory (created if needed). Defaults to
#'   the current working directory (`"."`).
#' @param name character; destination file name (default `"imurun_template.xlsx"`).
#'   The `.xlsx` extension is optional and will be appended if omitted.
#' @param overwrite logical; if `FALSE` (the default) an existing workbook is
#'   not clobbered.
#'
#' @return Invisibly, the resolved path to the copied workbook.
#'
#' @examples
#' dir <- tempfile("imurun_init_")
#' imurun_init(dir)
#'
#' @export
imurun_init <- function(
  path = ".",
  name = "imurun_template.xlsx",
  overwrite = FALSE
) {
  dest <- copy_bundled_workbook(
    imurun_template(),
    path = path,
    name = name,
    overwrite = overwrite,
    label = "template"
  )
  message("Created: ", dest)
  message("Next steps:")
  message("  1. Open the workbook and fill the observations and locations")
  message("     sheets (see the instructions sheet).")
  message("  2. Validate it:  imuRUN::run_fit(\"", dest, "\", dryrun = TRUE)")
  message("  3. Fit it:       imuRUN::run_fit(\"", dest, "\")")
  invisible(dest)
}

#' Copy the bundled example workbook into a target directory
#'
#' @description Copies the small filled example workbook (derived from
#' 'imuGAP''s `*_sim` data) into a target directory, so users have a complete,
#' runnable input to learn from.
#'
#' @param path character; destination directory (created if needed). Defaults to
#'   the current working directory (`"."`).
#' @param name character; destination file name (default `"imurun_example.xlsx"`).
#'   The `.xlsx` extension is optional and will be appended if omitted.
#' @param overwrite logical; if `FALSE` (the default) an existing workbook is
#'   not clobbered.
#'
#' @return Invisibly, the resolved path to the copied workbook.
#'
#' @examples
#' dir <- tempfile("imurun_example_")
#' if (nzchar(imurun_example())) {
#'   imurun_copy_example(dir)
#' }
#'
#' @export
imurun_copy_example <- function(
  path = ".",
  name = "imurun_example.xlsx",
  overwrite = FALSE
) {
  dest <- copy_bundled_workbook(
    imurun_example(),
    path = path,
    name = name,
    overwrite = overwrite,
    label = "example"
  )
  message("Created: ", dest)
  message("Validate it with:  imuRUN::run_fit(\"", dest, "\", dryrun = TRUE)")
  invisible(dest)
}
