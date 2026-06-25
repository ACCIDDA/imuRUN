# Does an input exist under any supported extension?

Tests whether a named input (e.g. `"observations"`) exists in a
directory under any of the
[SUPPORTED_EXT](https://accidda.github.io/imurun/reference/SUPPORTED_EXT.md)
extensions.

## Usage

``` r
file_exists_any_ext(dir, name)
```

## Arguments

- dir:

  character; directory to look in.

- name:

  character; the input base name, without extension.

## Value

Logical scalar; `TRUE` if a matching file exists.
