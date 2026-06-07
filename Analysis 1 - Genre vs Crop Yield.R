# ============================================================
# STATS 405 — Analysis 1
# Genre Share vs Staple Crop Yield Growth
# ============================================================
# Question: Does a country's genre mix shift with how good or bad
#           the harvest was that year?
#   - Bad crop years  -> more comedies (escapism)?
#   - Good crop years  -> more dramas?
#   - Poor harvests    -> more action?
#
# Design choices:
#   - Uses a LOW-vote film set (df_genre, >=50 votes). Genre tags don't
#     need reliable ratings, so the pipeline's 500-vote floor needlessly
#     starved the data (it left only the US). 50 votes recovers ~8 countries.
#   - STAPLE crop = each country's real dominant crop, HAND-PICKED from the
#     4 crops in the FAOSTAT export (Maize, Rice, Soybeans, Wheat). The old
#     "highest yield/ha" rule mislabeled most countries as Rice.
#   - Yield measured as YEAR-OVER-YEAR % GROWTH (detrended, comparable)
#   - Yields come straight from `fao_wide` (full year coverage), NOT `final`
#     (which was limited to country-years that had 500-vote films).
#   - Genre share = fraction of a country-year's films tagged with a genre
#   - Drop country-years with < MIN_FILMS films (shares too noisy)
#   - FACET by country (no blending of different baselines)
#   - Tests SEVERAL lags: same year, +1y, +2y (films released in year Y were
#     made 1-3 years earlier, so the harvest "leads" the genre mix).
#
# Run imdb_crop_pipeline.R first so `origin`, `movies`, `ratings`,
# and `fao_wide` exist in memory.
# ============================================================

library(tidyverse)

VOTE_FLOOR   <- 50        # genre tags don't need reliable ratings -> low floor
MIN_FILMS    <- 20        # min films in a country-year to trust its genre shares
LAGS         <- c(0, 1, 2) # harvest leads genre by this many years (0 = same year)
TOP_N_GENRES <- 8         # how many genres to carry through

country_labels <- c(
  "US" = "United States", "IN" = "India", "BR" = "Brazil",
  "CN" = "China", "JP" = "Japan", "DE" = "Germany",
  "FR" = "France", "NG" = "Nigeria", "KR" = "South Korea", "MX" = "Mexico"
)

lag_label_for <- function(L) {
  if (L == 0) "Same year (Y vs Y)" else paste0("Harvest leads by ", L, "y")
}

# ------------------------------------------------------------
# 0. Build the genre film set (low vote floor) from pipeline pieces
# ------------------------------------------------------------
# `origin` already enforces domestic-origin (<=3 regions) + target countries.
df_genre <- origin |>
  inner_join(movies,  by = "tconst") |>
  inner_join(ratings, by = "tconst") |>
  filter(numVotes >= VOTE_FLOOR)

cat("Genre film set:", nrow(df_genre), "movie-country rows (>=", VOTE_FLOOR, "votes)\n")

# ------------------------------------------------------------
# 1. Staple crop per country + year-over-year % yield growth
#    (straight from FAOSTAT wide table = full year coverage)
# ------------------------------------------------------------
yield_cols <- colnames(fao_wide) |> str_subset("^yield_")

yield_long <- fao_wide |>
  pivot_longer(all_of(yield_cols), names_to = "crop", values_to = "yield") |>
  filter(!is.na(yield)) |>
  mutate(
    crop    = str_remove(crop, "^yield_") |> str_to_title(),
    country = country_labels[region]
  )

# Hand-picked dominant crop per country (from the 4 crops FAOSTAT gives us:
# Maize_corn, Rice, Soya_beans, Wheat). Chosen by real agricultural dominance,
# NOT by yield/ha (which over-picks rice).
staple_crop <- tibble::tribble(
  ~country,          ~crop,
  "United States",   "Maize_corn",
  "India",           "Rice",
  "Brazil",          "Soya_beans",
  "China",           "Rice",
  "Japan",           "Rice",
  "Germany",         "Wheat",
  "France",          "Wheat",
  "Nigeria",         "Maize_corn",
  "South Korea",     "Rice",
  "Mexico",          "Maize_corn"
)

cat("\nStaple crop per country (hand-picked):\n")
print(staple_crop)

# Sanity check: make sure every chosen staple actually exists in the data
missing_staple <- staple_crop |> anti_join(distinct(yield_long, country, crop),
                                           by = c("country", "crop"))
if (nrow(missing_staple) > 0) {
  cat("\nWARNING: these staple choices have no yield data:\n"); print(missing_staple)
}

# Staple yield series with % growth vs previous year
staple_yield <- yield_long |>
  semi_join(staple_crop, by = c("country", "crop")) |>
  select(country, region, year, crop, yield) |>
  arrange(country, year) |>
  group_by(country) |>
  mutate(yield_growth = (yield - lag(yield)) / lag(yield)) |>   # fractional growth
  ungroup() |>
  filter(!is.na(yield_growth))

# ------------------------------------------------------------
# 2. Genre share per country-year
# ------------------------------------------------------------
films_per_year <- df_genre |>
  distinct(region, startYear, tconst) |>
  count(region, startYear, name = "n_films")

top_genres <- df_genre |>
  separate_rows(genres, sep = ",") |>
  filter(genres != "" & !is.na(genres)) |>
  count(genres, sort = TRUE) |>
  head(TOP_N_GENRES) |>
  pull(genres)

cat("\nGenres carried through:", paste(top_genres, collapse = ", "), "\n")

genre_counts <- df_genre |>
  separate_rows(genres, sep = ",") |>
  filter(genres %in% top_genres) |>
  distinct(region, startYear, tconst, genres) |>
  count(region, startYear, genres, name = "n_genre")

genre_share <- genre_counts |>
  left_join(films_per_year, by = c("region", "startYear")) |>
  filter(n_films >= MIN_FILMS) |>                 # noise filter
  mutate(
    share   = n_genre / n_films,                  # fraction of films in this genre
    country = country_labels[region]
  )

cat("\nCountries surviving the >=", MIN_FILMS, "films filter:\n")
genre_share |> distinct(country, startYear) |> count(country, name = "usable_years") |>
  arrange(desc(usable_years)) |> print()

# ------------------------------------------------------------
# 3. Join genre share to staple yield growth, for EACH lag
# ------------------------------------------------------------
# Harvest of year (Y - L) vs films released in year Y, for L in LAGS.
panel <- map_dfr(LAGS, function(L) {
  genre_share |>
    inner_join(
      staple_yield |> transmute(country, startYear = year + L, yield_growth),
      by = c("country", "startYear")
    ) |>
    mutate(lag = L, lag_label = lag_label_for(L))
}) |>
  mutate(lag_label = factor(lag_label, levels = vapply(sort(LAGS), lag_label_for, character(1))))

# ------------------------------------------------------------
# 4. Faceted LOESS scatter — one genre at a time, all lags
# ------------------------------------------------------------
plot_genre_vs_yield <- function(data, genre, lag_label) {
  d <- data |> filter(genres == genre, lag_label == !!lag_label)
  if (nrow(d) == 0) return(invisible(NULL))

  ggplot(d, aes(x = yield_growth, y = share)) +
    geom_point(alpha = 0.55, size = 1.8, color = "#2c3e50") +
    geom_smooth(method = "loess", se = TRUE, color = "#e67e22", linewidth = 0.9) +
    geom_vline(xintercept = 0, linetype = "dotted", alpha = 0.5) +
    facet_wrap(~ country, scales = "free", ncol = 3) +
    scale_x_continuous(labels = scales::percent) +
    scale_y_continuous(labels = scales::percent) +
    labs(
      title    = paste0(genre, " Share vs Staple Crop Yield Growth"),
      subtitle = lag_label,
      x = "Staple crop yield growth (year-over-year)",
      y = paste0(genre, " share of films")
    ) +
    theme_minimal(base_size = 12) +
    theme(strip.text = element_text(face = "bold"))
}

# Comedy across all lags (swap "Comedy" for "Drama"/"Action" to test others)
for (lbl in levels(panel$lag_label)) print(plot_genre_vs_yield(panel, "Comedy", lbl))

# ------------------------------------------------------------
# 5. Correlation summary: every country x genre x lag
# ------------------------------------------------------------
cor_summary <- panel |>
  group_by(lag_label, country, genres) |>
  summarise(
    r       = cor(yield_growth, share, use = "complete.obs"),
    n_years = n(),
    .groups = "drop"
  ) |>
  filter(n_years >= 5)

cat("\n--- Strongest genre / yield-growth relationships (all lags) ---\n")
cor_summary |>
  mutate(abs_r = abs(r)) |>
  arrange(desc(abs_r)) |>
  select(lag_label, country, genres, r, n_years) |>
  head(25) |>
  print()

p_cor_heatmap <- ggplot(cor_summary, aes(x = genres, y = country, fill = r)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = round(r, 2)), size = 2.6) +
  scale_fill_gradient2(low = "#d73027", mid = "white", high = "#1a9850",
                       midpoint = 0, limits = c(-1, 1)) +
  facet_wrap(~ lag_label) +
  labs(
    title    = "Genre Share vs Staple Crop Yield Growth",
    subtitle = "Pearson r per country x genre, by lag",
    x = "Genre", y = "", fill = "r"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    axis.text.y = element_text(face = "bold"),
    panel.grid  = element_blank()
  )

print(p_cor_heatmap)

# ------------------------------------------------------------
# 6. CROSS-COUNTRY PATTERN TEST
# ------------------------------------------------------------
# The real question isn't "is there a strong cell somewhere" (with many
# correlations, a few big ones happen by chance). It's: does a genre move
# with yield growth *systematically across countries, in the same direction*?
#   mean_r        — average correlation across countries
#   n_pos / n_neg — how many countries share each sign (consistency)
#   p_ttest       — one-sample t-test: is mean r different from 0?
genre_pattern <- cor_summary |>
  group_by(lag_label, genres) |>
  summarise(
    n_countries = n(),
    mean_r      = mean(r),
    n_pos       = sum(r > 0),
    n_neg       = sum(r < 0),
    p_ttest     = if (n() >= 3) t.test(r)$p.value else NA_real_,
    .groups     = "drop"
  ) |>
  arrange(lag_label, desc(abs(mean_r)))

cat("\n--- CROSS-COUNTRY PATTERN: does any genre move with yield systematically? ---\n")
print(genre_pattern, n = 40)

# Dot plot: each country's r per genre, with the cross-country mean marked.
p_pattern <- ggplot(cor_summary, aes(x = r, y = genres)) +
  geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5) +
  geom_point(aes(size = n_years, color = country), alpha = 0.75) +
  stat_summary(fun = mean, geom = "point", shape = 124, size = 7, color = "black") +
  facet_wrap(~ lag_label) +
  scale_x_continuous(limits = c(-1, 1)) +
  labs(
    title    = "Genre x Yield-growth correlation across countries",
    subtitle = "Each dot = one country (size = #years). Black bar = cross-country mean.",
    x = "Pearson r", y = "Genre", size = "Years", color = "Country"
  ) +
  theme_minimal(base_size = 12)

print(p_pattern)
