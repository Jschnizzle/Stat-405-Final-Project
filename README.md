# Movie Genres & Crop Yields — STATS 405 Final Project

Do a country's **movie genres** have anything to do with its **agriculture**? Using IMDB
film data and FAOSTAT crop yields for ten major producing countries, we test whether genre
patterns move with the harvest — and explore how national cinemas differ in genre diversity.

**Short answer:** crop yields show **no detectable relationship** with movie genres. But the
genre data tells an interesting story on its own (see Analysis 2).

---

## Data

| Source | Files | Notes |
|---|---|---|
| [IMDB datasets](https://datasets.imdbws.com/) | `title.akas.tsv`, `title.basics.tsv`, `title.ratings.tsv` | Titles, years, genres, ratings, votes (~3.7 GB) |
| [FAOSTAT](https://www.fao.org/faostat/en/#data/QCL) | `FAOSTAT_data_en_6-5-2026.csv` | Annual crop **yield**, 1961–2024 (Maize, Rice, Soybeans, Wheat) |

> **The raw data is not in this repo** (too large / licensing). Download it and update
> `base_path` at the top of `imdb_crop_pipeline.R` to point to your local copy.

---

## How to run

In R / RStudio:

```r
# 1. Install packages (once)
install.packages(c("tidyverse", "data.table", "janitor", "readr", "broom", "scales", "maps"))

# 2. Edit base_path in imdb_crop_pipeline.R to your data folder, then:
source("imdb_crop_pipeline.R")             # builds the data frames

# 3. Run either analysis
source("Analysis 1 - Genre vs Crop Yield.R")
source("Analysis 2 - Genre Diversity.R")

# 4. (optional) regenerate the saved figures
source("_save_outputs.R")    # Analysis 1 figures
source("_save_outputs2.R")   # Analysis 2 figures
```

---

## Repository structure

```
imdb_crop_pipeline.R              # loads + cleans + joins IMDB and FAOSTAT
Analysis 1 - Genre vs Crop Yield.R
Analysis 2 - Genre Diversity.R
Analysis 1 - Writeup.md           # full writeup + figures
Analysis 2 - Writeup.md           # full writeup + figures
a1_*.png, a2_*.png                # generated figures
_save_outputs*.R                  # helpers to export figures/tables
```

---

## Analysis 1 — Do genres track the harvest?

For each country-year we computed each genre's **share** of films and correlated it against
the **year-over-year % growth** of the country's staple-crop yield (detrended), across 8
countries and three time lags (same-year, +1y, +2y).

**Result: a clean null.** No genre's share moves systematically with crop yields. Individual
country-genre correlations reached as high as 0.68, but they **failed to replicate** across
countries or lags — exactly what chance produces across ~360 simultaneous comparisons. A good
illustration of the multiple-comparisons trap.

📄 Full details: [`Analysis 1 - Writeup.md`](Analysis%201%20-%20Writeup.md)

## Analysis 2 — How diverse is each country's cinema?

We measured the **Shannon entropy** of each country-year's genre mix, then explored it
descriptively and tested it against harvests.

**Findings:**
- **Diversity ranking:** Japan, the US, and Germany make the most genre-balanced cinema;
  France and China the most concentrated.
- **Why:** every national cinema is **Drama-led**, but low-diversity countries pour ~30–33%
  of output into Drama while high-diversity ones cap it near ~22% and spread the rest.
- **Diversity has risen over time** in 7 of 8 countries.
- **Crop link: null again** — diversity doesn't track the harvest either.

📄 Full details: [`Analysis 2 - Writeup.md`](Analysis%202%20-%20Writeup.md)

---

## Key methods & caveats

- **Country of origin** is inferred from IMDB distribution footprint (a film in ≤3 regions is
  treated as domestic) — IMDB has no production-country field.
- **Vote threshold:** ratings analyses use ≥500 votes; genre analyses use ≥50 (genre tags
  don't need reliable ratings, and the lower floor recovers 8 countries instead of just the US).
- **Yields** are detrended to year-over-year growth to avoid spurious long-term-trend correlation.
- **Known issues:** in `imdb_crop_pipeline.R`, the `KR` mapping points to North Korea (should be
  "Republic of Korea"), and the hg/ha→t/ha conversion is a no-op. Neither affects the conclusions
  (Korea is too data-thin to enter the analyses).
