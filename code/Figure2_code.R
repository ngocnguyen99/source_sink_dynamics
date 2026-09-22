# Figure 2: Relationship between β_(cWood,GPP) and r_(∆cWood,GPP).
# Citation: Nguyen et al. (2026). Long-term biomass growth unimpeded by short-term photosynthetic decoupling. https://www.nature.com/articles/s41477-026-02418-1
# Run: Rscript code/Figure2_code.R (from the repository root).
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
paths <- setup_analysis("Figure2", script_dir, c("dplyr", "ggplot2", "ggrepel", "purrr", "tibble"))

# 2. Parameters ----------------------------------------------------------------
MODEL_LIST <- c("ISBA-CTRIP", "CABLE-POP", "CLM5.0", "LPJ-GUESS", "LPX-Bern", "ORCHIDEE",  "ORCHIDEEv3", "CLASSIC-N", "CLASSIC")
SCENARIO <- "S1"
YEAR_START <- 1950
MIN_OBSERVATIONS <- 40L
BETA_LIMITS <- c(-5, 10)

# 3. Analysis helpers ----------------------------------------------------------
response_ratio <- function(data) {
  if (nrow(data) < 2L) {
    return(NA_real_)
  }
  gpp_fit <- fitted(lm(gpp ~ year, data))
  wood_fit <- fitted(lm(cWood ~ year, data))
  endpoints <- c(gpp_fit[1], tail(gpp_fit, 1), wood_fit[1], tail(wood_fit, 1))
  if (any(!is.finite(endpoints)) || any(endpoints <= 0)) {
    return(NA_real_)
  }
  denominator <- log(tail(wood_fit, 1) / wood_fit[1])
  if (denominator == 0) {
    return(NA_real_)
  }
  
  log(tail(gpp_fit, 1) / gpp_fit[1]) / denominator
}

process_model <- function(model) {
  message("Processing ", model, " ", SCENARIO)
  gpp <- read_trendy(paths, model, SCENARIO, "gpp") %>%
    filter(!is.na(gpp), gpp != 0, year > YEAR_START)
  wood <- read_trendy(paths, model, SCENARIO, "cWood") %>%
    filter(!is.na(cWood), cWood != 0, year > YEAR_START)
  if (model == "CLM5.0") gpp <- filter(gpp, year < 2020)
  joined <- inner_join(gpp, wood, by = c("year", "lat", "lon")) %>%
    mutate(gpp = gpp * 1000) %>%
    add_increment("cWood", "biomass_increment") %>%
    filter(!is.na(biomass_increment), !is.na(gpp))
  require_rows(joined, paste(model, "Figure 2 inputs"))
  joined %>%
    group_by(lat, lon) %>%
    group_modify(~ tibble(
      r_detrend_delta = detrend_linear(.x$biomass_increment, .x$gpp, MIN_OBSERVATIONS)[["r"]],
      beta = response_ratio(.x)
    )) %>%
    ungroup() %>%
    filter(is.finite(r_detrend_delta), is.finite(beta)) %>%
    mutate(model = model) %>%
    select(lat, lon, model, r_detrend_delta, beta)
}

# 4. Process inputs ------------------------------------------------------------
merged_beta_df <- map_dfr(MODEL_LIST, process_model)
beta_df_sub <- filter(merged_beta_df, beta >= BETA_LIMITS[1], beta <= BETA_LIMITS[2])
require_rows(beta_df_sub, "Figure 2 regression", minimum = 3L)
write_dataset(beta_df_sub, paths, "Figure2_alldata.csv")

# 5. Plot and export -----------------------------------------------------------
fit <- lm(beta ~ r_detrend_delta, data = beta_df_sub)

slope <- coef(summary(fit))["r_detrend_delta", "Estimate"]
p_value <- coef(summary(fit))["r_detrend_delta", "Pr(>|t|)"]

label_text <- paste0(
  "Slope = ", round(slope, 3), ", ",
  "P = ", signif(p_value, 3), ", ",
  "n = ", nrow(beta_df_sub)
)

summary_df <- beta_df_sub %>%
  group_by(model) %>%
  summarise(
    yQ1 = quantile(beta, 0.25),
    yQ2 = quantile(beta, 0.5),
    yQ3 = quantile(beta, 0.75),
    xQ1 = quantile(r_detrend_delta, 0.25),
    xQ2 = quantile(r_detrend_delta, 0.5),
    xQ3 = quantile(r_detrend_delta, 0.75)
  )
# Plot + whiskers
p_local <- ggplot(summary_df, aes(x = xQ2, y = yQ2)) +
  geom_segment(aes(x = xQ1, xend = xQ3, y = yQ2, yend = yQ2), linewidth = 0.4, color = "gray50") +
  geom_segment(aes(x = xQ1, xend = xQ1, y = yQ2 - 0.03, yend = yQ2 + 0.03), linewidth = 0.4, color = "gray50") +
  geom_segment(aes(x = xQ3, xend = xQ3, y = yQ2 - 0.03, yend = yQ2 + 0.03), linewidth = 0.4, color = "gray50") +
  geom_segment(aes(x = xQ2, xend = xQ2, y = yQ1, yend = yQ3), linewidth = 0.4, color = "gray50", lineend = "square") +
  geom_segment(aes(x = xQ2 - 0.015, xend = xQ2 + 0.015, y = yQ1, yend = yQ1), linewidth = 0.4, color = "gray50") +
  geom_segment(aes(x = xQ2 - 0.015, xend = xQ2 + 0.015, y = yQ3, yend = yQ3), linewidth = 0.4, color = "gray50") +
  geom_point(size = 2, shape = 21, fill = "#00a087", color = "#00a087", alpha = 0.8) +
  geom_text_repel(
    aes(label = model),
    color = "#00a087",
    box.padding = 1.5,
    point.padding = 1,
    segment.color = NA,
    nudge_x = 0.17,
    nudge_y = 0.15,
    force = 10, size = 3.5
  ) +
  theme_bw() +
  theme(
    legend.key.size = unit(1, "cm"),
    axis.text.y = element_text(size = 12),
    axis.text.x = element_text(size = 12),
    axis.title.y = element_text(size = 12),
    axis.title.x = element_text(size = 12),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank()
  ) +
  labs(
    x = expression(r[Delta * italic(cWood) * "," ~ italic(GPP)]),
    y = expression(beta[italic(cWood) * "," ~ italic(GPP)])
  ) +
  annotate("text",
    x = -Inf,
    y = Inf,
    label = label_text,
    hjust = -0.65,
    vjust = 1.8,
    size = 4
  ) +
  xlim(0, 1.12)


ggsave(file.path(paths$figures, "Figure2.pdf"), p_local, width = 5, height = 5)
record_session(paths, "Figure2")
