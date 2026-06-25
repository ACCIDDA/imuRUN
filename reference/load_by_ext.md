# Read a data file by its extension

Reads a single input file, dispatching on its extension. CSV is read
with [`utils::read.csv()`](https://rdrr.io/r/utils/read.table.html)
(strings as character); RDS with
[`base::readRDS()`](https://rdrr.io/r/base/readRDS.html). Unsupported
extensions and unreadable files raise an error that names the offending
file.

## Usage

``` r
load_by_ext(path)
```

## Arguments

- path:

  character; path to the file to read.

## Value

The object stored in the file (typically a `data.frame`).

## Examples

``` r
path <- tempfile(fileext = ".csv")
write.csv(data.frame(x = 1:3), path, row.names = FALSE)
load_by_ext(path)
#>   x
#> 1 1
#> 2 2
#> 3 3
```
