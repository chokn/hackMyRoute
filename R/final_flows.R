# # # # # # # # #
# Flows to plot #
# # # # # # # # #

# # # # # # # # # # # # # # # # #
# Stage 1: manipulate the data  #
# # # # # # # # # # # # # # # # #

f <- read.csv("data/msoa-leeds-all-with-route.csv")
nrow(f)
# which cols do we want from f?
names(f) # id and last 4 are new

fl <- read.csv("data/msoa-flow-leeds-all.csv")
fl$lat_dest <- f$lat_dest
head(fl)
names(fl)

# flows to present
library("dplyr")
fl_present <- select(fl, Area.of.residence, Area.of.workplace, All.categories..Method.of.travel.to.work, Bicycle, lon_origin,  lat_origin, lon_dest, lat_dest, ecp, p_cycle, pc, dist)   # fl dataset to present
fl <- rename(fl_present, Origin = Area.of.residence, Destination = Area.of.workplace, Total = All.categories..Method.of.travel.to.work, clc = p_cycle, plc = pc)
names(fl_present)
# Test the datasets join-up
 fl$lon_dest[1:5] == f$lon_dest[1:5]
#  summary(fl$lon_dest == f$lon_dest)
#  summary(fl$lon_origin == f$lon_origin)
#  summary(fl$lat_origin == f$lat_origin)
#  summary(fl$lat_origin == f$lat_origin)

f <- f[c(1, 6:9)]
names(f)
ids <- f$id
f$id <- NULL

flows <- cbind(ids, fl, f)

# Is this the final df?
summary(flows$dist) # na - we kanye be doing with 0 dists
flows <- flows[flows$dist > 10, ]
summary(flows$dist)

head(flows) # yay we have the final data frame

flows <- flows[ flows$dist < 8000, ]
# write.csv(flows, "R/fixMyPath/flows.csv")

# points to lines
l <- vector("list", nrow(flows))
for(i in 1:nrow(flows)){
  x <- c(flows$lon_origin[i], flows$lon_dest[i])
  y <- c(flows$lat_origin[i], flows$lat_dest[i])
  l[[i]] <- Lines(list(Line(rbind(x, y))), as.character(i))
}

l <- SpatialLines(l)
l <- SpatialLinesDataFrame(l, data = flows, match.ID = F)
object.size(l) / 1000000
saveRDS(l, "R/fixMyPath/l.Rds")

# # # # # # # # # # # # #  #
# Extract the ones to plot #
# # # # # # # # # # # # #  #

# Intersting routes (top and bottom ecp, plc and clc)
head_tail <- rbind(flows[head(order(flows$ecp),10),], flows[tail(order(flows$ecp),10),])
head_tail <- rbind(head_tail, flows[head(order(flows$clc),10),], flows[head(order(flows$clc),10),])
head_tail <- rbind(head_tail, flows[head(order(flows$plc),10),], flows[head(order(flows$plc),10),])
head_tail <- unique(head_tail)

# How good is the estimate of cycling potential?
plot(flows$plc, flows$Bicycle)
cor(flows$plc, flows$Bicycle)


# Saving the routes
library(rgdal)
library("maptools")

al <- NULL
for(i in 1:nrow(head_tail)){
  rfile <- list.files(path = "local-data/", pattern = paste0("^", head_tail[i,]$ids, "-"), full.names = T)
  for(j in rfile){
    l <- readOGR(j, layer = "OGRGeoJSON")
    if(grepl("fast", j)){
      da <- rename(head_tail[i,], d = fastest_distance_in_m, t = fastest_time_in_s)
      l <- SpatialLinesDataFrame(l, data = select(da, d, t, ecp, clc, plc), match.ID = F)
      l$route <- "fast"
    }else{
      da <- rename(head_tail[i,], d = quietest_distance_in_m, t = quietest_time_in_s)
      l <- SpatialLinesDataFrame(l, data = select(da, d, t, ecp, clc, plc), match.ID = F)
      l$route <- "quiet"
    }
    row.names(l) = toString(j)
    if(is.null(al)) {
      al <- l
      row.names(al) = toString(i)
    }
    else al <- spRbind(al, l)
  }
}

# writeOGR(al, layer = "shape1", dsn = "/tmp/", driver = "ESRI Shapefile")
saveRDS(al, "R/fixMyPath/al.Rds")
