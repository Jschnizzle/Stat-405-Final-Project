library(dplyr)

combined_df = read.csv("combined_yield_ratings.csv")

correlation_results <- combined_df %>%
  # Filter to a specific crop (e.g., wheat) to avoid mixing crop behaviors
  filter(crop == "wheat") %>%
  group_by(genres) %>%
  summarize(
    # Use use = "complete.obs" to ignore the NA values from 1983
    pearson_r  = cor(pct_change_yield, pct_change_rating, method = "pearson", use = "complete.obs"),
    spearman_r = cor(pct_change_yield, pct_change_rating, method = "spearman", use = "complete.obs"),
    .groups = "drop"
  ) %>%
  arrange(desc(abs(pearson_r))) # Sort by strongest correlation first





write.csv(correlation_results, "correlations.csv", row.names = FALSE)