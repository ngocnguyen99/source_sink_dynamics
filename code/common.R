# Shared setup, input validation, and statistical helpers for Figures 1–4.
# Source through a figure script; package installation is a separate setup step.
ANALYSIS_PACKAGES <- c("dplyr", "ggplot2", "ggrepel", "patchwork", "purrr", "tibble", "tidyr")
SECONDS_PER_YEAR <- 365 * 24 * 60 * 60

setup_analysis <- function(figure, script_dir, packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Missing R packages: ", paste(missing, collapse = ", "),
      ". Run Rscript install-r-packages.R from the repository root.",
      call. = FALSE
    )
  }
  if (packageVersion("dplyr") < "1.1.0") {
    stop("dplyr >= 1.1.0 is required. Run install-r-packages.R.", call. = FALSE)
  }
  invisible(lapply(packages, function(package) {
    suppressPackageStartupMessages(library(package, character.only = TRUE))
  }))
  root <- normalizePath(Sys.getenv("SOURCE_SINK_ROOT", unset = dirname(script_dir)),
    mustWork = TRUE
  )
  paths <- list(
    root = root,
    data = file.path(root, "data", "cabon"),
    trendy = file.path(root, "results", "TRENDYv10", "31_site_weighted"),
    datasets = file.path(root, "results", "datasets"),
    figures = file.path(root, "results", "figures")
  )
  for (path in paths[c("datasets", "figures")]) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  set.seed(1) # Reproducible jitter and label placement.
  message(figure, ": using ", root)
  paths
}

read_input <- function(path, required_columns) {
  if (!file.exists(path)) stop("Missing input: ", path, call. = FALSE)
  data <- read.csv(path)
  missing <- setdiff(required_columns, names(data))
  if (length(missing)) {
    stop("Missing columns in ", path, ": ", paste(missing, collapse = ", "), call. = FALSE)
  }
  data
}

read_trendy <- function(paths, model, scenario, variable) {
  path <- file.path(
    paths$trendy, model,
    paste0(variable, "_", scenario, "_31_site_weighted_yearly_mean.csv")
  )
  columns <- c("year", "lat", "lon", variable)
  data <- read_input(path, columns)[columns]
  if (!all(vapply(data, is.numeric, logical(1))) || anyNA(data[c("year", "lat", "lon")])) {
    stop("Expected numeric values and complete year/lat/lon keys in ", path, call. = FALSE)
  }
  if (anyDuplicated(data[c("year", "lat", "lon")])) {
    stop("Duplicate year/lat/lon rows in ", path, call. = FALSE)
  }
  data
}

write_dataset <- function(data, paths, filename) {
  write.csv(data, file.path(paths$datasets, filename), row.names = FALSE)
}

record_session <- function(paths, figure) {
  writeLines(
    capture.output(sessionInfo()),
    file.path(paths$datasets, paste0(figure, "_sessionInfo.txt"))
  )
}

require_rows <- function(data, context, minimum = 1L) {
  if (nrow(data) < minimum) {
    stop(context, ": fewer than ", minimum,
      " valid rows remain. Check inputs, units, zero values, and filtering parameters.",
      call. = FALSE
    )
  }
  invisible(data)
}

# Detrend paired finite observations against their original row positions.
# Complete data reproduce the original calculation. Residuals avoid recycling
# predictions against the unfiltered vectors when observations are missing.
detrend_linear <- function(x, y, min_n = 4L) {
  valid <- is.finite(x) & is.finite(y)
  if (sum(valid) < min_n) {
    return(c(r = NA_real_, p = NA_real_))
  }
  data <- data.frame(x = x[valid], y = y[valid], index = which(valid))
  x_residual <- residuals(lm(x ~ index, data))
  y_residual <- residuals(lm(y ~ index, data))
  if (sd(x_residual) == 0 || sd(y_residual) == 0) {
    return(c(r = NA_real_, p = NA_real_))
  }
  result <- cor.test(x_residual, y_residual, method = "pearson")
  c(r = unname(result$estimate), p = result$p.value)
}

significance_label <- function(p) {
  ifelse(is.na(p), "", ifelse(p < 0.001, "***", ifelse(p < 0.01, "**", ifelse(p < 0.05, "*", ""))))
}

add_increment <- function(data, variable, output, divisor = 1) {
  data %>%
    arrange(lat, lon, year) %>%
    group_by(lat, lon) %>%
    mutate(!!output := (.data[[variable]] - lag(.data[[variable]])) / divisor) %>%
    ungroup()
}

remove_outliers <- function(data, variable, threshold = 3) {
  data %>%
    group_by(lat, lon) %>%
    mutate(
      avg = mean(.data[[variable]], na.rm = TRUE),
      std = sd(.data[[variable]], na.rm = TRUE)
    ) %>%
    filter(
      .data[[variable]] >= avg - threshold * std,
      .data[[variable]] <= avg + threshold * std
    ) %>%
    ungroup() %>%
    select(-avg, -std)
}

# Pair by site ID, never by incidental CSV row order.
paired_p_value <- function(model_data, observations) {
  if (anyDuplicated(model_data$SITE_ID)) {
    stop("Multiple model coordinates for one SITE_ID; resolve the site mapping before a paired test.")
  }
  pairs <- inner_join(select(model_data, SITE_ID, r_detrend_delta),
    select(observations, SITE_ID, r_detrend_delta),
    by = "SITE_ID", suffix = c("_model", "_obs")
  )
  if (nrow(pairs) < 2L) {
    return(NA_real_)
  }
  tryCatch(t.test(pairs$r_detrend_delta_model, pairs$r_detrend_delta_obs,
    paired = TRUE
  )$p.value, error = function(error) NA_real_)
}

