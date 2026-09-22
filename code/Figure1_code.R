# Figure 1: Short-term correlations between annual gross primary production (GPP) and annual woody carbon increment (∆cWood).
# Citation: Nguyen et al. (2026). Long-term biomass growth unimpeded by short-term photosynthetic decoupling. https://www.nature.com/articles/s41477-026-02418-1
# Run: Rscript code/Figure1_code.R (from the repository root).
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
paths <- setup_analysis("Figure1", script_dir, c("dplyr", "ggplot2", "purrr", "tibble", "tidyr", "patchwork"))

# 2. Parameters ----------------------------------------------------------------
MODEL_LIST <- c("ISBA-CTRIP", "CABLE-POP", "CLM5.0", "LPJ-GUESS", "LPX-Bern", "ORCHIDEE",  "ORCHIDEEv3", "CLASSIC-N", "CLASSIC")
SCENARIOS <- c("S0", "S1", "S2")
MIN_OBSERVATIONS <- 4L
OBS_QC_MIN <- 0.7

# 3. Analysis helpers ----------------------------------------------------------
process_model <- function(model, site_info) {
  coordinates <- read_input(
    file.path(paths$trendy, paste0(model, "_site_info.csv")),
    c("lat", "lon", "SITE_ID")
  ) %>%
    distinct(lat, lon, SITE_ID)
  map_dfr(SCENARIOS, function(scenario) {
    message("Processing ", model, " ", scenario)
    gpp <- read_trendy(paths, model, scenario, "gpp") %>% filter(!is.na(gpp))
    wood <- read_trendy(paths, model, scenario, "cWood") %>% filter(!is.na(cWood), cWood != 0)
    if (model == "CLM5.0") {
      gpp <- filter(gpp, year < 2020)
      wood <- filter(wood, year < 2020)
    }
    # Join GPP and wood, then compute increments.
    matched <- inner_join(gpp, wood, by = c("year", "lat", "lon")) %>%
      add_increment("cWood", "biomass_increment") %>%
      inner_join(coordinates, by = c("lat", "lon"), relationship = "many-to-many") %>%
      inner_join(site_info, by = "SITE_ID") %>%
      filter(year >= Start, year <= End)
    stats <- matched %>%
      group_by(lat, lon, SITE_ID) %>%
      summarise(
        n = n(),
        correlation = list(detrend_linear(biomass_increment, gpp, MIN_OBSERVATIONS)),
        .groups = "drop"
      ) %>%
      mutate(
        r_detrend_delta = map_dbl(correlation, "r"),
        p_detrend_delta = map_dbl(correlation, "p")
      ) %>%
      select(-correlation) %>%
      filter(!is.na(r_detrend_delta))
    require_rows(stats, paste(model, scenario, "correlations"))
    write_dataset(stats, paths, paste0("Figure1_", model, "_", scenario, ".csv"))
    mutate(stats, model = model, scenario = scenario)
  })
}

observed_correlations <- function() {
  rings <- read_input(file.path(paths$data, "rw_onsite.csv"), c("Year", "Site", "IDcrn", "RWI_dtrd"))
  flux <- read_input(file.path(paths$data, "flux_onsite.csv"), c("Year", "Site", "QC", "GPP_dtrd"))
  annual <- aggregate(GPP_dtrd ~ Year + Site, data = subset(flux, QC > OBS_QC_MIN), FUN = mean)
  paired <- inner_join(rings, annual, by = c("Year", "Site")) %>% na.omit()
  by_series <- paired %>%
    group_by(IDcrn) %>%
    summarise(
      correlation = list(tryCatch(
        {
          result <- cor.test(GPP_dtrd, RWI_dtrd, method = "pearson")
          c(r = unname(result$estimate), p = result$p.value)
        },
        error = function(error) c(r = NA_real_, p = NA_real_)
      )),
      .groups = "drop"
    ) %>%
    mutate(
      SITE_ID = substr(IDcrn, 1, 6),
      r_detrend_delta = map_dbl(correlation, "r"),
      p_detrend_delta = map_dbl(correlation, "p")
    ) %>%
    filter(!is.na(r_detrend_delta))
  by_series %>%
    group_by(SITE_ID) %>%
    summarise(across(c(r_detrend_delta, p_detrend_delta), mean), .groups = "drop")
}

# 4. Process inputs ------------------------------------------------------------
site_info <- read_input(
  file.path(paths$data, "Cabonetal_site_info.csv"),
  c("Site", "Start", "End", "On.site.RW")
) %>%
  filter(On.site.RW == TRUE) %>%
  transmute(SITE_ID = Site, Start, End)
model_data <- map_dfr(MODEL_LIST, process_model, site_info = site_info)
observations <- observed_correlations()
plot_data <- map_dfr(MODEL_LIST, function(model) {
  simulated <- filter(model_data, .data$model == .env$model)
  observed <- observations %>%
    filter(SITE_ID %in% simulated$SITE_ID) %>%
    mutate(model = model, scenario = "obs")
  bind_rows(simulated, observed)
})
write_dataset(plot_data, paths, "Figure1_data.csv")

# 5. Plot and export -----------------------------------------------------------
plot_columns <- min(3L, length(MODEL_LIST))
plot_rows <- ceiling(length(MODEL_LIST) / plot_columns)
plots <- map(seq_along(MODEL_LIST), function(index) {
  model <- MODEL_LIST[index]
  data <- filter(plot_data, .data$model == .env$model)
  observed <- filter(data, scenario == "obs")
  p_values <- map_dbl(SCENARIOS, function(scenario) {
    paired_p_value(filter(data, .data$scenario == .env$scenario), observed)
  })
  labels <- tibble(
    scenario = c("obs", SCENARIOS),
    asterisk = significance_label(c(NA_real_, p_values))
  ) %>%
    left_join(data %>% group_by(scenario) %>%
      summarise(y_pos = 0.05 + max(r_detrend_delta), .groups = "drop"), by = "scenario")
  sample_n <- n_distinct(filter(data, scenario == "S2")$SITE_ID)
  plot <- ggplot(data, aes(scenario, r_detrend_delta)) +
    geom_boxplot(linewidth = 0.3, alpha = 0.5, outlier.shape = NA, color = "#3c5488", fill = "#3c5488") +
    geom_jitter(size = 0.3, alpha = 0.5, width = 0.15, color = "#3c5488") +
    geom_text(data = labels, aes(scenario, y_pos, label = asterisk), inherit.aes = FALSE, size = 3.5) +
    annotate("text",
      x = 0.6, y = -0.8, label = paste0(model, " (n = ", sample_n, ")"),
      hjust = 0, vjust = 1, size = 3.5
    ) +
    annotate("text", x = 0.7, y = 1.15, label = letters[index], size = 5) +
    ylim(-1, 1.2) +
    ylab(expression(r[Delta * italic(cWood) * "," ~ italic(GPP)])) +
    theme_bw() +
    theme(
      legend.position = "none", panel.grid = element_blank(),
      axis.text = element_text(size = 12), axis.title = element_text(size = 12)
    )
  if ((index - 1L) %% plot_columns != 0L) {
    plot <- plot + theme(axis.title.y = element_blank(), axis.text.y = element_blank())
  }
  if (ceiling(index / plot_columns) < plot_rows) {
    plot <- plot + theme(axis.title.x = element_blank(), axis.text.x = element_blank())
  }
  plot
})
combined_plot <- wrap_plots(plots, ncol = plot_columns)
ggsave(file.path(paths$figures, "Figure1.pdf"), combined_plot, width = 7, height = 6.5)
record_session(paths, "Figure1")
