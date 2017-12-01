### Setup ----
library(tidyverse)
library(magrittr)
library(data.table)
dublin_csv <- fread("0_raw_data/attributes.csv")

# Melt data columns labelled as u00_00 ... u23_45 into one variable "Time" with value "Speed"
melted_dt <- data.table::melt(dublin_csv, measure.vars = grep("u\\d", names(dublin_csv), value = TRUE),
                  variable.name = "Time", value.name = "Speed")

# Convert Time variable into datetime representation
melted_dt <- melted_dt[, Time := as.POSIXct(Time, format = "u%H_%M")]
setkey(melted_dt, link_id, trav_dir, Time)

### Create traffic_intensity as speed / max(speed) ----

# Derive max(speed) by road link
max_speeds <- melted_dt[, .SD[which.max(Speed)], by=list(link_id, trav_dir)]
max_speeds <- max_speeds[, .(link_id, trav_dir, Time, Speed)]
names(max_speeds) <- c("link_id", "trav_dir", "Time of Max Speed", "Max Speed")

# Add traffic_intensity variable
melted_dt <- melted_dt[max_speeds]
melted_dt$traffic_intensity <- melted_dt[, .(traffic_intensity = Speed / `Max Speed`)]

# Save resulting CSVs
write_csv(melted_dt, "4_r_data_output/melted_dt.csv", na = "")
melted_dt_sample <- melted_dt[func_class <= 3 & trav_dir]
write_csv(melted_dt_sample, "4_r_data_output/melted_dt_sample.csv", na = "")

### Create time interval clusters ----
library(lubridate)
library(Ckmeans.1d.dp)
# Group all links together by 15min interval where func_class == 1
cluster_data <- melted_dt[func_class == 1, .(Minutes = hour(Time) * 60 + minute(Time), AvgSpeed = mean(Speed)), by = Time]
x <- cluster_data[["Minutes"]]
y <-
  cluster_data[["AvgSpeed"]] %>%
  head %>%
  {1 - (. - min(.)) / (max(.) - min(.))} %>% # Scale values to min = 1 and max = 0 such that low speeds represent high traffic
  {0.5 + 1.5 * .} # Spread by factor 1.5 and scale from 0.5 to 2

clusters <- Ckmeans.1d.dp(x = x, k = 6, y = y)
plot(clusters)

# Create dataframe from Ckmeans.1d.dp output clusters
cluster_output <- data.frame(Minutes = today() + minutes(x),
                             RelAvgSpeed = y,
                             Cluster = clusters$cluster)
# Manually add points after 11pm to Cluster 1
cluster_output$Cluster <- cluster_output %$%
  ifelse(x > 23 * 60, 1, Cluster)

write_csv(cluster_output, "4_r_data_output/cluster_output.csv", na = "")
