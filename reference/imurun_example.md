# Locate the bundled filled example workbook

Resolves the path to the small, realistic example `.xlsx` workbook
shipped with imurun (derived from 'imuGAP”s `*_sim` datasets), via
[`base::system.file()`](https://rdrr.io/r/base/system.file.html).

## Usage

``` r
imurun_example()
```

## Value

character; absolute path to `imurun_example.xlsx`, or `""` if the
package is not installed.

## Examples

``` r
imurun_example()
#> [1] "/tmp/RtmpaQDzck/temp_libpath18b66c20dba4/imurun/extdata/imurun_example.xlsx"
```
