# Find and read a named input from a directory

Looks for a named input (e.g. `"observations"`) in a directory, trying
each supported extension in precedence order (CSV before RDS), and reads
the first match with
[`load_by_ext()`](https://accidda.github.io/imurun/reference/load_by_ext.md).
Errors with a clear message if no matching file is found.

## Usage

``` r
find_input_file(dir, name)
```

## Arguments

- dir:

  character; directory to look in.

- name:

  character; the input base name, without extension.

## Value

The object read from the matching file.

## Examples

``` r
dir <- tempfile("imurun_find_")
dir.create(dir)
write.csv(data.frame(positive = 1:3, sample_n = 10:12),
          file.path(dir, "observations.csv"), row.names = FALSE)
find_input_file(dir, "observations")
#>   positive sample_n
#> 1        1       10
#> 2        2       11
#> 3        3       12
```
