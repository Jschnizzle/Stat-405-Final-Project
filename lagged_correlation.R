library(dplyr)
library(purrr)
library(ggplot2)

# Load data

df <- read.csv("combined_yield_ratings.csv")

max_lag <- 3

# Lagged correlation analysis

lagged_results <-
  df %>%
  group_by(crop, genres) %>%
  group_modify(~{
    
    x <- .x$pct_change_yield
    y <- .x$pct_change_rating
    
    map_dfr(-max_lag:max_lag, function(k){
      
      if(k < 0){
        
        x_shift <- x[1:(length(x)+k)]
        y_shift <- y[(1-k):length(y)]
        
      } else if(k > 0){
        
        x_shift <- x[(1+k):length(x)]
        y_shift <- y[1:(length(y)-k)]
        
      } else {
        
        x_shift <- x
        y_shift <- y
        
      }
      
      test <- cor.test(
        x_shift,
        y_shift,
        use = "complete.obs"
      )
      
      data.frame(
        lag = k,
        correlation = unname(test$estimate),
        p_value = test$p.value,
        n = sum(complete.cases(x_shift, y_shift))
      )
      
    })
    
  }) %>%
  ungroup()

# Export full results

write.csv(
  lagged_results,
  "lagged_correlations.csv",
  row.names = FALSE
)

# Significant lagged correlations

significant_results <-
  lagged_results %>%
  filter(p_value < 0.05) %>%
  arrange(p_value)

write.csv(
  significant_results,
  "significant_lagged_correlations.csv",
  row.names = FALSE
)

# Strongest lag by crop-genre pair

strongest_lags <-
  lagged_results %>%
  group_by(crop, genres) %>%
  slice_max(
    abs(correlation),
    n = 1,
    with_ties = FALSE
  ) %>%
  ungroup()

# Top 10 strongest lagged correlations

top10_absolute <-
  lagged_results %>%
  mutate(
    abs_corr = abs(correlation)
  ) %>%
  arrange(desc(abs_corr)) %>%
  slice_head(n = 10)

write.csv(
  top10_absolute,
  "top10_lagged_correlations.csv",
  row.names = FALSE
)

# Heatmap visualization

heatmap_plot <-
  ggplot(
    lagged_results,
    aes(
      x = lag,
      y = genres,
      fill = correlation
    )
  ) +
  geom_tile() +
  facet_wrap(~ crop) +
  scale_fill_gradient2() +
  theme_minimal()

heatmap_plot

ggsave(
  "lagged_correlation_heatmap.png",
  plot = heatmap_plot,
  width = 12,
  height = 8,
  dpi = 300
)