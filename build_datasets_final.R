library(tidyverse)
library(dplyr)
library(tidyr)


crop_yields <- read.csv("yield_by_crop_year.csv")

# Removes 1981 since incomplete data. Removes secondary crop categories.
crop_yields <- crop_yields %>% 
  dplyr::filter(year != "1981" & 
  crop != "maize_major" & crop != "maize_second" & 
  crop != "rice_major" & crop != "rice_second" & 
  crop != "wheat_spring" & crop != "wheat_winter")

#Calculate the net change in crop yields
crop_yields <- crop_yields %>%
  arrange(crop, year) %>% 
  group_by(crop) %>% 
  mutate(pct_change_yield = (yield - lag(yield)) / lag(yield) * 100) %>% 
  ungroup()

#Remove the now NA values for 1982
crop_yields <- crop_yields %>% 
  dplyr::filter(year != "1982")

write.csv(crop_yields, "net_change_crop_yields_by_year.csv", row.names = FALSE)

movie_ratings <- read.csv("movie_yearly_ratings.csv")

movie_ratings <- movie_ratings %>% 
    mutate(startYear = as.integer(unlist(startYear))) %>%

    dplyr::filter(startYear > 1982 & startYear < 2017)

low_count = movie_ratings %>% 
    dplyr::filter(count <= 50)

#By inspection, we can see that the genres with low counts are game show, news, and western

target_genres <- c("Game-Show", "News", "Western")

combined_data <- movie_ratings %>%
  
  mutate(genres = ifelse(genres %in% target_genres, "Other", genres)) %>%
  
  
  group_by(startYear, genres) %>%
  
  
  summarise(
    # Formula for weighted average: sum(rating * count) / sum(count)
    mean_ratings = sum(mean_ratings * count, na.rm = TRUE) / sum(count, na.rm = TRUE),
    
    count = sum(count, na.rm = TRUE),
    
    .groups = "drop" # Keeps df clean 
  )


combined_data = combined_data %>% 
    rename(year = startYear)

combined_data <- combined_data %>%
  arrange(genres, year) %>%
  group_by(genres) %>%
  mutate(pct_change_rating = (mean_ratings - lag(mean_ratings)) / lag(mean_ratings) * 100) %>%
  ungroup()

write.csv(combined_data, "updated_movie_yearly_ratings.csv", row.names = FALSE)

combined_df <- left_join(crop_yields, combined_data, by = "year", relationship="many-to-many")
write.csv(combined_df, "combined_yield_ratings.csv", row.names = FALSE)
