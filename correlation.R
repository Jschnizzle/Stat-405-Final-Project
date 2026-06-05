library(dplyr)

combined_df = read.csv("combined_yield_ratings.csv")

wheat_correlation_results <- combined_df %>%
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


maize_correlation_results <- combined_df %>%
  # Filter to a specific crop (e.g., wheat) to avoid mixing crop behaviors
  filter(crop == "maize") %>%
  group_by(genres) %>%
  summarize(
    # Use use = "complete.obs" to ignore the NA values from 1983
    pearson_r  = cor(pct_change_yield, pct_change_rating, method = "pearson", use = "complete.obs"),
    spearman_r = cor(pct_change_yield, pct_change_rating, method = "spearman", use = "complete.obs"),
    .groups = "drop"
  ) %>%
  arrange(desc(abs(pearson_r))) # Sort by strongest correlation first


rice_correlation_results <- combined_df %>%
  # Filter to a specific crop (e.g., wheat) to avoid mixing crop behaviors
  filter(crop == "rice") %>%
  group_by(genres) %>%
  summarize(
    # Use use = "complete.obs" to ignore the NA values from 1983
    pearson_r  = cor(pct_change_yield, pct_change_rating, method = "pearson", use = "complete.obs"),
    spearman_r = cor(pct_change_yield, pct_change_rating, method = "spearman", use = "complete.obs"),
    .groups = "drop"
  ) %>%
  arrange(desc(abs(pearson_r))) # Sort by strongest correlation first


soybean_correlation_results <- combined_df %>%
  # Filter to a specific crop (e.g., wheat) to avoid mixing crop behaviors
  filter(crop == "soybean") %>%
  group_by(genres) %>%
  summarize(
    # Use use = "complete.obs" to ignore the NA values from 1983
    pearson_r  = cor(pct_change_yield, pct_change_rating, method = "pearson", use = "complete.obs"),
    spearman_r = cor(pct_change_yield, pct_change_rating, method = "spearman", use = "complete.obs"),
    .groups = "drop"
  ) %>%
  arrange(desc(abs(pearson_r))) # Sort by strongest correlation first





write.csv(wheat_correlation_results, "wheat_correlations.csv", row.names = FALSE)
write.csv(rice_correlation_results, "rice_correlations.csv", row.names = FALSE)
write.csv(soybean_correlation_results, "soybean_correlations.csv", row.names = FALSE)
write.csv(maize_correlation_results, "maize_correlations.csv", row.names = FALSE)