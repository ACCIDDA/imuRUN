# Coerce a command-line flag value to a whole number

Coerce a command-line flag value to a whole number

## Usage

``` r
assert_flag_int(val, flag, min = 1L)
```

## Arguments

- val:

  the raw string value supplied after the flag.

- flag:

  the flag name (e.g. `"--iter"`), used in the error message.

- min:

  the smallest allowed value.

## Value

`val` as an integer no smaller than `min`.
