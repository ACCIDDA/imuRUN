# Install imurun CLI to PATH

Creates a symlink to the bundled CLI script so `imurun` is available as
a shell command.

## Usage

``` r
install_cli(path = "~/.local/bin")
```

## Arguments

- path:

  character; directory to install the symlink into. Defaults to
  `"~/.local/bin"`.

## Value

Invisible `TRUE` on success, errors on failure.

## Examples

``` r
if (FALSE) { # \dontrun{
install_cli()                 # installs to ~/.local/bin
install_cli("~/bin")          # installs to a directory of your choice
} # }
```
