# =============================================================
# 03_figures.R
# Event-study figures for main results and robustness checks
# Author: Carla Morvan
# =============================================================

# --- 1. Packages ---------------------------------------------
library(readr)
library(ggplot2)
library(dplyr)
library(patchwork)
library(stringr)
library(purrr)

# --- 2. Paths ------------------------------------------------

results_path <- "results/"
figures_path <- "figures/"
dir.create(figures_path, recursive = TRUE, showWarnings = FALSE)

# --- 3. Utility functions ------------------------------------

# Prepare data from standard dCDMH output (...1 or label column)
prepare_data <- function(file_path) {
  df <- read_csv(file_path, show_col_types = FALSE)
  if("...1" %in% names(df)) df <- df %>% rename(label = `...1`)
  df %>%
    filter(str_detect(label, "Effect_|Placebo_")) %>%
    mutate(
      time = case_when(
        str_detect(label, "Placebo_1") ~ -3,
        str_detect(label, "Placebo_2") ~ -2,
        str_detect(label, "Placebo_3") ~ -1,
        str_detect(label, "Effect_")   ~ as.numeric(str_extract(label, "[0-9]+"))
      ),
      periode = ifelse(time < 0, "Negatif", "Positif")
    )
}

# Event-study plot with fixed y-axis (main results)
create_plot <- function(data, subtitle_text, ylim = c(-0.055, 0.055)) {
  ggplot(data, aes(x = time, y = Estimate)) +
    geom_point(aes(color = periode), size = 2) +
    geom_errorbar(aes(ymin = `LB CI`, ymax = `UB CI`, color = periode),
                  width = 0.1) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray") +
    scale_color_manual(values = c("lightblue", "darkblue")) +
    scale_x_continuous(limits = c(-3, 8.5), breaks = seq(-3, 8, 1)) +
    coord_cartesian(ylim = ylim) +
    labs(x = "Time", y = "Estimate and 95% Conf. Int.",
         title = "", subtitle = subtitle_text) +
    theme(panel.background = element_rect(fill = "white"),
          axis.line        = element_line(colour = "black"),
          legend.position  = "none",
          legend.title     = element_blank())
}

# Event-study plot with free y-axis (robustness)
create_plot_free <- function(data, subtitle_text) {
  ggplot(data, aes(x = time, y = Estimate)) +
    geom_point(aes(color = periode), size = 2) +
    geom_errorbar(aes(ymin = `LB CI`, ymax = `UB CI`, color = periode),
                  width = 0.1) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray") +
    scale_color_manual(values = c("lightblue", "darkblue")) +
    scale_x_continuous(limits = c(-3, 8.5), breaks = seq(-3, 8, 1)) +
    labs(x = "Time", y = "Estimate and 95% Conf. Int.",
         title = "", subtitle = subtitle_text) +
    theme(panel.background  = element_rect(fill = "white"),
          axis.line         = element_line(colour = "black"),
          legend.position   = "none",
          legend.title      = element_blank(),
          axis.title.x      = element_text(size = 30),
          axis.title.y      = element_text(size = 30),
          axis.text.x       = element_text(size = 28),
          axis.text.y       = element_text(size = 28),
          plot.subtitle     = element_text(size = 30))
}

# Save figure helper
save_fig <- function(plot, filename, width = 10, height = 6) {
  ggsave(
    filename = paste0(figures_path, filename),
    plot     = plot,
    width    = width,
    height   = height,
    units    = "in",
    dpi      = 300
  )
  cat("Saved:", filename, "\n")
}

# =============================================================
# PART 1 : MAIN RESULTS
# =============================================================

# --- 1.1 Expenditures -----------------------------------------
p_invex <- create_plot(
  prepare_data(paste0(results_path, "/dCMDH_depinvN.csv")), "")
p_curex <- create_plot(
  prepare_data(paste0(results_path, "/dCMDH_depfN.csv")), "")

save_fig(p_invex, "figSPE1H_invex.pdf")
save_fig(p_curex, "figSPE1H_curex.pdf")

# --- 1.2 Financing --------------------------------------------
p_grant <- create_plot(
  prepare_data(paste0(results_path, "/dCMDH_grantN.csv")), "")
p_debt  <- create_plot(
  prepare_data(paste0(results_path, "/dCMDH_debtN.csv")), "")

save_fig(p_grant, "figSPE1H_grant.pdf")
save_fig(p_debt,  "figSPE1H_debt.pdf")

# --- 1.3 Property tax -----------------------------------------
p_taxfb   <- create_plot(
  prepare_data(paste0(results_path, "/dCMDH_taxN.csv")), "")
p_basefb  <- create_plot(
  prepare_data(paste0(results_path, "/dCMDH_basetaxN.csv")), "")

save_fig(p_taxfb,  "figSPE1H_taxfb.pdf")
save_fig(p_basefb, "figSPE1H_basefb.pdf")

# --- 1.4 Business tax -----------------------------------------
p_taxpro  <- create_plot(
  prepare_data(paste0(results_path, "/dCMDH_taxproN.csv")), "",
  ylim = c(-0.085, 0.085))
p_basepro <- create_plot(
  prepare_data(paste0(results_path, "/dCMDH_basetaxproN.csv")), "",
  ylim = c(-0.085, 0.085))

save_fig(p_taxpro,  "figSPE1H_taxpro.pdf")
save_fig(p_basepro, "figSPE1H_basepro.pdf")

# =============================================================
# PART 2 : HETEROGENEITY BY DISASTER FREQUENCY
# =============================================================
# --- 2.1 Heterogeneity by disaster frequency ---------
outcomes_nb <- list(
  list(prefix = "depinvN", filename = "invex"),
  list(prefix = "depfN",   filename = "curex"),
  list(prefix = "grantN",  filename = "grant"),
  list(prefix = "debtN",   filename = "debt")
)

walk(outcomes_nb, function(o) {
  p1 <- create_plot(
    prepare_data(paste0(results_path, "heterogeneity/nb_floods/dCMDH_",
                        o$prefix, "_1.csv")), "1st Flood",
    #ylim = c(-0.5, 0.5)
    )
  p2 <- create_plot(
    prepare_data(paste0(results_path, "heterogeneity/nb_floods/dCMDH_",
                        o$prefix, "_2.csv")), "2nd Flood",
   # ylim = c(-0.5, 0.5)
   )
  p3 <- create_plot(
    prepare_data(paste0(results_path, "heterogeneity/nb_floods/dCMDH_",
                        o$prefix, "_3.csv")), "3rd Flood",
   # ylim = c(-0.5, 0.5)
   )
  save_fig(p1 + p2 + p3,
           paste0("figNB_", o$filename, ".pdf"),
           width = 30, height = 6)
})


# --- 2.2 Heterogeneity by financial health (AFL) ---------
outcomes_rob <- list(
  list(prefix = "depinvN", filename = "invex"),
  list(prefix = "depfN",   filename = "curex"),
  list(prefix = "grantN",  filename = "grant"),
  list(prefix = "debtN",   filename = "debt"),
  list(prefix = "taxN",    filename = "tax"),
  list(prefix = "taxproN", filename = "taxpro")
)

walk(outcomes_rob, function(o) {
  p1 <- create_plot_free(
    prepare_data(paste0(results_path, "heterogeneity/afl/dCMDH_afl_0_",
                        o$prefix, ".csv")),
    "Healthy")
  p2 <- create_plot_free(
    prepare_data(paste0(results_path, "heterogeneity/afl/dCMDH_afl_1_",
                        o$prefix, ".csv")),
    "Distressed")
  save_fig(p1 + p2,
           paste0("fig_afl_", o$filename, ".pdf"),
           width = 20, height = 6)
})

# --- 2.3 Heterogeneity by household income ---------
walk(outcomes_rob, function(o) {
  p1 <- create_plot_free(
    prepare_data(paste0(results_path, "heterogeneity/income/dCMDH_rich_0_",
                        o$prefix, ".csv")),
    "Low income")
  p2 <- create_plot_free(
    prepare_data(paste0(results_path, "heterogeneity/income/dCMDH_rich_1_",
                        o$prefix, ".csv")),
    "High income")
  save_fig(p1 + p2,
           paste0("fig_rich_", o$filename, ".pdf"),
           width = 20, height = 6)
})

# =============================================================
# PART 3 : ROBUSTNESS CHECKS
# =============================================================

outcomes_rob <- list(
  list(prefix = "depinvN", filename = "invex"),
  list(prefix = "depfN",   filename = "curex"),
  list(prefix = "grantN",  filename = "grant"),
  list(prefix = "debtN",   filename = "debt"),
  list(prefix = "taxN",    filename = "tax"),
  list(prefix = "taxproN", filename = "taxpro")
)

# --- 3.1 Type of disaster -------------------------------------
walk(outcomes_rob, function(o) {
  p1 <- create_plot_free(
    prepare_data(paste0(results_path, "robustness/dCMDH_RC_", o$prefix, ".csv")),
    "All disasters")
  p2 <- create_plot_free(
    prepare_data(paste0(results_path, "robustness/dCMDH_RD_", o$prefix, ".csv")),
    "Droughts")
  save_fig(p1 + p2,
           paste0("fig_type_", o$filename, ".pdf"),
           width = 20, height = 6)
})

# --- 3.2 Sensitivity checks -----------------------------------
walk(outcomes_rob, function(o) {
  p1 <- create_plot_free(
    prepare_data(paste0(results_path, "robustness/dCMDH_RNF_",    o$prefix, ".csv")),
    "Non-normalized")
  p2 <- create_plot_free(
    prepare_data(paste0(results_path, "robustness/dCMDH_small_", o$prefix, ".csv")),
    "Small communes")
  p3 <- create_plot_free(
    prepare_data(paste0(results_path, "robustness/dCMDH_nolito_",   o$prefix, ".csv")),
    "No littoral")
  save_fig(p1 + p2 + p3,
           paste0("fig_sens_", o$filename, ".pdf"),
           width = 30, height = 6)
})


# =============================================================
# PART 4 : DESCRIPTIVE FIGURES
# =============================================================

library(sf)

# --- 4.1 Map of natural disasters ----------------------------

# Load geographic data
# Note: these files are not posted on GitHub due to size
# Download from: https://geoservices.ign.fr/adminexpress
geo_commune <- st_read(
  "C:/sdrive/DATA/import-1/geo_commune_2022/geo_commune_2022.shp",
  quiet = TRUE
) %>% rename(cod_commune = cd_cmmn)

fr <- st_read(
  "C:/sdrive/DATA/AIRCOV_DATA/GEO/fr_shp/fr.shp",
  quiet = TRUE
)

# Charger la base complète
data_budgetco <- read_parquet(paste0(path_output, "data_budgetco.parquet"))
catnat_gaspar <- read_delim(
  paste0(path_data, "gaspar26/catnat_gaspar.csv"),
  delim = ";", escape_double = FALSE, trim_ws = TRUE
)

# Construire les cumuls sur toute la base
catnat_full <- catnat_gaspar %>%
  mutate(year = year(dat_deb)) %>%
  filter(year >= 2000) %>%
  mutate(big_type = case_when(
    num_risque_jo == "SEC" ~ "SEC",
    TRUE                   ~ "FLOODS_STORMS"
  )) %>%
  filter(big_type == "FLOODS_STORMS") %>%
  group_by(cod_commune) %>%
  summarise(choc = n(), .groups = "drop")

# Pour la carte
base_map <- data_budgetco %>%
  distinct(cod_commune) %>%
  left_join(catnat_full, by = "cod_commune") %>%
  mutate(choc = ifelse(is.na(choc), 0, choc)) %>%
  right_join(geo_commune, by = "cod_commune") %>%
  mutate(
    choc_cat = case_when(
      choc == 0     ~ "No disaster",
      choc == 1     ~ "1",
      choc == 2     ~ "2",
      choc %in% 3:5  ~ "3-5",
      choc %in% 6:10 ~ "6-10",
      choc %in% 11:20 ~ "11-20",
      choc > 20      ~ ">20"
    ),
    choc_cat = factor(choc_cat,
                      levels = c("No disaster", "1", "2",
                                 "3-5", "6-10", "11-20", ">20"))
  )

# Plot
p_map <- ggplot() +
  geom_sf(data = fr,       aes(geometry = geometry),
          fill = "white", color = "black") +
  geom_sf(data = base_map, aes(geometry = geometry, fill = choc_cat),
          color = NA) +
  scale_fill_manual(
    values = c(
      "No disaster" = "white",
      "1"           = "#FCFDBF",
      "2"           = "#FE9F6D",
      "3-5"         = "#DE4968",
      "6-10"        = "#8C2981",
      "11-20"       = "#3B0F70",
      ">20"         = "#000004"
    ),
    guide = guide_legend(title = "Natural disaster occurrence",
                         title.position = "top")
  ) +
  theme_minimal() +
  theme(
    panel.grid   = element_blank(),
    axis.title   = element_blank(),
    axis.text    = element_blank(),
    axis.ticks   = element_blank(),
    legend.title = element_text(size = 14),
    legend.text  = element_text(size = 14)
  )

ggsave(
  filename = paste0(figures_path, "natural_disasters_map.png"),
  plot     = p_map,
  width    = 10,
  height   = 8,
  units    = "in",
  dpi      = 300
)
cat("Saved: natural_disasters_map.png\n")

# --- 4.2 Pie chart: distribution of disaster frequency -------

nbcata <- data_budgetco %>%
  distinct(cod_commune) %>%
  left_join(catnat_full, by = "cod_commune") %>%
  mutate(floods = ifelse(is.na(choc), 0, choc))

df_pie <- nbcata %>%
  mutate(
    categorie = case_when(
      floods == 0 ~ "0",
      floods == 1 ~ "1",
      floods == 2 ~ "2",
      floods == 3 ~ "3",
      floods == 4 ~ "4",
      floods >= 5 ~ ">5"
    ),
    categorie = factor(categorie,
                       levels = c("0", "1", "2", "3", "4", ">5"))
  ) %>%
  group_by(categorie) %>%
  summarise(n = n(), .groups = "drop") %>%
  mutate(
    pourcentage = n / sum(n),
    label       = scales::percent(pourcentage, accuracy = 0.9),
    ymax        = cumsum(pourcentage),
    ymin        = c(0, head(ymax, n = -1)),
    label_pos   = (ymax + ymin) / 2
  )

p_pie <- ggplot(df_pie,
                aes(xmax = 1, xmin = 0.6,
                    ymax = ymax, ymin = ymin,
                    fill = categorie)) +
  geom_rect(color = "white", linewidth = 1) +
  geom_text(aes(x = 0.8, y = label_pos, label = label),
            color = "white", size = 5, fontface = "bold") +
  scale_fill_manual(
    values = c("#D3D3D3", "#A8D5E2", "#F4A460",
               "#E07A5F", "darkred", "#800010"),
    name   = "Nb Disasters"
  ) +
  coord_polar(theta = "y", start = 0) +
  xlim(0.5, 1) +
  theme_void() +
  theme(
    plot.title       = element_text(hjust = 0.5, face = "bold", size = 14),
    legend.position  = "left"
  )

ggsave(
  filename = paste0(figures_path, "pie_floods.pdf"),
  plot     = p_pie,
  width    = 10,
  height   = 7,
  units    = "in",
  dpi      = 300
)
cat("Saved: pie_floods.pdf\n")
