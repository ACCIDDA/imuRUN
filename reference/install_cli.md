# Install imurun CLI to PATH

Installs the bundled CLI so `imurun` is available as a shell command. On
Unix-like systems this symlinks the script into `path`; on Windows it
writes an `imurun.cmd` shim that runs the script through `Rscript`
(Windows has neither shebangs nor user symlinks by default).

## Usage

``` r
install_cli(path = "~/.local/bin")
```

## Arguments

- path:

  character; directory to install into. Defaults to `"~/.local/bin"`.
  The directory must already exist and be on your `PATH`.

## Value

Invisible `TRUE` on success, errors on failure.

## Examples

``` r
if (FALSE) { # \dontrun{
install_cli()                 # installs to ~/.local/bin
install_cli("~/bin")          # installs to a directory of your choice
} # }
```
