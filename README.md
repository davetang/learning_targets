# README

Learning about the [{targets} R package](https://books.ropensci.org/targets/).

## Table of contents

- [Introduction](#introduction)
  - [When to use {targets}](#when-to-use-targets)
  - [Limitations](#limitations)
- [Getting started](#getting-started)
  - [Directory structure](#directory-structure)
  - [Setup](#setup)
- [FAQ](#faq)
- [Using {renv} with {targets}](#using-renv-with-targets)
- [Useful links](#useful-links)

## Introduction

If you've used Make, you already understand the core idea behind {targets}: declare the relationships between inputs and outputs, and the tool figures out what needs to be rebuilt when something changes. {targets} brings that same dependency-tracking philosophy to R data analysis pipelines.

Where Make operates on files and shell commands, {targets} operates on **R objects and R functions**. Each step in a pipeline (called a *target*) is defined by a name and an R expression. {targets} hashes the results and tracks dependencies between targets automatically, so re-running the pipeline only executes the targets that are out of date. Everything else is loaded from cache, just like Make skips up-to-date build artifacts.

The key differences from Make:

- **No Makefile syntax.** Pipelines are defined in plain R (`_targets.R`) using `tar_target()` calls. Dependencies are inferred from which R objects each function consumes, so there is no need to declare prerequisites manually.
- **Targets are R objects, not files.** Results are stored and retrieved as serialised R objects. You can track files too (with `format = "file"`), but the default unit of work is an in-memory R value.
- **Reproducibility is first-class.** {targets} records the state of code *and* data. If an upstream function body changes, all downstream targets are invalidated; Make only does this if you encode those relationships yourself.
- **Parallel execution is built in.** Where Make uses `-j`, {targets} integrates with the [{crew}](https://wlandau.github.io/crew/) package to dispatch targets across local workers or HPC clusters with no changes to the pipeline definition.

The mental model is the same as Make: a directed acyclic graph (DAG) of dependencies, skipping work that is already current. `tar_visnetwork()` renders that graph interactively so you can inspect it before running anything.

### When to use {targets}

{targets} pays off when at least some steps in your pipeline are slow enough that re-running them unnecessarily is painful. A good fit looks like: raw data that rarely changes, a sequence of cleaning, modelling, and reporting steps written as R functions, and a need to be confident that every output is consistent with the current code and data.

It is probably not worth adopting for short, single-script analyses that run in seconds, for exploratory work where the pipeline structure changes constantly, or for projects that are not primarily R.

### Limitations

- **R only.** The pipeline definition, all targets, and the framework itself must run in R. Non-R steps require workarounds (see [FAQ](#faq)).
- **Each target must be a function call, not inline code.** The `command` of a target must be a call to a named function; you cannot inline a block of R expressions the way you can inline shell commands in a Makefile recipe. In practice this means pulling your analysis code into functions defined in `R/`, but there is no requirement on how much or how little each function does.
- **Package functions are not tracked.** If a function comes from an installed package rather than your own code, {targets} will not detect when it changes. Updating a package silently invalidates assumptions without invalidating any targets.
- **Single machine by default.** Parallel execution across a cluster requires additional setup via {crew} and {crew.cluster}.
- **Persistent state can surprise you.** The `_targets/` cache reflects the last run, not the current state of your code. If you delete or rename a target, its old cached result lingers until you explicitly clean it with `tar_destroy()` or `tar_prune()`.

## Getting started

### Directory structure

{targets} expects a specific layout at the root of your project:

```
_targets.R        # pipeline definition; must be at the project root
R/                # your functions; loaded automatically by tar_source()
_targets/         # cache directory; created by {targets} on first run
```

`_targets.R` is the entry point - it defines the pipeline using `tar_target()` calls and calls `tar_source()` to load everything in `R/`. You do not create or manage the `_targets/` directory yourself; {targets} owns it.

There are no strict rules about what else goes in the project, but keeping raw data in `data/` and outputs such as reports in a separate directory is a common convention.

### Setup

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

## FAQ

**Can I use {targets} outside of R like Make?**

No. Unlike Make, which is a general-purpose build tool that can run any shell command, {targets} is R-only. The pipeline is defined in R, every target must return an R object, and the framework itself runs inside an R session. If your pipeline mixes R with other languages or tools, you would need to wrap the non-R steps in `system()` calls and track their outputs as file targets (with `format = "file"`), rather than running them natively as you would in a Makefile.

For language-agnostic pipeline tools with a similar dependency-tracking philosophy, consider [Snakemake](https://snakemake.readthedocs.io/) (Python-based) or Make itself.

---

**Does {targets} work with {reticulate}?**

Partially. You can call Python code from within a target using {reticulate} as you normally would in R, and {targets} will track changes to the R functions that wrap those calls. However, there is a fundamental serialization problem: Python objects (numpy arrays, pandas DataFrames, scikit-learn models, etc.) cannot be safely persisted across R sessions. When {targets} saves a target's result to disk and reloads it in a later session, any Python object inside it becomes a null pointer because the Python session it belonged to no longer exists.

The practical workaround is to convert Python objects to native R objects before returning them from a target, so that {targets} only ever stores R data:

```r
library(targets)
library(reticulate)

fit_python_model <- function(data) {
  sklearn <- import("sklearn.linear_model")
  model <- sklearn$LinearRegression()$fit(data$X, data$y)
  # extract coefficients as an R vector before returning
  list(
    coef = as.numeric(model$coef_),
    intercept = as.numeric(model$intercept_)
  )
}
```

If you need to persist a Python object itself rather than just its extracted values, write it to disk inside the target using pickle or `joblib`, return the file path, and use `format = "file"` so {targets} tracks it as a file dependency.

---

**Where does {targets} store its outputs?**

In a `_targets/` directory created in your project root. R objects are saved under `_targets/objects/` and pipeline metadata (hashes, timestamps, error messages) is kept in `_targets/meta/meta`. You do not need to reference these files directly; use `tar_read()` or `tar_load()` instead.

---

**How do I read a target's value after the pipeline has run?**

Use `tar_read(target_name)` to return the value, or `tar_load(target_name)` to load it into your global environment as a variable of the same name. Both work outside the pipeline, in an interactive R session.

```r
tar_read(model)   # returns the object
tar_load(model)   # loads `model` into your environment
```

---

**What causes a target to be re-run?**

{targets} considers a target outdated when any of the following change: the body of the function that produces it, the value of any upstream target it depends on, or the packages and global options declared in `tar_option_set()`. The check is hash-based, so only a genuine content change triggers a rebuild, not just a file timestamp (unlike Make by default).

Note that {targets} does not track functions that come from packages. If you update a package and one of its functions changes internally, targets that call it will not automatically be invalidated.

---

**How do I force a specific target to re-run?**

Mark it as outdated with `tar_invalidate()`, then call `tar_make()`:

```r
tar_invalidate(model)
tar_make()
```

To see which targets are already considered outdated before running, use `tar_outdated()`.

---

**How do I run only one target without running the whole pipeline?**

Pass its name to `tar_make()`:

```r
tar_make(names = "plot")
```

{targets} will also run any upstream targets that are outdated. If you want to check dependencies first, `tar_visnetwork()` will highlight what is current and what is not.

---

**How do I debug a failing target?**

The quickest approach is to run the pipeline in your current R session (rather than in a separate process) so that standard interactive debuggers work:

```r
tar_make(callr_function = NULL, use_crew = FALSE, as_job = FALSE)
```

You can then insert `browser()` into the offending function to pause execution and inspect the environment interactively.

If the target has already errored, {targets} saves a workspace file automatically. Load it with `tar_workspace(target_name)` to restore the exact environment the target had when it failed, including all its dependencies and the random seed.

To retrieve stored error messages without re-running anything:

```r
tar_meta(fields = error, complete_only = TRUE)
```

---

**Can a target produce a file instead of an R object?**

Yes. Set `format = "file"` in `tar_target()` and have the function return the file path as a string. {targets} will then track the file's contents by hash and invalidate the target if the file changes.

```r
tar_target(
  name = report,
  command = render_report("report.Rmd"),  # returns "report.html"
  format = "file"
)
```

---

**Can I use {targets} with R Markdown or Quarto?**

Yes, via the [{tarchetypes}](https://docs.ropensci.org/tarchetypes/) companion package, which provides `tar_render()` for R Markdown and `tar_quarto()` for Quarto. These treat a rendered document as a target, so it is only re-rendered when its inputs change.

---

**How do I run targets in parallel?**

Install the [{crew}](https://wlandau.github.io/crew/) package and pass a controller to `tar_option_set()` in `_targets.R`:

```r
tar_option_set(
  controller = crew::crew_controller_local(workers = 4)
)
```

{targets} will then distribute independent targets across workers automatically. No changes to individual `tar_target()` calls are needed. For HPC clusters, see the [{crew.cluster}](https://wlandau.github.io/crew.cluster/) package.

## Using {renv} with {targets}

{renv} and {targets} solve different reproducibility problems and work well alongside each other. {renv} locks the versions of every R package your project depends on. {targets} tracks whether your pipeline outputs are current with respect to your code and data. Together they cover both "which packages were used" and "which computations were run."

### Setup

Initialize {renv} from your project root (inside the container, with the working directory set to the project):

```r
renv::init()
```

{renv} will scan your R scripts - including `_targets.R` and everything in `R/` - and populate `renv.lock` with the packages it finds. Commit `renv.lock` to version control. Collaborators (or a fresh clone) can then restore the exact same package versions with:

```r
renv::restore()
```

After that, use {targets} as normal. The two tools operate at different layers and do not interfere.

### Excluding the targets cache from {renv}

{renv} scans project files for `library()` and `require()` calls to detect package usage. The `_targets/` cache directory contains serialised R objects that can confuse this scan. Add it to `.renvignore` so {renv} skips it:

```
_targets/
```

### Keeping the lockfile up to date

When you install or update a package, run `renv::snapshot()` to record the change in `renv.lock`. Updating `renv.lock` does not invalidate any targets - {targets} is unaware of package versions. If a package update changes the behaviour of a function you rely on, invalidate the affected targets manually with `tar_invalidate()` and re-run the pipeline.

### Useful links

- [{renv} documentation](https://rstudio.github.io/renv/)
- [Reproducibility chapter in the {targets} manual](https://books.ropensci.org/targets/reproducibility.html) - covers {renv} integration

## Useful links

- [The {targets} R package user manual](https://books.ropensci.org/targets/) - the authoritative reference, covering everything from basic walkthrough to distributed computing and dynamic branching
- [Function reference](https://docs.ropensci.org/targets/reference/) - documentation for every function in the package
- [GitHub repository](https://github.com/ropensci/targets) - source code, issue tracker, and discussion board
- [Get started in four minutes](https://github.com/wlandau/targets-four-minutes) - the minimal worked example this repo is based on
- [{tarchetypes}](https://docs.ropensci.org/tarchetypes/) - companion package providing higher-level helpers, including `tar_render()` for R Markdown and `tar_quarto()` for Quarto
- [{crew}](https://wlandau.github.io/crew/) - parallel worker controller that integrates with {targets}
- [{crew.cluster}](https://wlandau.github.io/crew.cluster/) - extends {crew} for HPC schedulers such as SGE, SLURM, and PBS
- [Carpentries workshop: Introduction to {targets}](https://carpentries-incubator.github.io/targets-workshop/) - lesson material aimed at researchers new to pipeline tools
