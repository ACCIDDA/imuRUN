# Refuse to overwrite an existing output file

imurun writes next to a user's own inputs, so a second run must not
silently replace results they have not looked at yet. Errors when `path`
already exists unless `overwrite` is `TRUE`.

## Usage

``` r
assert_no_clobber(path, overwrite = FALSE)
```

## Arguments

- path:

  character; the file about to be written.

- overwrite:

  logical; `TRUE` to allow replacing an existing file.

## Value

Invisibly, `path`.
