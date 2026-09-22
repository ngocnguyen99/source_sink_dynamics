# Figure 3: Percentage relative to GPP and trends in plant carbon fluxes and pools.
# Citation: Nguyen et al. (2026). Long-term biomass growth unimpeded by short-term photosynthetic decoupling. https://www.nature.com/articles/s41477-026-02418-1
# Run: Rscript code/Figure3_code.R (from the repository root).
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
paths <- setup_analysis("Figure3", script_dir, c("dplyr", "ggplot2", "purrr", "tibble", "tidyr"))

# 2. Parameters ----------------------------------------------------------------
MODEL_LIST <- c("ISBA-CTRIP", "CABLE-POP", "CLM5.0", "LPX-Bern", "ORCHIDEE", "ORCHIDEEv3", "CLASSIC-N", "CLASSIC")
SCENARIO <- "S1"
YEAR_START <- 1950
VARIABLES <- c("gpp", "ra", "cWood", "cLeaf", "cRoot")
POOL_VARIABLES <- c("cWood", "cLeaf", "cRoot")

# 3. Analysis helpers ----------------------------------------------------------
percent_increase <- function(values) {
  if (length(values) < 3L) {
    return(c(change = NA_real_, significant = NA_real_))
  }
  fit <- lm(values ~ seq_along(values))
  predicted <- fitted(fit)
  if (predicted[1] == 0) {
    return(c(change = NA_real_, significant = NA_real_))
  }
  c(
    change = unname((tail(predicted, 1) / predicted[1] - 1) * 100),
    significant = as.numeric(summary(fit)$coefficients[2, 4] < 0.05)
  )
}

process_model <- function(model) {
  message("Processing ", model, " ", SCENARIO)
  # Read and filter each variable once, then reuse it for both panels.
  inputs <- set_names(map(VARIABLES, function(variable) {
    data <- read_trendy(paths, model, SCENARIO, variable) %>%
      filter(!is.na(.data[[variable]]), .data[[variable]] != 0, year > YEAR_START)
    if (model == "CLM5.0") data <- filter(data, year < 2020)
    data
  }), VARIABLES)

  increments <- imap(inputs, function(data, variable) {
    if (variable %in% POOL_VARIABLES) {
      add_increment(data, variable, paste0(variable, "_increment"))
    } else {
      data
    }
  })
  means <- reduce(increments, full_join, by = c("year", "lat", "lon")) %>%
    group_by(lat, lon) %>%
    summarise(across(everything(), ~ mean(.x, na.rm = TRUE)), .groups = "drop") %>%
    filter(
      !is.na(ra), !is.na(gpp), !is.na(cWood_increment),
      !is.na(cLeaf_increment), !is.na(cRoot_increment)
    )
  require_rows(means, paste(model, "Figure 3a inputs"))
  allocation <- means %>% transmute(
    lat, lon,
    ra = ra / gpp * 100,
    cWood = cWood_increment / SECONDS_PER_YEAR / gpp * 100,
    cLeaf = cLeaf_increment / SECONDS_PER_YEAR / gpp * 100,
    cRoot = cRoot_increment / SECONDS_PER_YEAR / gpp * 100,
    model = model
  )

  changes <- imap(inputs, function(data, variable) {
    data %>%
      arrange(lat, lon, year) %>%
      group_by(lat, lon) %>%
      summarise(result = list(percent_increase(.data[[variable]])), .groups = "drop") %>%
      mutate(
        !!variable := map_dbl(result, "change"),
        !!paste0("p_", variable) := map_dbl(result, "significant")
      ) %>%
      select(-result)
  }) %>%
    reduce(full_join, by = c("lat", "lon")) %>%
    select(lat, lon, all_of(VARIABLES), all_of(paste0("p_", VARIABLES))) %>%
    mutate(model = model)

  write_dataset(allocation, paths, paste0("Figure3a_", model, "_", SCENARIO, ".csv"))
  write_dataset(changes, paths, paste0("Figure3b_", model, "_", SCENARIO, ".csv"))
  list(allocation = allocation, changes = changes)
}

# 4. Process inputs ------------------------------------------------------------
model_results <- map(MODEL_LIST, process_model)
all_model_data <- map_dfr(model_results, "allocation")
df_long <- all_model_data %>%
  pivot_longer(cols = c(ra, cWood, cLeaf, cRoot), names_to = "variable", values_to = "value") %>%
  mutate(variable = factor(variable, levels = c("ra", "cWood", "cLeaf", "cRoot")))
df_clean <- map_dfr(model_results, "changes") %>%
  select(all_of(VARIABLES), model) %>%
  na.omit() %>%
  pivot_longer(cols = all_of(VARIABLES), names_to = "variable", values_to = "value")
write_dataset(df_long, paths, "Figure3a_alldata.csv")
write_dataset(df_clean, paths, "Figure3b_alldata.csv")

# 5. Plot and export -----------------------------------------------------------
p3 <- ggplot(df_long, aes(x = variable, y = value)) +
  geom_boxplot(outlier.shape = NA, width = 0.6) +
  geom_jitter(alpha = 0.8, color = "gray50", fill = "gray50") +
  scale_x_discrete(
    labels = c(
      ra = expression(italic(R)[a])
    )
  ) +
  theme_bw() +
  theme(
    panel.grid = element_blank(),
    axis.text.y = element_text(size = 12),
    axis.text.x = element_text(size = 12),
    axis.title.y = element_text(size = 12),
    axis.title.x = element_text(size = 12)
  ) +
  labs(
    x = NULL,
    y = "Relative to GPP (%)"
  )

ggsave(file.path(paths$figures, "Figure3a.png"), p3, width = 4, height = 4, dpi = 1200)

df <- df_clean
df$variable <- factor(df$variable, levels = unique(df$variable))

ylims <- df %>%
  group_by(variable) %>%
  summarise(ymin = boxplot.stats(value)$stats[1], ymax = boxplot.stats(value)$stats[5]) %>%
  summarise(ymin = min(ymin), ymax = max(ymax))

p <- ggplot(df, aes(x = variable, y = value)) +
  geom_boxplot(width = 0.6, outlier.shape = NA) +
  stat_summary(fun = mean, geom = "point", shape = 23, size = 1.5) +
  scale_x_discrete(labels = c("ra" = expression(italic(R)[a]), "gpp" = "GPP")) +
  labs(x = NULL, y = "Increases from 1951-2020 (%)") +
  theme_classic() +
  theme(axis.text.x = element_text(size = 14, hjust = 0.5), axis.text.y = element_text(size = 14), axis.title.y = element_text(size = 16)) +
  coord_cartesian(ylim = c(ylims$ymin, ylims$ymax))

ggsave(file.path(paths$figures, "Figure3b.png"), p, width = 5.5, height = 5, dpi = 300)
record_session(paths, "Figure3")
