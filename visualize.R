# Get an alphabetical list of all 24 genres
all_genres <- sort(unique(df_long$genres))

# Open a standard landscape letter-sized PDF document
pdf("all_24_genres_by_pages.pdf", width = 11, height = 8.5)

# Loop through the 24 genres in blocks of 6
for (i in seq(1, length(all_genres), by = 6)) {
  
  current_batch <- all_genres[i:min(i + 5, length(all_genres))]
  page_data <- df_long %>% filter(genres %in% current_batch)
  
  p_page <- ggplot(page_data, aes(x = year, y = value, color = metric, group = metric)) +
    geom_line(linewidth = 0.8, alpha = 0.8) + 
    geom_point(size = 1.2, alpha = 0.6) +
    
    # 6 panels per page (2 rows x 3 columns) makes every single line spacious and readable
    facet_wrap(~ genres, ncol = 3) + 
    
    scale_color_manual(values = c("Wheat Yield % Change" = "darkgoldenrod", 
                                  "Movie Rating % Change" = "royalblue")) +
    theme_minimal(base_size = 12) +
    labs(
      title = "Wheat Yield vs. Movie Ratings Percentage Change",
      subtitle = paste("Comprehensive Genre Analysis (Page", (i-1)/6 + 1, "of 4)"),
      x = "Year",
      y = "Percentage Change (%)",
      color = "Metric"
    ) +
    theme(
      legend.position = "bottom",
      strip.text = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    )
  
  print(p_page)
}

dev.off()