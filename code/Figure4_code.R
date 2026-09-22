# Figure 4: Long-term changes in the percentage of net woody C biomass growth relative to GPP
# Citation: Nguyen et al. (2026). Long-term biomass growth unimpeded by short-term photosynthetic decoupling. https://www.nature.com/articles/s41477-026-02418-1
# Run: Rscript code/Figure4_code.R (from the repository root).
# See README.md for inputs, methods, outputs, and environment setup.

# 1. Setup ---------------------------------------------------------------------
# Locate common.R for Rscript, source(), or interactive use from root/code.
script_dir <- local({
  source_files <- Filter(Negate(is.null), lapply(sys.frames(), function(frame) frame$ofile))
  args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  script <- if (length(source_files)) tail(source_files, 1)[[1]] else if (length(args)) sub("^--file=", "", args[1]) else NULL
  if (!is.null(script)) dirname(normalizePath(script)) else if (file.exists("code/common.R")) normalizePath("code") else normalizePath(".")
})
source(file.path(script_dir, "common.R"))
paths <- setup_analysis("Figure4", script_dir, c("dplyr", "ggplot2", "purrr", "tibble", "patchwork"))

# 2. Parameters ----------------------------------------------------------------
MODEL_LIST <- c("ISBA-CTRIP", "CABLE-POP", "CLM5.0", "LPJ-GUESS", "LPX-Bern", "ORCHIDEE",  "ORCHIDEEv3", "CLASSIC-N", "CLASSIC")
YEAR_START <- 1900
OUTLIER_SD_THRESHOLD <- 3
CONFIDENCE_LEVEL <- 0.95

# 3. Analysis helpers ----------------------------------------------------------
# Function to calculate confidence intervals
calculate_ci <- function(data, variable, confidence = CONFIDENCE_LEVEL) {
  z_score <- qnorm((1 + confidence) / 2)

  data %>%
    group_by(year) %>%
    summarise(
      mean_val = mean(.data[[variable]], na.rm = TRUE),
      se_val = sd(.data[[variable]], na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    ) %>%
    mutate(
      ci_lower = mean_val - z_score * se_val,
      ci_upper = mean_val + z_score * se_val
    )
}

# Function to fit linear model and extract slope statistics
extract_slope_stats <- function(data, y_var, x_var = "year") {
  fit <- lm(reformulate(x_var, y_var), data = data)
  slope_summary <- summary(fit)$coefficients

  list(
    slope = unname(coef(fit)[x_var]),
    se = slope_summary[x_var, "Std. Error"],
    p_value = slope_summary[x_var, "Pr(>|t|)"]
  )
}

# Prepare fluxes for the figure and its site list.
# Filter before computing lag so the first retained year has no increment.
prepare_flux_data <- function(gpp_data, cwood_data, year_start) {
  gpp_filtered <- gpp_data %>%
    filter(!is.na(gpp), year > year_start)
  cwood_filtered <- cwood_data %>%
    filter(!is.na(cWood), year > year_start) %>%
    add_increment("cWood", "cwood_increment", SECONDS_PER_YEAR)

  inner_join(gpp_filtered, cwood_filtered, by = c("year", "lat", "lon")) %>%
    filter(!is.na(cwood_increment), cWood != 0)
}

# Process each model once, reading each scenario's input files only once.
process_model_data <- function(model_name) {
  message("Processing ", model_name)
  scenarios <- c("S0", "S1", "S2")

  scenario_data <- set_names(map(scenarios, function(scenario) {
    gpp_data <- read_trendy(paths, model_name, scenario, "gpp")
    cwood_data <- read_trendy(paths, model_name, scenario, "cWood")

    # Keep the figure's existing time period and increment-outlier filtering.
    clean_data <- prepare_flux_data(gpp_data, cwood_data, YEAR_START) %>%
      remove_outliers("cwood_increment", OUTLIER_SD_THRESHOLD) %>%
      mutate(cwood_gpp_ratio = cwood_increment / gpp * 100)
    require_rows(clean_data, paste(model_name, scenario, "Figure 4 inputs"))
    ci_data <- calculate_ci(clean_data, "cwood_gpp_ratio")
    names(ci_data) <- paste0(names(ci_data), "_", scenario)
    names(ci_data)[1] <- "year"

    list(
      ci = ci_data,
      coords = distinct(clean_data, lat, lon)
    )
  }), scenarios)

  # Match the original Figure 4 site list: unique S2 locations with observations
  # retained after per-site, per-scenario 3-SD filtering of wood increments.
  # Outlying years are removed
  sample_coords <- scenario_data$S2$coords
  write_dataset(
    sample_coords, paths,
    paste0(model_name, "_selected_sites_TRENDYv10_3sd_filtered.csv")
  )

  combined_data <- map(scenario_data, "ci") %>%
    reduce(full_join, by = "year") %>%
    mutate(model = model_name)
  write_dataset(combined_data, paths, paste0("Figure4_", model_name, ".csv"))

  list(data = combined_data, sample_n = nrow(sample_coords))
}

# 4. Process inputs ------------------------------------------------------------
message("Processing data for all models...")
model_results <- set_names(map(MODEL_LIST, process_model_data), MODEL_LIST)
all_model_data <- map(model_results, "data")
sample_num <- tibble(
  model_name = MODEL_LIST,
  sample_n = map_int(model_results, "sample_n")
)

# 5. Plot and export -----------------------------------------------------------
plot_columns <- min(3L, length(MODEL_LIST))
plot_rows <- ceiling(length(MODEL_LIST) / plot_columns)
# Common colors
scenario_cols <- c(S1 = "#3c5488", S0 = "black", S2 = "#00a087")

create_model_plot <- function(df, this_model, idx) {
  # Determine position
  row <- ceiling(idx / plot_columns)
  col <- ((idx - 1) %% plot_columns) + 1

  # Sample size & subtitle
  sample_n_val <- sample_num %>%
    filter(model_name == this_model) %>%
    pull(sample_n)

  subtitle_text <- map_chr(c("S0", "S1", "S2"), ~ {
    stats <- extract_slope_stats(df, paste0("mean_val_", .x))
    slope_rounded <- round(stats$slope, 3)
    slope_display <- ifelse(slope_rounded == 0, "0", sprintf("%.3f", slope_rounded))
    sprintf("'%s: '*alpha*'=%s%s'", .x, slope_display, significance_label(stats$p_value))
  }) %>% paste(collapse = "*'; '*")

  y_max <- max(
    df$ci_upper_S0,
    df$ci_upper_S1,
    df$ci_upper_S2,
    na.rm = TRUE
  )

  p <- ggplot(df, aes(x = year)) +
    geom_ribbon(aes(ymin = ci_lower_S0, ymax = ci_upper_S0, fill = "S0"), alpha = .2) +
    geom_line(aes(y = mean_val_S0, colour = "S0"), linewidth = .8) +
    geom_ribbon(aes(ymin = ci_lower_S1, ymax = ci_upper_S1, fill = "S1"), alpha = .2) +
    geom_line(aes(y = mean_val_S1, colour = "S1"), linewidth = .8) +
    geom_ribbon(aes(ymin = ci_lower_S2, ymax = ci_upper_S2, fill = "S2"), alpha = .2) +
    geom_line(aes(y = mean_val_S2, colour = "S2"), linewidth = .8) +
    annotate("text",
      x = YEAR_START,
      y = y_max * 1.5,
      label = paste0(this_model, " (n=", sample_n_val, ")"),
      hjust = 0, vjust = 1, size = 4.2
    ) +
    annotate("text",
      x = YEAR_START,
      y = y_max * 1.2,
      label = subtitle_text, parse = TRUE,
      hjust = 0, vjust = 1, size = 3.5
    ) +
    scale_colour_manual(values = scenario_cols) +
    scale_fill_manual(values = scenario_cols) +
    labs(colour = "Scenario", fill = "Scenario") +
    coord_cartesian(xlim = c(YEAR_START, max(df$year))) +
    theme_bw() +
    theme(
      panel.grid = element_blank(),
      plot.subtitle = element_text(size = 15),
      axis.text.y = element_text(size = 15),
      axis.text.x = element_text(size = 15),
      axis.title.y = element_text(size = 15),
      axis.title.x = element_text(size = 15),
      legend.title = element_text(size = 15),
      legend.text = element_text(size = 15),
      legend.key.size = unit(1.2, "cm")
    ) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "red")


  # Keep the y-axis title in the first column.
  if (col == 1) {
    p <- p + ylab(expression(Delta * cWood / GPP ~ "(%)")) + xlab("Year")
  } else {
    p <- p + theme(axis.title.y = element_blank())
  }


  # Keep x-axis labels on the bottom row for any number of selected models.
  if (row == plot_rows) {
    p <- p + xlab("Year")
  } else {
    p <- p + theme(
      axis.title.x = element_blank(),
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank()
    )
  }

  return(p)
}

# Build plots with index
model_plots <- map2(
  all_model_data, seq_along(all_model_data),
  ~ create_model_plot(.x, names(all_model_data)[.y], .y)
)

# Combine with single legend and add panel labels a, b, c, …
combined_plot <- wrap_plots(model_plots, ncol = plot_columns, guides = "collect") +
  plot_annotation(tag_levels = "a") &
  theme(
    legend.position = "bottom",
    plot.tag = element_text(size = 14, face = "bold")
  )

ggsave(
  file.path(paths$figures, "Figure4.pdf"),
  combined_plot,
  width = 13, height = 8, units = "in"
)


write_dataset(bind_rows(all_model_data), paths, "Figure4_data.csv")
record_session(paths, "Figure4")
