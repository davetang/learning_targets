# README

Learning about the [{targets} R package](https://books.ropensci.org/targets/).

## Table of contents

- [Introduction](#introduction)
- [Getting started](#getting-started)

## Introduction

If you've used Make, you already understand the core idea behind {targets}: declare the relationships between inputs and outputs, and the tool figures out what needs to be rebuilt when something changes. {targets} brings that same dependency-tracking philosophy to R data analysis pipelines.

Where Make operates on files and shell commands, {targets} operates on **R objects and R functions**. Each step in a pipeline (called a *target*) is defined by a name and an R expression. {targets} hashes the results and tracks dependencies between targets automatically, so re-running the pipeline only executes the targets that are out of date. Everything else is loaded from cache, just like Make skips up-to-date build artifacts.

The key differences from Make:

- **No Makefile syntax.** Pipelines are defined in plain R (`_targets.R`) using `tar_target()` calls. Dependencies are inferred from which R objects each function consumes, so there is no need to declare prerequisites manually.
- **Targets are R objects, not files.** Results are stored and retrieved as serialised R objects. You can track files too (with `format = "file"`), but the default unit of work is an in-memory R value.
- **Reproducibility is first-class.** {targets} records the state of code *and* data. If an upstream function body changes, all downstream targets are invalidated; Make only does this if you encode those relationships yourself.
- **Parallel execution is built in.** Where Make uses `-j`, {targets} integrates with the [{crew}](https://wlandau.github.io/crew/) package to dispatch targets across local workers or HPC clusters with no changes to the pipeline definition.

The mental model is the same as Make: a directed acyclic graph (DAG) of dependencies, skipping work that is already current. `tar_visnetwork()` renders that graph interactively so you can inspect it before running anything.

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
