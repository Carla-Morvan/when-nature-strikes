# Data Documentation

## Raw Data Sources

### Municipal Budget Data
- **Source**: French Ministry of Public Accounts (Direction Générale des Finances Publiques)
- **URL**: https://data.economie.gouv.fr/explore/?search=comptes-individuels-des-communes
- **Coverage**: All French mainland municipalities, 2000--2024
- **Format**: Parquet files by period (downloaded March 2026)

### Natural Disaster Data
- **Source**: GASPAR database (Gestion ASsistée des Procédures Administratives relatives aux Risques), French Ministry of Environment
- **URL**: https://www.georisques.gouv.fr/donnees/bases-de-donnees/procedures-administratives-relatives-aux-risques
- **Coverage**: All recognized natural disasters (CatNat) in France since 1982

### Socioeconomic Data
- **Median household income**: INSEE, Filosofi survey -- https://www.insee.fr/fr/statistiques/6036907
- **Population**: INSEE, legal population estimates -- https://www.insee.fr/fr/statistiques/1893204
- **Urban area typology**: INSEE, Aires d'attraction des villes 2020 -- https://www.insee.fr/fr/information/4803954
- **Population density**: INSEE, Grille de densité 2015 -- https://www.insee.fr/fr/information/6439600
- **Coastal municipalities**: DATAR, Loi Littoral classification -- https://www.data.gouv.fr/datasets/communes-de-la-loi-littoral-au-code-officiel-geographique-cog-2020-2022
- **Mountain municipalities**: DATAR, Loi Montagne classification -- https://www.data.gouv.fr/datasets/communes-de-montagne-30383014
- **Financial health score**: AFL (Agence France Locale), proprietary banking formula combining several financial ratios to assess municipal fiscal soundness.

### Geographic Data (required for map figure only)
- **Municipal boundaries**: `geo_commune_2022.shp` -- https://www.data.gouv.fr/datasets/decoupage-administratif-communal-francais-issu-d-openstreetmap
- **National boundaries**: `fr.shp` — available from the same source

---

## Variable Dictionary

#### Identifiers
| Variable | Description |
|----------|-------------|
| `cod_commune` | Municipality identifier (5-digit INSEE code) |
| `year` | Year |
| `inom` | Municipality name |
| `dep` | Department code (2 digits) |
| `reg` | Region code |
| `pop1` | Population (inhabitants) |
| `nomsst2_cat` | Intercommunality type |

#### Current account (section de fonctionnement)
| Variable | Description | Unit |
|----------|-------------|------|
| `fprod` | Current revenues | €/inhab |
| `fcharge` | Current expenditures | €/inhab |
| `fperso` | Staff costs | €/inhab |
| `fachat` | Purchases and external charges | €/inhab |
| `ffin` | Financial charges | €/inhab |
| `fsubv` | Operating subsidies paid | €/inhab |
| `fdgf` | General decentralization grant (DGF) | €/inhab |
| `fcaf` | Self-financing capacity (CAF) | €/inhab |
| `fimpo1` | Property tax revenues (taxe foncière) | €/inhab |
| `fimpo2` | Housing tax revenues (taxe d'habitation) | €/inhab |

#### Investment account (section d'investissement)
| Variable | Description | Unit |
|----------|-------------|------|
| `frecinv` | Investment revenues | €/inhab |
| `femp` | New borrowings | €/inhab |
| `fsubr` | Investment grants received | €/inhab |
| `fdepinv` | Investment expenditures | €/inhab |
| `fequip` | Equipment expenditures | €/inhab |
| `fremb` | Debt repayments | €/inhab |
| `fdette` | Outstanding debt stock | €/inhab |
| `fannu` | Debt annuity | €/inhab |

#### Property tax (taxe foncière sur les propriétés bâties)
| Variable | Description | Unit |
|----------|-------------|------|
| `fbfb` | Tax base | €/inhab |
| `fbfbexod` | Tax base (exonerated portion) | €/inhab |
| `fpfb` | Tax revenues | €/inhab |
| `tfb` | Voted tax rate | % |

#### Housing tax (taxe d'habitation)
| Variable | Description | Unit |
|----------|-------------|------|
| `fbth` | Tax base | €/inhab |
| `fbthexod` | Tax base (exonerated portion) | €/inhab |
| `fpth` | Tax revenues | €/inhab |
| `tth` | Voted tax rate | % |

#### Business tax (taxe professionnelle / CFE post-2010)
| Variable | Description | Unit |
|----------|-------------|------|
| `fbtp` | Tax base | €/inhab |
| `fptp` | Tax revenues | €/inhab |
| `ttp` | Voted tax rate | % |

#### Aggregated variables
| Variable | Description | Unit |
|----------|-------------|------|
| `totalex` | Total expenditures (current + investment) | €/inhab |
| `totalgrant` | Total grants (DGF + investment grants) | €/inhab |
| `totalrev` | Total revenues (current + investment) | €/inhab |
| `totaltax` | Total tax revenues (foncière + habitation) | €/inhab |
| `debt` | Outstanding debt stock (= fdette) | €/inhab |

#### IHS-transformed variables
All budget variables are also provided in inverse hyperbolic sine (IHS) transformation, prefixed with `h` (e.g., `hdepinv`, `hdepf`, `hdebt`, `htax`, `hfbfb`, etc.). These are the outcome variables used in the estimations.

#### Socioeconomic controls
| Variable | Description | Source |
|----------|-------------|--------|
| `MEDREV` | Median household income | INSEE Filosofi |
| `MEDREV_2000` | Median household income in 2000 (time-invariant) | INSEE Filosofi |
| `total_pop` | Total population | INSEE |
| `pop_20` | Population under 20 | INSEE |
| `pop_65` | Population over 65 | INSEE |

#### Geographic controls
| Variable | Description |
|----------|-------------|
| `AAV2020` | Urban area code (Aires d'attraction des villes 2020) |
| `LIBAAV2020` | Urban area name |
| `montagne` | Mountain municipality (dummy) |
| `littoral_clean` | Coastal municipality (dummy) |
| `DENS` | Population density category (1 = urban, 7 = rural) |

#### Heterogeneity variables
| Variable | Description |
|----------|-------------|
| `afl_dummy` | Financial health split: 0 = healthy (AFL score below 2000 median), 1 = distressed |
| `rich_dummy` | Income split: 0 = low income (below 2000 median), 1 = high income |

---

### `catnat_gaspar.csv`
*One observation per disaster event. Source: GASPAR database, French Ministry of Environment.*

| Variable | Description |
|----------|-------------|
| `cod_commune` | Municipality identifier |
| `dat_deb` | Start date of the disaster |
| `dat_fin` | End date of the disaster |
| `num_risque_jo` | Disaster type code (official Journal Officiel classification) |
| `lib_risque_jo` | Disaster type label |
| `lib_commune` | Municipality name |
