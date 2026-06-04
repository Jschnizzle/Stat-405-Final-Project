library(readr)
library(dplyr)
library(ggplot2)
library(tidyr)

# 1. Load the data
df <- read_csv("combined_yield_ratings.csv")

# 2. Filter for wheat and reshape the data
df_long <- df %>%
  # Keep ONLY wheat data
  filter(crop == "wheat") %>%
  
  # Filter for major genres to keep the plot readable
  # (Feel free to add/remove genres from this list)
  filter(genres %in% c("Action", "Comedy", "Drama", "Documentary", "Horror", "Sci-Fi")) %>%
  
  # Pivot the two metrics into a single column
  pivot_longer(
    cols = c(net_change, mean_ratings),
    names_to = "metric",
    values_to = "value"
  ) %>%
  
  # Clean up metric names for the row labels
  mutate(metric = recode(metric, 
                         "net_change" = "Wheat Net Change", 
                         "mean_ratings" = "Mean Movie Rating"))

# 3. Create the multi-panel plot
p = ggplot(df_long, aes(x = year, y = value, group = genres)) +
  # Using 'linewidth' to prevent warnings, and a fixed color since there is only 1 crop
  geom_line(linewidth = 0.8, color = "darkgoldenrod", alpha = 0.8) + 
  geom_point(size = 1.2, color = "darkgoldenrod", alpha = 0.6) +
  
  # Separate metrics vertically and genres horizontally
  facet_grid(metric ~ genres, scales = "free_y") +
  
  theme_minimal(base_size = 12) +
  labs(
    title = "Wheat Net Change vs. Movie Ratings Over Time",
    subtitle = "Stratified by selected genres (1983 - 2016)",
    x = "Year",
    y = "Value (Scale depends on metric)"
  ) +
  theme(
    strip.text = element_text(face = "bold", size = 11),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5, color = "gray30")
  )

ggsave("wheat_vs_ratings_plot.png", plot = p, width = 10, height = 6, dpi = 300) 