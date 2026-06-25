#' @title Install imurun CLI to PATH
#'
#' @description Creates a symlink to the bundled CLI script so \code{imurun} is
#' available as a shell command.
#'
#' @param path character; directory to install the symlink into.
#'   Defaults to \code{"~/.local/bin"}.
#'
#' @return Invisible \code{TRUE} on success, errors on failure.
#'
#' @examples
#' \dontrun{
#' install_cli()                 # installs to ~/.local/bin
#' install_cli("~/bin")          # installs to a directory of your choice
#' }
#'
#' @export
install_cli <- function(path = "~/.local/bin") {
  if (.Platform$OS.type == "windows") {
    stop("install_cli() is not supported on Windows.", call. = FALSE)
  }

  script <- system.file("scripts", "imurun.R", package = "imurun")
  if (!nzchar(script)) {
    stop("Cannot find bundled CLI script. Is imurun installed?", call. = FALSE)
  }

  path <- normalizePath(path, mustWork = FALSE)
  if (!dir.exists(path)) {
    stop("Directory does not exist: ", path, call. = FALSE)
  }

  link <- file.path(path, "imurun")

  if (interactive()) {
    ans <- readline(paste0("Install symlink at ", link, "? [Y/n] "))
    if (!tolower(ans) %in% c("", "y", "yes")) {
      message("Aborted.")
      return(invisible(FALSE))
    }
  }

  unlink(link)
  ok <- file.symlink(script, link)
  if (!ok) {
    stop("Failed to create symlink at ", link, call. = FALSE)
  }
  message("Installed: ", link, " -> ", script)
  message("Ensure ", path, " is on your PATH.")
  invisible(TRUE)
}
