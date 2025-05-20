# README

Learning about the [{targets} R package](https://books.ropensci.org/targets/).

> Pipeline tools coordinate the pieces of computationally demanding analysis projects. The targets package is a Make-like pipeline tool for statistics and data science in R. The package skips costly runtime for tasks that are already up to date, orchestrates the necessary computation with implicit parallel computing, and abstracts files as R objects. If all the current output matches the current upstream code and data, then the whole pipeline is up to date, and the results are more trustworthy than otherwise.

## Getting started

See [Get started with the {targets} R package in four minutes ](https://github.com/wlandau/targets-four-minutes).

```console
mkdir demo && cd $_
mkdir R
wget -O R/functions.R https://raw.githubusercontent.com/wlandau/targets-four-minutes/refs/heads/main/R/functions.R
wget https://raw.githubusercontent.com/wlandau/targets-four-minutes/refs/heads/main/data.csv
wget https://raw.githubusercontent.com/wlandau/targets-four-minutes/refs/heads/main/_targets.R
```

In RStudio.

```r
setwd("/home/rstudio/work/demo/")
library(targets)

# tar_manifest() lists verbose information about each target.
tar_manifest(fields = all_of("command"))

# displays the dependency graph of the pipeline, showing a natural left-to-right flow of work.
tar_visnetwork()

# runs the pipeline
tar_make()
```
