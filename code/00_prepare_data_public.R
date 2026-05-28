# =============================================================
# 00_prepare_data_public.R
# Prepare the base dataset:
#   - data_budgetco.parquet
#
# NOTE: This script requires access to raw data files.
# Raw data sources are documented in data/README_data.md
# The AFL financial health score (afl_dummy) requires access to 
# proprietary data (afl_2000.csv) not publicly available.
# All other results are fully replicable without this file.
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
library(haven)

# --- 2. Paths ------------------------------------------------
# Adapt these paths to your local setup
path_raw    <- "raw/"
path_data   <- "data/"
path_output <- "data/output/"

# =============================================================
# PART 1 : BUDGET DATA 
# =============================================================

# --- 1.1 Load budget data ------------------------------------
comptescom <- read_parquet(
  paste0(path_data, "comptes_communes_import_mars26/comptescom_2000_2024_use2.parquet")
)

# --- 1.2 Build budget variables ------------------------------
CIC <- comptescom %>%
  rename(year = an) %>%
  group_by(cod_commune) %>%
  mutate(
    totalex     = fcharge + fdepinv,
    totalgrant  = fdgf + fsubr,
    totalrev    = fprod + frecinv,
    totaltax    = fimpo1 + fimpo2,
    debt        = fdette,
    lpop        = log(pop1),
    htotalex    = asinh(totalex),
    htotalgrant = asinh(totalgrant),
    htotalrev   = asinh(totalrev),
    htotaltax   = asinh(totaltax),
    hdebt       = asinh(debt),
    hdepf       = asinh(fcharge),
    hdepinv     = asinh(fdepinv),
    hsubi       = asinh(fsubr),
    htax        = asinh(fimpo1),
    hloan       = asinh(femp),
    hremb       = asinh(fremb),
    hcaf        = asinh(fcaf),
    hpop        = asinh(pop1),
    hfpfb       = asinh(fpfb),
    hfpth       = asinh(fpth),
    hfbfb       = asinh(fbfb),
    hfbth       = asinh(fbth),
    hfbtp       = asinh(fbtp),
    hfbfbexod   = asinh(fbfbexod)
  ) %>%
  ungroup()



# =============================================================
# PART 2 : MERGE FINAL DATABASE (data_catnat_budgetco.parquet)
# =============================================================


# --- 2.1 Add socioeconomic controls --------------------------
MEDREV <- read_csv(paste0(path_data, "REVENU_MEDIAN_2000_2024.csv")) %>%
  rename(year = an) %>%
  distinct(cod_commune, year, MEDREV)

POPULATION <- read_csv(paste0(path_data, "POPULATION.csv"))

data_budget <- CIC %>%
  left_join(MEDREV,     by = c("cod_commune", "year")) %>%
  left_join(POPULATION, by = c("cod_commune", "year")) %>%
  fill(total_pop, pop_20, pop_65, MEDREV, .direction = "down")

# --- 2.2 Add geographic controls -----------------------------
loilittoral <- read_delim(paste0(path_data, "loilittoral_25.csv"),
                          delim = ";", trim_ws = TRUE) %>%
  mutate(
    littoral = ifelse(littoral == "C", 1, 0),
    dep      = substr(cod_commune, 1, 2)
  )

loimontagne <- read_delim(paste0(path_data, "loimontagne_2020.csv"),
                          delim = ";", trim_ws = TRUE) %>%
  rename(cod_commune = INSEE_COM) %>%
  mutate(montagne = 1)

grille_densite <- read_delim(paste0(path_data, "grille_densite2015.csv"),
                             delim = ";", trim_ws = TRUE) %>%
  rename(cod_commune = CODGEO)

AAV2020 <- read_delim(paste0(path_data, "AAV2020_14.csv"),
                      delim = ";", trim_ws = TRUE) %>%
  rename(cod_commune = CODGEO)

deps_cotiers <- unique(loilittoral %>% filter(littoral == 1) %>% pull(dep))

zonage <- loilittoral %>%
  select(cod_commune, littoral) %>%
  full_join(loimontagne %>% select(cod_commune, montagne),
            by = "cod_commune") %>%
  full_join(grille_densite %>% select(cod_commune, DENS),
            by = "cod_commune") %>%
  mutate(
    montagne = ifelse(is.na(montagne), 0, 1),
    montagne = ifelse(montagne == 1, "MONTAGNE", "PLAINE"),
    littoral = ifelse(littoral == 1, "LITTORAL", "TERRE")
  ) %>%
  distinct(cod_commune, montagne, littoral, DENS)

data_budgetco <- data_budget %>%
  left_join(AAV2020 %>% select(cod_commune, AAV2020, LIBAAV2020),
            by = "cod_commune") %>%
  left_join(zonage, by = "cod_commune") %>%
  filter(!is.na(dep)) %>%
  mutate(
    montagne       = ifelse(is.na(montagne), "PLAINE", montagne),
    littoral_clean = case_when(
      is.na(littoral) & dep %in% deps_cotiers  ~ "LITTORAL",
      is.na(littoral) & !dep %in% deps_cotiers ~ "TERRE",
      TRUE ~ as.character(littoral)
    )
  )%>%
  select(-littoral)

# --- 2.3 Add AFL financial health score ----------------------
# Score based on AFL (Agence France Locale) banking formula
# Computed on year 2000 values, ranging from 1 (excellent) to 7 (poor)
afl_2000 <- read.csv("afl_2000.csv")

# Join AFL score to main dataset
data_budgetco <- data_budgetco %>%
  left_join(afl_2000, by = "cod_commune")

# --- 2.4 Add income dummy split ----
medians_2000 <- data_budgetco %>%
  filter(year == 2000) %>%
  summarise(med_rev = median(MEDREV, na.rm = TRUE))

data_budgetco <- data_budgetco %>%
  group_by(cod_commune) %>%
  mutate(MEDREV_2000 = MEDREV[year == 2000][1]) %>%
  ungroup() %>%
  mutate(rich_dummy = as.integer(MEDREV_2000 >= medians_2000$med_rev))

# --- 2.5 Save ------------------------------------------------
write_parquet(data_budgetco,
              paste0(path_output, "data_budgetco.parquet"))

cat("data_budgetco saved.\n")
cat("N municipalities:", n_distinct(data_budgetco$cod_commune), "\n")
cat("N observations:",   nrow(data_budgetco), "\n")
