# ============================================================
# STATS 405 — Global Crop Yields vs Movie Ratings
# Pipeline: IMDB Data Loading, Cleaning & Joining
# ============================================================

# install.packages("readr")
# install.packages("data.table")

library(readr)
library(tidyverse)
library(data.table)
library(janitor)

# ------------------------------------------------------------
# 1. Read the IMDB data
# ------------------------------------------------------------
# Update these paths to wherever your .tsv files live
base_path <- "/Users/sarthakmohindru/Downloads"

dt   <- fread(file.path(base_path, "title.akas.tsv"),    sep = "\t", na.strings = "\\N", quote = "")
dt_1 <- fread(file.path(base_path, "title.basics.tsv"),  sep = "\t", na.strings = "\\N", quote = "")
dt_2 <- fread(file.path(base_path, "title.ratings.tsv"), sep = "\t", na.strings = "\\N", quote = "")

# Convert to data frames and free the data.tables
title_akas   <- as.data.frame(dt);   rm(dt)
title_basics  <- as.data.frame(dt_1); rm(dt_1)
ratings       <- as.data.frame(dt_2); rm(dt_2)
gc()

# ------------------------------------------------------------
# 2. Clean \N nulls + fix types upfront (before any joins)
# ------------------------------------------------------------
title_basics <- title_basics |>
  filter(!is.na(startYear), !is.na(genres)) |>
  mutate(
    startYear      = as.integer(startYear),
    runtimeMinutes = as.integer(runtimeMinutes)
  )

ratings <- ratings |>
  mutate(
    averageRating = as.numeric(averageRating),
    numVotes      = as.integer(numVotes)
  )

# ------------------------------------------------------------
# 3. Identify country of origin via region count heuristic
# ------------------------------------------------------------
# IMDB doesn't have an explicit "production country" field.
# Instead, we use distribution footprint as a proxy:
#   - Count how many distinct regions each movie appears in
#   - Movies in <= 3 regions are almost certainly domestic productions
#   - Their region(s) reliably indicate country of origin
# NOTE: title_akas uses "titleId" instead of "tconst"

target_countries <- c("US", "IN", "BR", "CN", "JP", "DE", "FR", "NG", "KR", "MX")

origin <- title_akas |>
  filter(!is.na(region)) |>
  group_by(titleId) |>
  mutate(n_regions = n_distinct(region)) |>
  ungroup() |>
  filter(
    n_regions <= 3,                      # domestic productions only
    region %in% target_countries         # keep target countries
  ) |>
  distinct(titleId, region) |>           # one row per movie-country
  select(tconst = titleId, region)

gc()

# ------------------------------------------------------------
# 4. Filter basics to movies only
# ------------------------------------------------------------
movies <- title_basics |>
  filter(titleType == "movie") |>
  select(tconst, primaryTitle, startYear, runtimeMinutes, genres)
# Think about adding a start year filter here
# ------------------------------------------------------------
# 5. Join: origin -> movies -> ratings
# ------------------------------------------------------------
# inner_join throughout — we only want movies that have:
#   (a) a known country of origin (domestic production)
#   (b) at least one rating
df <- origin |>
  inner_join(movies, by = "tconst") |>
  inner_join(ratings, by = "tconst")

gc()

# ------------------------------------------------------------
# 6. Min vote threshold to drop obscure/unreliable ratings
# ------------------------------------------------------------
df <- df |>
  filter(numVotes >= 500)

# ------------------------------------------------------------
# 7. Aggregate: one row per country-year
# ------------------------------------------------------------
country_year <- df |>
  group_by(region, startYear) |>
  summarise(
    avg_rating    = mean(averageRating, na.rm = TRUE),
    weighted_avg_rating = weighted.mean(averageRating, numVotes, na.rm = TRUE),
    median_rating = median(averageRating, na.rm = TRUE),
    film_count    = n(),
    avg_votes     = mean(numVotes, na.rm = TRUE),
    .groups       = "drop"
  ) |>
  arrange(region, startYear)

# ------------------------------------------------------------
# 8. Quick sanity check
# ------------------------------------------------------------
cat("Domestic movies with ratings (500+ votes):", nrow(df), "\n")
cat("Country-year rows:", nrow(country_year), "\n\n")

# Per-country breakdown
df |> count(region, sort = TRUE) |> print()

# Preview
head(country_year, 20)

# ============================================================
# FAOSTAT: Load crop yield data and join to IMDB
# ============================================================

# ------------------------------------------------------------
# 9. Load FAOSTAT data
# ------------------------------------------------------------
fao_raw <- read_csv(file.path(base_path, "FAOSTAT_data_en_6-5-2026.csv"))

# Check column names (FAOSTAT formatting can vary)
cat("FAOSTAT columns:\n")
colnames(fao_raw) |> print()

# ------------------------------------------------------------
# 10. Clean FAOSTAT + map country names to ISO codes
# ------------------------------------------------------------
country_map <- tibble(
  region   = c("US", "IN", "BR", "CN", "JP", "DE", "FR", "NG", "KR", "MX"),
  fao_name = c("United States of America", "India", "Brazil",
               "China", "Japan", "Germany",
               "France", "Nigeria", "Democratic People's Republic of Korea", "Mexico")
)

# FAOSTAT typically has: Area, Item, Element, Year, Unit, Value
# Yield is usually in hg/ha (hectograms per hectare)
# Convert to tonnes/ha by dividing by 10,000
fao <- fao_raw |>
  filter(Element == "Yield") |>
  select(fao_name = Area, crop = Item, Year, yield_hg_ha = Value) |>
  mutate(yield_t_ha = yield_hg_ha) |>
  inner_join(country_map, by = "fao_name") |>
  select(region, year = Year, crop, yield_hg_ha, yield_t_ha)

cat("\nFAOSTAT rows after cleaning:", nrow(fao), "\n")
cat("Year range:", min(fao$year), "-", max(fao$year), "\n")
cat("Crops:", unique(fao$crop) |> paste(collapse = ", "), "\n\n")

# ------------------------------------------------------------
# 11. Join IMDB country-year with FAOSTAT
# ------------------------------------------------------------
# Wide format: one column per crop yield
fao_wide <- fao |>
  select(region, year, crop, yield_t_ha) |>
  pivot_wider(
    names_from  = crop,
    values_from = yield_t_ha,
    names_prefix = "yield_"
  ) |>
  janitor::clean_names()   # makes column names lowercase + snake_case

# Final join: IMDB country-year + crop yields
final <- country_year |>
  inner_join(fao_wide, by = c("region" = "region", "startYear" = "year"))

# ------------------------------------------------------------
# 12. Final sanity check
# ------------------------------------------------------------
cat("Final analysis table:", nrow(final), "rows\n")
cat("Year range:", min(final$startYear), "-", max(final$startYear), "\n")
cat("Countries:", n_distinct(final$region), "\n\n")

final |> count(region, sort = TRUE) |> print()

# Preview
head(final, 20)