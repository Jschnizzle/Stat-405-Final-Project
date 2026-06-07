# Run this in the SAME RStudio session where you just ran Analysis 1
# (so the analysis objects exist). Saves plots as PNGs + prints key tables.

out <- "/Users/sarthakmohindru/Desktop/STATS 405-Final project_Sarthak"

# Comedy LOESS for every lag (same year, +1y, +2y)
lag_file <- c("Same year (Y vs Y)" = "a1_comedy_same.png",
              "Harvest leads by 1y" = "a1_comedy_lag1.png",
              "Harvest leads by 2y" = "a1_comedy_lag2.png")
for (lbl in levels(panel$lag_label)) {
  ggsave(file.path(out, lag_file[[lbl]]),
         plot_genre_vs_yield(panel, "Comedy", lbl),
         width = 11, height = 8.5, dpi = 110)
}

ggsave(file.path(out, "a1_heatmap.png"),
       p_cor_heatmap, width = 13, height = 5, dpi = 110)

ggsave(file.path(out, "a1_pattern.png"),
       p_pattern, width = 13, height = 5, dpi = 110)

cat("\n================ CROSS-COUNTRY PATTERN (the key table) ================\n")
print(genre_pattern, n = 40)

cat("\nSaved PNGs to the project folder.\n")
