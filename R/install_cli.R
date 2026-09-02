#' @title Install imurun CLI to PATH
#'
#' @description Installs the bundled CLI so `imurun` is available as a shell
#' command. On Unix-like systems this symlinks the script into `path`; on Windows
#' it writes an `imurun.cmd` shim that runs the script through `Rscript`
#' (Windows has neither shebangs nor user symlinks by default).
#'
#' @param path character; directory to install into. Defaults to
#'   `"~/.local/bin"`. The directory must already exist and be on your `PATH`.
#'
#' @return Invisible `TRUE` on success, errors on failure.
#'
#' @examples
#' \dontrun{
#' install_cli()                 # installs to ~/.local/bin
#' install_cli("~/bin")          # installs to a directory of your choice
#' }
#'
#' @export
install_cli <- function(path = "~/.local/bin") {
  script <- system.file("scripts", "imurun.R", package = "imuRUN")
  if (!nzchar(script)) {
    stop("Cannot find bundled CLI script. Is imuRUN installed?", call. = FALSE)
  }

  path <- normalizePath(path, mustWork = FALSE)
  if (!dir.exists(path)) {
    stop("Directory does not exist: ", path, call. = FALSE)
  }

  is_windows <- .Platform$OS.type == "windows"
  # Windows launchers must be a real command file (.cmd); Unix uses a bare
  # symlink whose target carries the `#!/usr/bin/env Rscript` shebang.
  target <- file.path(path, if (is_windows) "imurun.cmd" else "imurun")

  if (interactive()) {
    ans <- readline(paste0("Install imurun CLI at ", target, "? [Y/n] "))
    if (!tolower(ans) %in% c("", "y", "yes")) {
      message("Aborted.")
      return(invisible(FALSE))
    }
  }

  unlink(target)
  if (is_windows) {
    # A .cmd shim that invokes the script through this R's Rscript, forwarding
    # every argument (%*). Using the resolved Rscript path means the shim works
    # even when Rscript is not itself on PATH.
    rscript <- file.path(R.home("bin"), "Rscript")
    writeLines(
      c("@echo off", sprintf('"%s" "%s" %%*', rscript, script)),
      target
    )
    ok <- file.exists(target)
  } else {
    ok <- file.symlink(script, target)
  }
  if (!ok) {
    stop("Failed to install CLI at ", target, call. = FALSE)
  }

  message("Installed: ", target)
  message("Ensure ", path, " is on your PATH.")
  invisible(TRUE)
}
