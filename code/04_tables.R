# =============================================================
# 04_tables.R
# Generate all tables for the paper
# Author: Carla Morvan
# =============================================================

# --- 1. Packages ---------------------------------------------
library(arrow)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(knitr)

# --- 2. Paths ------------------------------------------------
#data_path    <- "data/"
results_path <- "results/"
tables_path  <- "tables/"
dir.create(tables_path, recursive = TRUE, showWarnings = FALSE)

# --- 3. Load data --------------------------------------------
df_run        <- read_parquet(paste0(path_output, "df_run.parquet"))
data_budgetco <- read_parquet(paste0(path_output, "data_budgetco.parquet"))

# =============================================================
# UTILITY FUNCTIONS
# =============================================================

# Extract Av_tot, F-test, N, Switchers from a dCDMH CSV
extract_avg <- function(path, outcome, groupe) {
  
  # Lecture
  dat <- read_csv(path, show_col_types = FALSE)
  
  # Extraire les lignes utiles directement avec ...1
  av_row  <- dat %>% filter(str_detect(`...1`, "Av_tot"))
  pl_rows <- dat %>% filter(str_detect(`...1`, "Placebo"))
  
  # Av_tot avec étoiles
  est  <- av_row$Estimate
  se   <- av_row$SE
  lb   <- av_row$`LB CI`
  ub   <- av_row$`UB CI`
  n    <- av_row$N
  sw   <- av_row$Switchers
  
  sig <- (lb > 0) | (ub < 0)
  stars <- case_when(
    sig & abs(est/se) > 2.576 ~ "***",
    sig & abs(est/se) > 1.96  ~ "**",
    sig                        ~ "*",
    TRUE                       ~ ""
  )
  cell_av <- paste0(round(est, 3), stars, "\n(", round(se, 3), ")")
  
  # F-test placebos
  n_pl   <- nrow(pl_rows)
  fstat  <- sum((pl_rows$Estimate / pl_rows$SE)^2) / n_pl
  pval   <- pf(fstat, n_pl, Inf, lower.tail = FALSE)
  sf <- case_when(
    pval < 0.001 ~ "***", pval < 0.01 ~ "**",
    pval < 0.05  ~ "*",   TRUE ~ ""
  )
  
  tibble(
    outcome  = outcome,
    groupe   = groupe,
    av_tot   = cell_av,
    f_test   = paste0(round(pval, 3), sf),
    n_total  = n,
    n_switch = sw
  )
}

# Build wide table from list of specs
build_table <- function(specs, outcomes, sep = "_") {
  map_dfr(specs, function(s) {
    map_dfr(outcomes, function(o) {
      path <- paste0(s$path, o$prefix, ".csv")
      extract_avg(path, o$name, s$label)
    })
  }) %>%
    select(outcome, groupe, av_tot, f_test, n_total, n_switch) %>%
    mutate(
      n_total  = format(n_total,  big.mark = ","),
      n_switch = format(n_switch, big.mark = ",")
    ) %>%
    pivot_longer(cols = c(av_tot, f_test, n_total, n_switch),
                 names_to = "label", values_to = "value") %>%
    mutate(label = case_when(
      label == "av_tot"   ~ "Av. tot.",
      label == "f_test"   ~ "Placebo F-test (p-val.)",
      label == "n_total"  ~ "N",
      label == "n_switch" ~ "Switchers"
    )) %>%
    mutate(
      label   = factor(label, levels = c("Av. tot.", "Placebo F-test (p-val.)",
                                         "N", "Switchers")),
      outcome = factor(outcome, levels = map_chr(outcomes, "name"))
    ) %>%
    arrange(outcome, label) %>%
    pivot_wider(names_from = groupe, values_from = value) %>%
    mutate(across(-c(outcome, label),
                  ~str_replace_na(., "") %>% str_replace("\n", "\\\\\\\\")))
}

# =============================================================
# TABLE 1 : MAIN RESULTS (budget outcomes)
# =============================================================

outcomes_main <- list(
  list(name = "Investment exp.",   prefix = "depinvN"),
  list(name = "Current exp.",      prefix = "depfN"),
  list(name = "Grants",            prefix = "grantN"),
  list(name = "Debt",              prefix = "debtN")
)

specs_main <- list(list(label = "main", path = paste0(results_path, "dCMDH_")))
for(s in specs_main) {
  for(o in outcomes_main) {
    path <- paste0(s$path, o$prefix, ".csv")
    cat("Testing:", path, "- exists:", file.exists(path), "\n")
    if(file.exists(path)) {
      tryCatch(
        extract_avg(path, o$name, s$label),
        error = function(e) cat("ERROR on", o$name, ":", e$message, "\n")
      )
    }
  }
}

table1 <- build_table(specs_main, outcomes_main) %>%
  select(outcome, label, main) %>%
  mutate(across(main, ~str_remove_all(., "\\\\\\\\")))

write_csv(table1, paste0(tables_path, "table1_main_budget.csv"))
cat("Table 1 saved.\n")

# =============================================================
# TABLE 2 : TAX RESULTS
# =============================================================

outcomes_tax <- list(
  list(name = "Property tax rate", prefix = "taxN"),
  list(name = "Property tax base", prefix = "basetaxN"),
  list(name = "Business tax rate", prefix = "taxproN"),
  list(name = "Business tax base", prefix = "basetaxproN")
)

table2 <- build_table(specs_main, outcomes_tax) %>%
  select(outcome, label, main) %>%
  mutate(across(main, ~str_remove_all(., "\\\\\\\\")))

write_csv(table2, paste0(tables_path, "table2_taxes.csv"))
cat("Table 2 saved.\n")

# =============================================================
# TABLE 3 : HETEROGENEITY BY NUMBER OF FLOODS
# =============================================================

outcomes_nb <- list(
  list(name = "Investment exp.", prefix = "depinvN"),
  list(name = "Current exp.",    prefix = "depfN"),
  list(name = "Grants",          prefix = "grantN"),
  list(name = "Debt",            prefix = "debtN")
)

specs_nb <- list(
  list(label = "1st Flood",
       path  = paste0(results_path, "heterogeneity/nb_floods/dCMDH_")),
  list(label = "2nd Flood",
       path  = paste0(results_path, "heterogeneity/nb_floods/dCMDH_")),
  list(label = "3rd Flood",
       path  = paste0(results_path, "heterogeneity/nb_floods/dCMDH_"))
)

# Special case: nb_floods files have suffix _1, _2, _3
all_nb <- map_dfr(1:3, function(n) {
  label <- paste0(c("1st", "2nd", "3rd")[n], " Flood")
  map_dfr(outcomes_nb, function(o) {
    path <- paste0(results_path, "heterogeneity/nb_floods/dCMDH_",
                   o$prefix, "_", n, ".csv")
    extract_avg(path, o$name, label)
  })
}) %>%
  select(outcome, groupe, av_tot, f_test, n_total, n_switch) %>%
  mutate(
    n_total  = format(n_total,  big.mark = ","),
    n_switch = format(n_switch, big.mark = ",")
  ) %>%
  pivot_longer(cols = c(av_tot, f_test, n_total, n_switch),
               names_to = "label", values_to = "value") %>%
  mutate(label = case_when(
    label == "av_tot"   ~ "Av. tot.",
    label == "f_test"   ~ "Placebo F-test (p-val.)",
    label == "n_total"  ~ "N",
    label == "n_switch" ~ "Switchers"
  )) %>%
  mutate(
    label   = factor(label, levels = c("Av. tot.", "Placebo F-test (p-val.)",
                                       "N", "Switchers")),
    outcome = factor(outcome, levels = map_chr(outcomes_nb, "name"))
  ) %>%
  arrange(outcome, label) %>%
  pivot_wider(names_from = groupe, values_from = value) %>%
  select(outcome, label, `1st Flood`, `2nd Flood`, `3rd Flood`) %>%
  mutate(across(-c(outcome, label),
                ~str_replace_na(., "") %>% str_replace("\n", "\\\\\\\\")))

write_csv(all_nb, paste0(tables_path, "table3_nb_floods.csv"))
cat("Table 3 saved.\n")

# =============================================================
# TABLE 4 : HETEROGENEITY BY FINANCIAL HEALTH (AFL)
# =============================================================
extract_avg <- function(path, outcome, groupe) {
  
  dat <- read_csv(path, show_col_types = FALSE)
  
  # Détecter le nom de la colonne id
  id_col <- if("...1" %in% names(dat)) "...1" else "label"
  
  # Extraire les lignes utiles
  av_row  <- dat %>% filter(str_detect(.data[[id_col]], "Av_tot"))
  pl_rows <- dat %>% filter(str_detect(.data[[id_col]], "Placebo"))
  
  # Av_tot avec étoiles
  est  <- av_row$Estimate
  se   <- av_row$SE
  lb   <- av_row$`LB CI`
  ub   <- av_row$`UB CI`
  n    <- av_row$N
  sw   <- av_row$Switchers
  
  sig <- (lb > 0) | (ub < 0)
  stars <- case_when(
    sig & abs(est/se) > 2.576 ~ "***",
    sig & abs(est/se) > 1.96  ~ "**",
    sig                        ~ "*",
    TRUE                       ~ ""
  )
  cell_av <- paste0(round(est, 3), stars, "\n(", round(se, 3), ")")
  
  # F-test placebos
  n_pl  <- nrow(pl_rows)
  fstat <- sum((pl_rows$Estimate / pl_rows$SE)^2) / n_pl
  pval  <- pf(fstat, n_pl, Inf, lower.tail = FALSE)
  sf <- case_when(
    pval < 0.001 ~ "***", pval < 0.01 ~ "**",
    pval < 0.05  ~ "*",   TRUE ~ ""
  )
  
  tibble(
    outcome  = outcome,
    groupe   = groupe,
    av_tot   = cell_av,
    f_test   = paste0(round(pval, 3), sf),
    n_total  = n,
    n_switch = sw
  )
}
outcomes_afl <- list(
  list(name = "Investment exp.",   prefix = "depinvN"),
  list(name = "Current exp.",      prefix = "depfN"),
  list(name = "Grants",            prefix = "grantN"),
  list(name = "Debt",              prefix = "debtN"),
  list(name = "Property tax rate", prefix = "taxN"),
  list(name = "Business tax rate", prefix = "taxproN")
)

specs_afl <- list(
  list(label = "Healthy",
       path  = paste0(results_path, "heterogeneity/afl/dCMDH_afl_0_")),
  list(label = "Distressed",
       path  = paste0(results_path, "heterogeneity/afl/dCMDH_afl_1_"))
)

table4 <- build_table(specs_afl, outcomes_afl) %>%
  select(outcome, label, Healthy, Distressed) %>%
  mutate(across(-c(outcome, label), ~str_remove_all(., "\\\\\\\\")))

write_csv(table4, paste0(tables_path, "table4_afl.csv"))
cat("Table 4 saved.\n")

# =============================================================
# TABLE A.5 : DESCRIPTIVE STATISTICS
# =============================================================

vars_budget <- c("fdepinv", "fcharge", "totalgrant", "debt",
                 "fbfb", "tfb", "fbtp", "ttp", "MEDREV", "pop1")
vars_catnat <- c("FLOODS_STORMS", "SEC", "nb_catnat_total")
all_vars <- c(vars_budget, vars_catnat)

# Stats pour chaque échantillon séparément
compute_stats <- function(data) {
  data %>%
    ungroup() %>%
    summarise(across(all_of(all_vars),
                     list(mean = ~round(mean(., na.rm = TRUE), 1),
                          sd   = ~round(sd(.,   na.rm = TRUE), 1)),
                     .names = "{.col}__{.fn}"))
}

stats_full <- compute_stats(data_budgetco %>%
                              left_join(df_run %>%
                                          select(cod_commune, year,
                                                 FLOODS_STORMS, SEC,
                                                 nb_catnat_total) %>%
                                          distinct(),
                                        by = c("cod_commune", "year")))

stats_1999 <- compute_stats(df_run)

# Assembler proprement
table_a5 <- tibble(
  Variable = c("Investment exp.", "Current exp.", "Grants", "Debt",
               "Property tax base", "Property tax rate",
               "Business tax base", "Business tax rate",
               "Median income", "Population",
               "Floods & Storms", "Droughts", "All disasters"),
  Full_mean = as.numeric(stats_full %>% select(ends_with("__mean"))),
  Full_sd   = as.numeric(stats_full %>% select(ends_with("__sd"))),
  S1999_mean = as.numeric(stats_1999 %>% select(ends_with("__mean"))),
  S1999_sd   = as.numeric(stats_1999 %>% select(ends_with("__sd"))),
  N_full     = n_distinct(data_budgetco$cod_commune),
  N_1999     = n_distinct(df_run$cod_commune)
)

write_csv(table_a5, paste0(tables_path, "tableA5_desc_stats.csv"))
cat("Table A5 saved.\n")

# =============================================================
# TABLE A.6 : ROBUSTNESS BY DISASTER TYPE
# =============================================================

specs_rob_type <- list(
  list(label = "Floods",
       path  = paste0(results_path, "/dCMDH_")),
  list(label = "All CatNat",
       path  = paste0(results_path, "robustness/dCMDH_RC_")),
  list(label = "Droughts",
       path  = paste0(results_path, "robustness/dCMDH_RD_"))
)

table_a6 <- build_table(specs_rob_type, outcomes_afl) %>%
  select(outcome, label, Floods, `All CatNat`, Droughts) %>%
  mutate(across(-c(outcome, label), ~str_remove_all(., "\\\\\\\\")))

write_csv(table_a6, paste0(tables_path, "tableA6_rob_type.csv"))
cat("Table A6 saved.\n")

# =============================================================
# TABLE A.7 : HETEROGENEITY BY HOUSEHOLD INCOME
# =============================================================

specs_rich <- list(
  list(label = "Low income",
       path  = paste0(results_path, "heterogeneity/income/dCMDH_rich_0_")),
  list(label = "High income",
       path  = paste0(results_path, "heterogeneity/income/dCMDH_rich_1_"))
)

table_a7 <- build_table(specs_rich, outcomes_afl) %>%
  select(outcome, label, `Low income`, `High income`) %>%
  mutate(across(-c(outcome, label), ~str_remove_all(., "\\\\\\\\")))

write_csv(table_a7, paste0(tables_path, "tableA7_rich.csv"))
cat("Table A7 saved.\n")

# =============================================================
# TABLE A.8 : SENSITIVITY CHECKS
# =============================================================

specs_sens <- list(
  list(label = "Baseline",
       path  = paste0(results_path, "/dCMDH_")),
  list(label = "Non-normalized",
       path  = paste0(results_path, "robustness/dCMDH_RNF_")),
  list(label = "Small communes",
       path  = paste0(results_path, "robustness/dCMDH_small_")),
  list(label = "No littoral",
       path  = paste0(results_path, "robustness/dCMDH_nolito_"))
)

table_a8 <- build_table(specs_sens, outcomes_afl) %>%
  select(outcome, label, Baseline, `Non-normalized`,
         `Small communes`, `No littoral`) %>%
  mutate(across(-c(outcome, label), ~str_remove_all(., "\\\\\\\\")))

write_csv(table_a8, paste0(tables_path, "tableA8_sensitivity.csv"))
cat("Table A8 saved.\n")

cat("\nAll tables saved successfully!\n")
