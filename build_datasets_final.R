library(tidyverse) # Loads dplyr, tidyr, and ggplot2 all at once


crop_yields <- read.csv("yield_by_crop_year.csv")

crop_yields <- crop_yields %>% 
  filter(year != 1981 & 
         crop != "maize_major" & crop != "maize_second" & 
         crop != "rice_major" & crop != "rice_second" & 
         crop != "wheat_spring" & crop != "wheat_winter")

crop_yields <- crop_yields %>%
  arrange(crop, year) %>% 
  group_by(crop) %>% 
  mutate(pct_change_yield = (yield - lag(yield)) / lag(yield) * 100) %>% 
  ungroup()



movie_ratings <- read.csv("movie_yearly_ratings.csv")

combined_data <- movie_ratings %>% 
  # Flatten and convert startYear to integers safely
  mutate(startYear = as.integer(unlist(startYear))) %>%
  
  # CRITICAL FIX: Keep 1982 here so 1983 can calculate its percentage change!
  filter(startYear >= 1982 & startYear <= 2016) %>%
  
  # Group "low count" genres into "Other"
  mutate(genres = ifelse(genres %in% c("Game-Show", "News", "Western"), "Other", genres)) %>%
  
  # Calculate weighted average ratings per year/genre
  group_by(startYear, genres) %>%
  summarise(
    mean_ratings = sum(mean_ratings * count, na.rm = TRUE) / sum(count, na.rm = TRUE),
    count = sum(count, na.rm = TRUE),
    .groups = "drop" 
  ) %>%
  rename(year = startYear)

# Calculate the percentage change in movie ratings year-over-year per genre
combined_data <- combined_data %>%
  arrange(genres, year) %>%
  group_by(genres) %>%
  mutate(pct_change_rating = (mean_ratings - lag(mean_ratings)) / lag(mean_ratings) * 100) %>%
  ungroup()


combined_df <- left_join(crop_yields, combined_data, by = "year", relationship = "many-to-many") %>%
  filter(year != 1982) 

write.csv(crop_yields, "net_change_crop_yields_by_year.csv", row.names = FALSE)
write.csv(combined_data, "updated_movie_yearly_ratings.csv", row.names = FALSE)
write.csv(combined_df, "combined_yield_ratings.csv", row.names = FALSE)