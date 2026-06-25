# Check that all required inputs are present

Verifies that all three required imuGAP inputs (`observations`,
`populations`, `locations`) exist in a directory under some supported
extension. Reports every missing input at once rather than failing on
the first.

## Usage

``` r
check_all_inputs(dir)
```

## Arguments

- dir:

  character; directory to check.

## Value

Invisibly `NULL` on success; errors listing the missing inputs
otherwise.

## Examples

``` r
dir <- tempfile("imurun_check_")
dir.create(dir)
for (n in c("observations", "populations", "locations")) {
  write.csv(data.frame(a = 1), file.path(dir, paste0(n, ".csv")),
            row.names = FALSE)
}
check_all_inputs(dir)
```
