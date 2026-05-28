# =============================================================
# 01_build_sample.R
# Build the main estimation sample (df_run) from:
#   - data_budgetco.parquet (posted on GitHub)
#   - catnat_gaspar.csv (posted on GitHub, source: GASPAR)
#
# Author: Carla Morvan
# =============================================================

# --- 1. Packages ---------------------------------------------
library(arrow)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(lubridate)

# --- 2. Paths ------------------------------------------------
# Adapt these paths to your local setup
path_raw    <- "raw/"
path_data   <- "data/"
path_output <- "data/output/"
# =============================================================
# PART 1 : PROCESS GASPAR DATA
# =============================================================

# --- 1.1 Load and classify disasters -------------------------
catnat_gaspar <- read_delim(
  paste0(path_data, "gaspar26/catnat_gaspar.csv"),
  delim = ";", escape_double = FALSE, trim_ws = TRUE
) %>%
  mutate(year = year(dat_deb)) %>%
  group_by(cod_commune, dat_deb, num_risque_jo) %>%
  summarise(
    lib_commune   = first(lib_commune),
    lib_risque_jo = first(lib_risque_jo),
    year          = min(year),
    .groups       = "drop"
  ) %>%
  mutate(
    type_cat = case_when(
      num_risque_jo %in% c("ICB", "COB", "IRN", "LVT")                ~ "flood",
      num_risque_jo %in% c("MVT", "GLT", "ECB", "EFA", "GET", "GER") ~ "landslide",
      num_risque_jo %in% c("SEC")                                       ~ "drought",
      num_risque_jo %in% c("TMP", "VCY", "CMV", "RAZ")                ~ "storm",
      num_risque_jo %in% c("PDN", "GRL", "AVA")                        ~ "snow_hail",
      num_risque_jo %in% c("SEI", "VOL")                               ~ "earthquake_volcano",
      num_risque_jo %in% c("DIV")                                       ~ "other",
      TRUE                                                               ~ NA_character_
    ),
    big_type_cat = case_when(
      type_cat == "drought"                                              ~ "SEC",
      type_cat %in% c("flood", "landslide", "earthquake_volcano",
                      "storm", "snow_hail", "other")                   ~ "FLOODS_STORMS",
      TRUE                                                               ~ NA_character_
    )
  )

# --- 1.2 Load budget data to get list of municipalities ------
data_budgetco <- read_parquet(paste0(path_output, "data_budgetco.parquet"))

# --- 1.3 Build commune x year panel --------------------------
expanded_catnat <- expand.grid(
  cod_commune = unique(data_budgetco$cod_commune),
  year        = seq(1982, 2024)
) %>%
  full_join(
    catnat_gaspar %>%
      mutate(catnat = 1) %>%
      select(cod_commune, year, catnat, big_type_cat),
    by = c("cod_commune", "year")
  ) %>%
  arrange(cod_commune, year) %>%
  group_by(cod_commune, year) %>%
  mutate(catnat = ifelse(is.na(catnat), 0, catnat)) %>%
  ungroup()

# --- 1.4 Aggregate by type and compute cumulative counts -----
catnat_commune_annee <- expanded_catnat %>%
  group_by(cod_commune, year, big_type_cat) %>%
  summarise(catnat = sum(catnat), .groups = "drop") %>%
  pivot_wider(
    names_from  = big_type_cat,
    values_from = catnat,
    values_fill = 0
  ) %>%
  select(-any_of("NA")) %>%
  right_join(
    expanded_catnat %>%
      group_by(cod_commune, year) %>%
      summarise(nb_catnat_total = sum(catnat == 1, na.rm = TRUE),
                .groups = "drop"),
    by = c("cod_commune", "year")
  ) %>%
  group_by(cod_commune) %>%
  arrange(year, .by_group = TRUE) %>%
  mutate(
    FLOODS_cumule = cumsum(FLOODS_STORMS),
    SEC_cumule    = cumsum(SEC),
    CATNAT_cumule = cumsum(nb_catnat_total)
  ) %>%
  ungroup()

# =============================================================
# PART 2 : BUILD HISTORICAL EXPOSURE VARIABLES
# =============================================================

# --- 2.1 Historical exposure index (Masiero & Santarossa, 2020) -----
# HE_2000 = sum of disasters before 2000, weighted by 1/(2000-t)
he_index <- catnat_commune_annee %>%
  filter(year %in% 1982:1999) %>%
  mutate(
    time_diff      = 2000 - year,
    weight         = 1 / time_diff,
    weighted_shock = nb_catnat_total * weight
  ) %>%
  group_by(cod_commune) %>%
  summarise(HE_2000 = sum(weighted_shock, na.rm = TRUE))

# --- 2.2 Last pre-2000 disaster year -------------------------
last_floods_hist <- catnat_commune_annee %>%
  filter(year %in% 1982:1999, FLOODS_STORMS >= 1) %>%
  group_by(cod_commune) %>%
  slice_max(order_by = year, n = 1) %>%
  summarise(last_floods = first(year))

last_catnat_hist <- catnat_commune_annee %>%
  filter(year %in% 1982:1999, nb_catnat_total >= 1) %>%
  group_by(cod_commune) %>%
  slice_max(order_by = year, n = 1) %>%
  summarise(last_catnat = first(year))

# --- 2.3 Historical cumulative counts up to 1999 -------------
history_counts <- catnat_commune_annee %>%
  filter(year == 1999) %>%
  rename(
    history_floods = FLOODS_cumule,
    history_sec    = SEC_cumule,
    history_catnat = CATNAT_cumule
  ) %>%
  select(cod_commune, history_catnat, history_floods, history_sec)

# =============================================================
# PART 3 : BUILD ESTIMATION SAMPLE
# =============================================================

# --- 3.1 Restrict catnat to 2000-2024 ------------------------
catnat_2000_2024 <- catnat_commune_annee %>%
  filter(year %in% 2000:2024) %>%
  group_by(cod_commune) %>%
  arrange(year, .by_group = TRUE) %>%
  mutate(
    FLOODS_cumule2000 = cumsum(FLOODS_STORMS),
    SEC_cumule2000    = cumsum(SEC),
    CATNAT_cumule2000 = cumsum(nb_catnat_total)
  ) %>%
  ungroup() %>%
  left_join(history_counts,   by = "cod_commune") %>%
  left_join(last_floods_hist, by = "cod_commune") %>%
  left_join(last_catnat_hist, by = "cod_commune") %>%
  left_join(he_index,         by = "cod_commune")

# --- 3.2 Merge budget and catnat data ------------------------
# Use full_join then filter to match original sample construction
data_catnat_budgetco <- data_budgetco %>%
  full_join(catnat_2000_2024, by = c("cod_commune", "year")) %>%
  arrange(cod_commune, year) %>%
  filter(!is.na(dep))  # Remove rows from catnat not in budget data

# --- 3.3 Apply sample restrictions ---------------------------
# Following dCDMH handbook section 8.3.4.7:
# Exclude municipalities with more than one cumulative flood at t=2000
# (initial conditions problem)
# Keep only municipalities whose last pre-2000 flood was in 1999
# (common baseline following Lothar & Martin storms)

df_run <- data_catnat_budgetco %>%
  group_by(cod_commune) %>%
  filter(!any(year == 2000 & FLOODS_cumule2000 > 1)) %>%
  ungroup() %>%
  filter(!is.na(last_floods)) %>%
  group_by(cod_commune) %>%
  filter(any(last_floods == 1999)) %>%
  ungroup()

# --- 3.4 Build risk groups for trends_nonparam ---------------
# Municipalities grouped by historical disaster exposure
# Used as trends_nonparam in dCDMH estimation
# See de Chaisemartin & D'Haultfoeuille (2024), Section 1.4
n_groups <- 3000

df_run <- df_run %>%
  mutate(
    risk_group_num = ifelse(
      HE_2000 == 0, 0,
      ntile(ifelse(HE_2000 > 0, HE_2000, NA), n = n_groups)
    ),
    risk_group = case_when(
      risk_group_num == 0 ~ "G0_No_History",
      TRUE                ~ paste0("G", risk_group_num, "_Risk")
    ),
    risk_group = factor(
      risk_group,
      levels = unique(risk_group[order(risk_group_num)])
    )
  ) %>%
  select(-risk_group_num)

# --- 3.5 Summary ---------------------------------------------
cat("Sample built successfully.\n")
cat("N municipalities:", n_distinct(df_run$cod_commune), "\n")
cat("N observations:  ", nrow(df_run), "\n")
cat("Years covered:   ", min(df_run$year), "-", max(df_run$year), "\n")

# --- 3.6 Save ------------------------------------------------
write_parquet(df_run, paste0(path_output, "df_run.parquet"))


summary(df_run)
