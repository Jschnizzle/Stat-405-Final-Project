library(readr)
library(dplyr)
library(ggplot2)
library(tidyr)

# 1. Load the freshly generated data
df <- read_csv("combined_yield_ratings.csv")

# 2. Filter for wheat and reshape the percentage columns
df_long <- df %>%
  # Keep ONLY wheat data (you can change this to "maize", "rice", or "soybean")
  filter(crop == "wheat") %>%
  
  # Pivot the two percentage columns into a single column for ggplot
  pivot_longer(
    cols = c(pct_change_yield, pct_change_rating),
    names_to = "metric",
    values_to = "value"
  ) %>%
  
  # Clean up metric names so they look beautiful in the chart legend
  mutate(metric = recode(metric, 
                         "pct_change_yield" = "Wheat Yield % Change", 
                         "pct_change_rating" = "Movie Rating % Change"))

# 3. Create the multi-panel grid plot (keeps all 24 genres)
p_all_pct <- ggplot(df_long, aes(x = year, y = value, color = metric, group = metric)) +
  # Using linewidth (not size) to keep the code warning-free
  geom_line(linewidth = 0.7, alpha = 0.8) + 
  geom_point(size = 1.0, alpha = 0.6) +
  
  # Organizes all 24 genres into a clean 4-column layout grid
  facet_wrap(~ genres, ncol = 4, scales = "fixed") + 
  
  # Custom color palette matching the theme
  scale_color_manual(values = c("Wheat Yield % Change" = "darkgoldenrod", 
                                "Movie Rating % Change" = "royalblue")) +
  
  theme_minimal(base_size = 11) + 
  labs(
    title = "Year-Over-Year Percentage Change: Wheat Yield vs. Movie Ratings",
    subtitle = "Comprehensive 24-Genre Analysis on a Shared Percentage Scale (1984 - 2016)",
    x = "Year",
    y = "Percentage Change (%)",
    color = "Metric"
  ) +
  theme(
    legend.position = "bottom",
    strip.text = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold", hjust = 0.5),
    plot.subtitle = element_text(hjust = 0.5, color = "gray30")
  )

# 4. Save with a wide, tall canvas size so the 24 timelines stretch out beautifully
ggsave("all_24_genres_percentage_comparison.png", plot = p_all_pct, width = 16, height = 16, dpi = 300)

cat("Success! Visualization saved as 'all_24_genres_percentage_comparison.png'\n")