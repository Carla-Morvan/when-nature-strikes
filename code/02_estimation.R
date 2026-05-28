# =============================================================
# 02_estimation.R
# Main estimations using the non-binary staggered DiD estimator
# of de Chaisemartin & D'Haultfoeuille (2024)
#
# Specification:
#   - Treatment: FLOODS_cumule2000 (cumulative floods since 2000)
#   - Cluster: cod_commune
#   - trends_nonparam: risk_group (historical exposure groups)
#   - normalized: TRUE
#   - effects: 10, placebo: 3
#
# Author: Carla Morvan
# =============================================================

# --- 1. Packages ---------------------------------------------
library(arrow)
library(dplyr)
library(DIDmultiplegtDYN)

# --- 2. Paths ------------------------------------------------
path_output  <- "data/output/"
results_path <- "results/"
dir.create(results_path, recursive = TRUE, showWarnings = FALSE)

# --- 3. Load data --------------------------------------------
df_run <- read_parquet(paste0(path_output, "df_run.parquet"))

# --- 4. Common estimation parameters -------------------------
run_did <- function(df, outcome, file_path, normalized = TRUE,
                    effects = 10, placebo = 3) {
  cat("Running:", outcome, "\n")
  result <- did_multiplegt_dyn(
    df              = df,
    outcome         = outcome,
    group           = "cod_commune",
    time            = "year",
    treatment       = "FLOODS_cumule2000",
    effects         = effects,
    placebo         = placebo,
    normalized      = normalized,
    trends_nonparam = "risk_group",
    cluster         = "cod_commune",
    save_results    = file_path   # ← renommé file_path
  )
  saveRDS(result, gsub(".csv", ".rds", file_path))
  cat("Done:", outcome, "\n\n")
  return(result)
}

# =============================================================
# PART 1 : MAIN RESULTS
# =============================================================

# --- 1.1 Expenditures -----------------------------------------
run_did(df_run, "hdepinv",
        paste0(results_path, "dCMDH_depinvN.csv"))

run_did(df_run, "hdepf",
        paste0(results_path, "dCMDH_depfN.csv"))

# --- 1.2 Financing --------------------------------------------
run_did(df_run, "htotalgrant",
        paste0(results_path, "dCMDH_grantN.csv"))

run_did(df_run, "hdebt",
        paste0(results_path, "dCMDH_debtN.csv"))

# --- 1.3 Property tax -----------------------------------------
run_did(df_run, "tfb",
        paste0(results_path, "dCMDH_taxN.csv"))

run_did(df_run, "hfbfb",
        paste0(results_path, "dCMDH_basetaxN.csv"))

# --- 1.4 Business tax -----------------------------------------
run_did(df_run, "ttp",
        paste0(results_path, "dCMDH_taxproN.csv"))

run_did(df_run, "hfbtp",
        paste0(results_path, "dCMDH_basetaxproN.csv"))

# =============================================================
# PART 2 : HETEROGENEITY
# =============================================================
# --- 2.1 Heterogeneity by disaster frequency ----

results_nb_path <- paste0(results_path, "heterogeneity/nb_floods/")
dir.create(results_nb_path, recursive = TRUE, showWarnings = FALSE)

# --- Function to build subsamples by disaster level 
# Switchers: municipalities that reach niveau_max
# Controls: municipalities that reach niveau_min but never exceed niveau_max
make_subsample <- function(df, niveau_min, niveau_max) {
  df %>%
    group_by(cod_commune) %>%
    filter(
      any(FLOODS_cumule2000 >= niveau_max) |
        (max(FLOODS_cumule2000) >= niveau_min & max(FLOODS_cumule2000) < niveau_max)
    ) %>%
    mutate(
      year_at_min    = ifelse(niveau_min > 0 & any(FLOODS_cumule2000 >= niveau_min),
                              min(year[FLOODS_cumule2000 >= niveau_min]), NA),
      year_above_max = ifelse(any(FLOODS_cumule2000 > niveau_max),
                              min(year[FLOODS_cumule2000 > niveau_max]), NA)
    ) %>%
    filter(is.na(year_at_min)    | year >= year_at_min) %>%
    filter(is.na(year_above_max) | year < year_above_max) %>%
    ungroup()
}

# --- Build subsamples 
df_s1 <- make_subsample(df_run, niveau_min = 0, niveau_max = 1)
df_s2 <- make_subsample(df_run, niveau_min = 1, niveau_max = 2)
df_s3 <- make_subsample(df_run, niveau_min = 2, niveau_max = 5)

cat("S1:", n_distinct(df_s1$cod_commune), "communes\n")
cat("S2:", n_distinct(df_s2$cod_commune), "communes\n")
cat("S3:", n_distinct(df_s3$cod_commune), "communes\n")

# --- Outcomes 
outcomes_nb <- list(
  list(outcome = "hdepinv",     prefix = "depinvN"),
  list(outcome = "hdepf",       prefix = "depfN"),
  list(outcome = "htotalgrant", prefix = "grantN"),
  list(outcome = "hdebt",       prefix = "debtN")
)

# --- Run estimations 
subsamples <- list(
  list(df = df_s1, n = 1),
  list(df = df_s2, n = 2),
  list(df = df_s3, n = 3)
)

for(s in subsamples) {
  for(o in outcomes_nb) {
    run_did(
      df       = s$df,
      outcome  = o$outcome,
      file_path = paste0(results_nb_path, "dCMDH_", o$prefix, "_", s$n, ".csv")
    )
  }
}



# --- 2.2 Heterogeneity by financial health (AFL) ---------
results_afl_path <- paste0(results_path,"/heterogeneity/afl/")
dir.create(results_afl_path, recursive = TRUE, showWarnings = FALSE)

df_run_afl <- df_run %>% filter(!is.na(afl_dummy))

# Helper function to extract by-group results
extract_by_results <- function(obj, outcome_name, path_base, prefix = "afl") {
  col_names <- c("Estimate", "SE", "LB CI", "UB CI",
                 "N", "Switchers", "N.w", "Switchers.w")
  for(i in seq_along(obj$by_levels)) {
    level      <- obj$by_levels[i]
    level_data <- obj[[paste0("by_level_", i)]]$results
    final_df   <- bind_rows(
      as.data.frame(level_data$Effects)  %>% setNames(col_names) %>%
        mutate(label = paste0("Effect_",  row_number())),
      as.data.frame(level_data$ATE)      %>% setNames(col_names) %>%
        mutate(label = "Av_tot_eff"),
      as.data.frame(level_data$Placebos) %>% setNames(col_names) %>%
        mutate(label = paste0("Placebo_", row_number()))
    ) %>% select(label, everything())
    write_csv(final_df,
              paste0(path_base, "dCMDH_", prefix, "_", level, "_", outcome_name, ".csv"))
    cat("Saved group", level, "for", outcome_name, "\n")
  }
}

outcomes_afl <- list(
  list(outcome = "hdepinv",     prefix = "depinvN"),
  list(outcome = "hdepf",       prefix = "depfN"),
  list(outcome = "htotalgrant", prefix = "grantN"),
  list(outcome = "hdebt",       prefix = "debtN"),
  list(outcome = "tfb",         prefix = "taxN"),
  list(outcome = "ttp",         prefix = "taxproN")
)

for(o in outcomes_afl) {
  cat("Running AFL heterogeneity:", o$outcome, "\n")
  result <- did_multiplegt_dyn(
    df              = df_run_afl,
    outcome         = o$outcome,
    group           = "cod_commune",
    time            = "year",
    treatment       = "FLOODS_cumule2000",
    effects         = 10,
    placebo         = 3,
    normalized      = TRUE,
    trends_nonparam = "risk_group",
    by              = "afl_dummy",
    cluster         = "cod_commune",
    save_results    = paste0(results_afl_path, "dCMDH_afl_", o$prefix, ".csv")
  )
  saveRDS(result, paste0(results_afl_path, "dCMDH_afl_", o$prefix, ".rds"))
  extract_by_results(result, o$prefix, results_afl_path, prefix = "afl")
}

# --- 2.3 Heterogeneity by household income -------

results_rich_path <- paste0(results_path,"/heterogeneity/income/")
dir.create(results_rich_path, recursive = TRUE, showWarnings = FALSE)

df_run_rich <- df_run %>% filter(!is.na(rich_dummy))

for(o in outcomes_afl) {
  cat("Running income heterogeneity:", o$outcome, "\n")
  result <- did_multiplegt_dyn(
    df              = df_run_rich,
    outcome         = o$outcome,
    group           = "cod_commune",
    time            = "year",
    treatment       = "FLOODS_cumule2000",
    effects         = 10,
    placebo         = 3,
    normalized      = TRUE,
    trends_nonparam = "risk_group",
    by              = "rich_dummy",
    cluster         = "cod_commune",
    save_results    = paste0(results_rich_path, "dCMDH_rich_", o$prefix, ".csv")
  )
  saveRDS(result, paste0(results_rich_path, "dCMDH_rich_", o$prefix, ".rds"))
  extract_by_results(result, o$prefix, results_rich_path, prefix = "rich")
}
# =============================================================
# PART 3 : ROBUSTNESS CHECKS
# =============================================================

# --- 3.1 Non-normalized --------------------------------------
results_rob_path <- paste0(results_path,"robustness/")
dir.create(results_rob_path, recursive = TRUE, showWarnings = FALSE)

outcomes_main <- list(
  list(outcome = "hdepinv",     prefix = "depinvN"),
  list(outcome = "hdepf",       prefix = "depfN"),
  list(outcome = "htotalgrant", prefix = "grantN"),
  list(outcome = "hdebt",       prefix = "debtN"),
  list(outcome = "tfb",         prefix = "taxN"),
  list(outcome = "ttp",         prefix = "taxproN")
)

for(o in outcomes_main) {
  run_did(df_run, o$outcome,
          paste0(results_rob_path, "dCMDH_RNF_", o$prefix, ".csv"),
          normalized = FALSE)
}

# --- 3.2 Small communes (< 10,000 inhabitants) ---------------
df_small <- df_run %>%
  group_by(cod_commune) %>%
  filter(max(pop1, na.rm = TRUE) <= 10000) %>%
  ungroup()

for(o in outcomes_main) {
  run_did(df_small, o$outcome,
          paste0(results_rob_path, "dCMDH_small_", o$prefix, ".csv"))
}

# --- 3.3 No littoral -----------------------------------------
df_nolitto <- df_run %>% filter(littoral_clean == "TERRE")

for(o in outcomes_main) {
  run_did(df_nolitto, o$outcome,
          paste0(results_rob_path, "dCMDH_nolito_", o$prefix, ".csv"))
}

# --- 3.4 All CatNat ------------------------------------------
for(o in outcomes_main) {
  cat("Running All CatNat:", o$outcome, "\n")
  result <- did_multiplegt_dyn(
    df              = df_run,
    outcome         = o$outcome,
    group           = "cod_commune",
    time            = "year",
    treatment       = "CATNAT_cumule2000",  # ← juste changer le traitement
    effects         = 10,
    placebo         = 3,
    normalized      = TRUE,
    trends_nonparam = "risk_group",
    cluster         = "cod_commune",
    save_results    = paste0(results_rob_path, "dCMDH_RC_", o$prefix, ".csv")
  )
  saveRDS(result, paste0(results_rob_path, "dCMDH_RC_", o$prefix, ".rds"))
}

# --- 3.5 Droughts --------------------------------------------
for(o in outcomes_main) {
  cat("Running Droughts:", o$outcome, "\n")
  result <- did_multiplegt_dyn(
    df              = df_run,
    outcome         = o$outcome,
    group           = "cod_commune",
    time            = "year",
    treatment       = "SEC_cumule2000",  # ← traitement sécheresses
    effects         = 10,
    placebo         = 3,
    normalized      = TRUE,
    trends_nonparam = "risk_group",
    cluster         = "cod_commune",
    save_results    = paste0(results_rob_path, "dCMDH_RD_", o$prefix, ".csv")
  )
  saveRDS(result, paste0(results_rob_path, "dCMDH_RD_", o$prefix, ".rds"))
}
