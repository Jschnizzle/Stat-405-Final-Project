# Run in the SAME RStudio session after Analysis 2.
# Saves the figures as PNGs + prints the key tables to paste back.

out <- "/Users/sarthakmohindru/Desktop/STATS 405-Final project_Sarthak"

ggsave(file.path(out, "a2_map.png"),     p_map,     width = 12, height = 7,   dpi = 120)
ggsave(file.path(out, "a2_bar.png"),     p_bar,     width = 9,  height = 5.5, dpi = 120)
ggsave(file.path(out, "a2_time.png"),    p_time,    width = 10, height = 6,   dpi = 120)
ggsave(file.path(out, "a2_crop.png"),    p_crop,    width = 11, height = 7,   dpi = 120)
ggsave(file.path(out, "a2_profile.png"), p_profile, width = 10, height = 5.5, dpi = 120)
ggsave(file.path(out, "a2_volume.png"),  p_vol,     width = 9,  height = 6,   dpi = 120)

cat("\n================ GENRE DIVERSITY BY COUNTRY ================\n")
print(country_div)

cat("\n================ SIGNATURE (most dominant) GENRE PER COUNTRY ============\n")
print(signature)

cat("\n================ DIVERSITY TREND PER DECADE ================\n")
print(trend)

cat("\n================ CROSS-COUNTRY: diversity vs harvests ================\n")
print(crop_pattern)

cat("\nSaved 6 PNGs to the project folder.\n")
