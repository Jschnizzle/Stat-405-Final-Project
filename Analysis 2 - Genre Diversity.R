# ============================================================
# STATS 405 — Analysis 2
# Genre Diversity (Shannon Entropy) across countries & vs harvests
# ============================================================
# Two questions:
#   (A) DESCRIPTIVE: which countries make the most genre-diverse cinema,
#       and how has diversity changed over time?  -> map, bar, time series
#   (B) CROP LINK: does a country make MORE diverse films after good
#       harvests? (entropy change vs staple-crop yield growth)
#
# Shannon entropy H = -sum(p_i * ln p_i), where p_i is the share of a
# country-year's genre tags falling in genre i. Higher H = more even spread
# across many genres; lower H = output concentrated in a few genres.
#
# Reuses the same data hygiene as Analysis 1: df_genre (>=50 votes),
# >=20 films per country-year, yields from fao_wide, hand-picked staples,
# yield as year-over-year % growth (detrended).
#
# Run imdb_crop_pipeline.R first (needs origin, movies, ratings, fao_wide).
# Needs the `maps` package for the world map: install.packages("maps")
# ============================================================

library(tidyverse)

VOTE_FLOOR <- 50
MIN_FILMS  <- 20
LAGS       <- c(0, 2)   # same-year and a 2-year lag for the crop test

country_labels <- c(
  "US" = "United States", "IN" = "India", "BR" = "Brazil",
  "CN" = "China", "JP" = "Japan", "DE" = "Germany",
  "FR" = "France", "NG" = "Nigeria", "KR" = "South Korea", "MX" = "Mexico"
)
lag_label_for <- function(L) if (L == 0) "Same year (Y vs Y)" else paste0("Harvest leads by ", L, "y")
shannon <- function(p) { p <- p[p > 0]; -sum(p * log(p)) }

# ------------------------------------------------------------
# 0. Genre film set (>=50 votes), and films per country-year
# ------------------------------------------------------------
df_genre <- origin |>
  inner_join(movies,  by = "tconst") |>
  inner_join(ratings, by = "tconst") |>
  filter(numVotes >= VOTE_FLOOR)

films_py <- df_genre |>
  distinct(region, startYear, tconst) |>
  count(region, startYear, name = "n_films")

# ------------------------------------------------------------
# 1. Shannon entropy of the genre mix, per country-year
# ------------------------------------------------------------
genre_tags <- df_genre |>
  separate_rows(genres, sep = ",") |>
  filter(genres != "" & !is.na(genres))

diversity <- genre_tags |>
  count(region, startYear, genres, name = "tag_n") |>
  group_by(region, startYear) |>
  mutate(p = tag_n / sum(tag_n)) |>
  summarise(entropy = shannon(p), richness = n(), .groups = "drop") |>
  mutate(evenness = if_else(richness > 1, entropy / log(richness), 0)) |>
  left_join(films_py, by = c("region", "startYear")) |>
  filter(n_films >= MIN_FILMS) |>                      # same noise floor as A1
  mutate(country = country_labels[region])

# Average diversity per country (only countries with several years)
country_div <- diversity |>
  group_by(country, region) |>
  summarise(mean_entropy = mean(entropy),
            mean_evenness = mean(evenness),
            mean_richness = mean(richness),
            years = n(), .groups = "drop") |>
  filter(years >= 5) |>
  arrange(desc(mean_entropy))

cat("Average genre diversity (Shannon entropy) by country:\n")
print(country_div)

# ------------------------------------------------------------
# 2a. WORLD MAP of average genre diversity  (the cool one)
# ------------------------------------------------------------
# map_data names match ours except USA; everything else is grey (no data).
world <- map_data("world")

map_div <- country_div |>
  mutate(map_region = if_else(country == "United States", "USA", country))

world_div <- world |>
  left_join(map_div, by = c("region" = "map_region"))

p_map <- ggplot(world_div, aes(long, lat, group = group, fill = mean_entropy)) +
  geom_polygon(color = "grey80", linewidth = 0.1) +
  scale_fill_viridis_c(option = "plasma", na.value = "grey92",
                       name = "Genre\nentropy") +
  coord_quickmap() +
  labs(
    title    = "Cinematic Genre Diversity by Country",
    subtitle = "Shannon entropy of the genre mix (avg across years) — 8 major film producers"
  ) +
  theme_void(base_size = 13) +
  theme(plot.title = element_text(face = "bold"),
        legend.position = c(0.08, 0.35))

print(p_map)

# ------------------------------------------------------------
# 2b. BAR CHART (the precise read of the 8 values)
# ------------------------------------------------------------
p_bar <- ggplot(country_div,
                aes(x = reorder(country, mean_entropy), y = mean_entropy,
                    fill = mean_entropy)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = round(mean_entropy, 2)), hjust = -0.15, size = 3.5) +
  scale_fill_viridis_c(option = "plasma", guide = "none") +
  coord_flip() +
  expand_limits(y = max(country_div$mean_entropy) * 1.08) +
  labs(title = "Genre Diversity by Country",
       subtitle = "Average Shannon entropy of the genre mix",
       x = NULL, y = "Shannon entropy (higher = more diverse)") +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold"), panel.grid.major.y = element_blank())

print(p_bar)

# ------------------------------------------------------------
# 2c. DIVERSITY OVER TIME
# ------------------------------------------------------------
p_time <- diversity |>
  semi_join(country_div, by = "country") |>
  ggplot(aes(startYear, entropy, color = country)) +
  geom_line(linewidth = 0.8, alpha = 0.85) +
  labs(title = "Genre Diversity Over Time",
       subtitle = "Shannon entropy of each country's genre mix, by year",
       x = "Year", y = "Shannon entropy", color = "Country") +
  theme_minimal(base_size = 13) +
  theme(plot.title = element_text(face = "bold"))

print(p_time)

# ------------------------------------------------------------
# 3. CROP LINK: does diversity rise after good harvests?
# ------------------------------------------------------------
# Staple yield growth (same hand-picked staples + detrending as Analysis 1)
yield_cols <- colnames(fao_wide) |> str_subset("^yield_")
yield_long <- fao_wide |>
  pivot_longer(all_of(yield_cols), names_to = "crop", values_to = "yield") |>
  filter(!is.na(yield)) |>
  mutate(crop = str_remove(crop, "^yield_") |> str_to_title(),
         country = country_labels[region])

staple_crop <- tibble::tribble(
  ~country,          ~crop,
  "United States",   "Maize_corn", "India", "Rice", "Brazil", "Soya_beans",
  "China", "Rice", "Japan", "Rice", "Germany", "Wheat", "France", "Wheat",
  "Nigeria", "Maize_corn", "South Korea", "Rice", "Mexico", "Maize_corn"
)

staple_yield <- yield_long |>
  semi_join(staple_crop, by = c("country", "crop")) |>
  select(country, year, yield) |>
  arrange(country, year) |>
  group_by(country) |>
  mutate(yield_growth = (yield - lag(yield)) / lag(yield)) |>
  ungroup() |>
  filter(!is.na(yield_growth))

# Year-over-year change in diversity (detrended, same as yield)
ent_change <- diversity |>
  arrange(country, startYear) |>
  group_by(country) |>
  mutate(entropy_change = entropy - lag(entropy)) |>
  ungroup() |>
  filter(!is.na(entropy_change))

crop_test <- map_dfr(LAGS, function(L) {
  ent_change |>
    inner_join(staple_yield |> transmute(country, startYear = year + L, yield_growth),
               by = c("country", "startYear")) |>
    mutate(lag_label = lag_label_for(L))
})

# Per-country correlation, then the cross-country pattern (like A1)
crop_cor <- crop_test |>
  group_by(lag_label, country) |>
  summarise(r = cor(entropy_change, yield_growth, use = "complete.obs"),
            n_years = n(), .groups = "drop") |>
  filter(n_years >= 5)

cat("\n--- Diversity change vs staple yield growth, per country ---\n")
crop_cor |> arrange(lag_label, desc(r)) |> print(n = 40)

crop_pattern <- crop_cor |>
  group_by(lag_label) |>
  summarise(n_countries = n(),
            mean_r = mean(r),
            n_pos  = sum(r > 0),
            n_neg  = sum(r < 0),
            p_ttest = if (n() >= 3) t.test(r)$p.value else NA_real_,
            .groups = "drop")

cat("\n--- CROSS-COUNTRY: does genre diversity track harvests? ---\n")
print(crop_pattern)

# Scatter: diversity change vs yield growth, faceted by country (same-year)
p_crop <- crop_test |>
  filter(lag_label == "Same year (Y vs Y)") |>
  ggplot(aes(yield_growth, entropy_change)) +
  geom_point(alpha = 0.55, size = 1.8, color = "#2c3e50") +
  geom_smooth(method = "lm", se = TRUE, color = "#e67e22", linewidth = 0.8) +
  geom_hline(yintercept = 0, linetype = "dotted", alpha = 0.5) +
  geom_vline(xintercept = 0, linetype = "dotted", alpha = 0.5) +
  facet_wrap(~ country, scales = "free", ncol = 3) +
  scale_x_continuous(labels = scales::percent) +
  labs(title = "Genre Diversity Change vs Staple Crop Yield Growth",
       subtitle = "Same year | each point = one year",
       x = "Staple crop yield growth (YoY)", y = "Change in genre entropy") +
  theme_minimal(base_size = 12) +
  theme(strip.text = element_text(face = "bold"))

print(p_crop)

# ============================================================
# 4. EXTRA EDA on genre diversity
# ============================================================

# --- 4a. Genre PROFILE: each country's genre "fingerprint" -------------------
# Explains WHY the entropy ranking looks the way it does: low-diversity
# countries concentrate their output in a few genres.
genre_profile <- genre_tags |>
  count(region, genres, name = "tag_n") |>
  group_by(region) |>
  mutate(share = tag_n / sum(tag_n), country = country_labels[region]) |>
  ungroup() |>
  semi_join(country_div, by = "country")

ent_order  <- country_div |> arrange(mean_entropy) |> pull(country)   # low -> high
prof_genres <- genre_profile |>
  group_by(genres) |> summarise(s = sum(tag_n), .groups = "drop") |>
  slice_max(s, n = 12) |> pull(genres)

p_profile <- genre_profile |>
  filter(genres %in% prof_genres) |>
  mutate(country = factor(country, levels = ent_order)) |>
  ggplot(aes(x = reorder(genres, -share, FUN = sum), y = country, fill = share)) +
  geom_tile(color = "white", linewidth = 0.4) +
  geom_text(aes(label = scales::percent(share, accuracy = 1)), size = 2.5) +
  scale_fill_viridis_c(option = "mako", direction = -1,
                       labels = scales::percent, name = "Share") +
  labs(title = "Genre Profile by Country",
       subtitle = "Share of each country's genre tags (countries ordered low -> high diversity)",
       x = "Genre", y = NULL) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        axis.text.y = element_text(face = "bold"), panel.grid = element_blank())
print(p_profile)

# Each country's single most dominant genre (its "signature")
signature <- genre_profile |>
  group_by(country) |> slice_max(share, n = 1) |> ungroup() |>
  transmute(country, signature_genre = genres, top_genre_share = share) |>
  arrange(desc(top_genre_share))
cat("\n--- Each country's most dominant genre (higher share = more concentrated) ---\n")
print(signature)

# --- 4b. Is cinema getting more genre-diverse over time? ----------------------
trend <- diversity |>
  group_by(country) |>
  summarise(slope_per_decade = coef(lm(entropy ~ startYear))[["startYear"]] * 10,
            years = n(), .groups = "drop") |>
  arrange(desc(slope_per_decade))
cat("\n--- Change in genre diversity per decade (entropy slope x 10) ---\n")
print(trend)

# --- 4c. Confound check: is diversity just a proxy for film count? ------------
r_cy <- cor(diversity$entropy, diversity$n_films, use = "complete.obs")
country_vol <- diversity |>
  group_by(country) |>
  summarise(mean_entropy = mean(entropy), total_films = sum(n_films), .groups = "drop")
r_ct <- cor(country_vol$mean_entropy, country_vol$total_films)
cat(sprintf("\nEntropy vs film count:  country-year r = %.2f  |  country-level r = %.2f\n",
            r_cy, r_ct))

p_vol <- ggplot(diversity, aes(n_films, entropy)) +
  geom_point(aes(color = country), alpha = 0.5, size = 1.6) +
  geom_smooth(method = "lm", se = TRUE, color = "black", linewidth = 0.7) +
  scale_x_log10() +
  labs(title = "Diversity vs Film Volume (confound check)",
       subtitle = sprintf("Country-year entropy vs #films (log scale), r = %.2f", r_cy),
       x = "Films in country-year (log scale)", y = "Shannon entropy", color = "Country") +
  theme_minimal(base_size = 12)
print(p_vol)
