ffu <- function(dummy) {
  querySummarydata <- dbGetQuery(con, "select count(query) as n_qry, substring (qrytext,1,150) as qrytext, min(run_minutes), max(run_minutes), avg(run_minutes), sum(run_minutes) as total,  max(query) as sample_qry
  from (
    select userid, query, trim(database) as database, trim(querytxt) as qrytext, starttime, endtime, datediff(minutes, starttime,endtime) as run_minutes
      from stl_query where userid <> 1
      and querytxt like '%select%'  )
  group by userid, qrytext
  order by 6 desc limit 35;")
  
  # We want to check the number of queries that are running and their average time
  
  queryTimeData <- dbGetQuery(con, "select userid, count(query) as queries, sum(elapsed) as time 
        from svl_qlog group by userid order by queries desc;")  
}

plotQueryDistribution <- function(con) {

  queryTimeHist <- dbGetQuery(con, "select userid, elapsed as time from svl_qlog;")
  shortQueries <- subset(queryTimeHist, queryTimeHist$time < 100000)
  longQueries <- subset(queryTimeHist, queryTimeHist$time >= 100000 & queryTimeHist$time <10000000)
  
  shortPlot <- ggplot(shortQueries, aes(x=time)) + 
    geom_histogram(aes(y=..density..),      # Histogram with density instead of count on y-axis
                   colour="black", fill="white") +
    geom_density(alpha=.2, fill="#FF6666") + # Overlay with transparent density plot
    scale_x_continuous(labels = comma)
  shortPercent <- length(shortQueries$time)/length(queryTimeHist$time)*100
  shortPlot <- shortPlot + annotate("text", label = sprintf("%.1f %%", shortPercent),
                                    x = Inf, hjust = 1, y = Inf, vjust = 2, color = "darkred")  +
    labs(title = "Query Time Distribution for short queries (<100ms)", x="Query elapsed time (microseconds)")
  
  longPlot <- ggplot(longQueries, aes(x=time/1000)) + 
    geom_histogram(aes(y=..density..),      # Histogram with density instead of count on y-axis
                   colour="black", fill="white") +
    geom_density(alpha=.2, fill="#FF6666") +  # Overlay with transparent density plot
    scale_x_continuous(labels = comma)
  longPercent <- length(longQueries$time)/length(queryTimeHist$time)*100
  longPlot <- longPlot + annotate("text", label = sprintf("%.1f %%", longPercent),
                                  x = Inf, hjust = 1, y = Inf, vjust = 2, color = "darkred")  +
    labs(title = "Query Time Distribution for long queries (>=100ms & <10s)", x="Query elapsed time (milliseconds)")
  multiplot(shortPlot, longPlot)
  
}

# Distribution of the queries along the days and hours

hourHeatMap <- function(con) {
  queryTimeScatter <- dbGetQuery(con, 
        "select 
              date_part(d, starttime) as day, 
              date_part(h, starttime) as hour, 
              count(query) as queries, 
              avg(elapsed/1000) as time
        from svl_qlog
        group by 1,2;")
  
  ggplot(queryTimeScatter, aes(x=hour, y=day)) +
    geom_point(aes(colour=time, size=queries), shape=19) +
    scale_colour_gradient(low="blue", high="red", labels = comma) +
    labs(title = "Query Distribution along the day", 
         x="Hour", y="Calander day", colour = "Avg. Time\n (ms)", size="#Queries")
  
}

# Analyzing queue time of the query to suggest better WLM settings

analyzeQueuePerServiceClass <- function (con) {
  # From: http://docs.aws.amazon.com/redshift/latest/dg/r_STL_WLM_QUERY.html
  serviceClassAvg <- dbGetQuery(con, "select service_class as svc_class, count(*),
    avg(total_queue_time) as avg_queue_time,
    avg(total_exec_time) as avg_exec_time
    from stl_wlm_query
    group by service_class
    order by service_class;")
  
  return (serviceClassAvg)
}

plotQueuePerServiceClass <- function (serviceClassAvgData) {
  require(reshape2)
  dfm <- melt(serviceClassAvgData[,c('svc_class', 'avg_queue_time', 'avg_exec_time')],id.vars = 1)
  tile <- ggplot(dfm, aes(x=factor(svc_class))) +
    geom_bar(aes(y=value/1000, fill=variable), stat='identity') +
    scale_y_sqrt(labels = comma) +
    labs(title = "Service Class Time Distribution", x="Service Class", y="Time in ms (SQRT Scale)")

  tile <- tile + geom_text(data=serviceClassAvgData, aes(x = factor(svc_class), y=1, label = count))
  return (tile)
}

# We want to check for each table how many scans did we have 'scan   tbl=118538'

#dbGetQuery(con, "SELECT avgtime, rows, bytes from SVL_QUERY_SUMMARY where label = 'scan   tbl=118538'")

getScanCount <- function(table) {
  count <- dbGetQuery(con, paste("SELECT label, count(query) as count, 
             sum(avgtime) as time, sum(rows) as rows, 
             sum(bytes) as bytes from SVL_QUERY_SUMMARY 
             where label ='scan   tbl=",table,"' group by 1",sep=""))$count  
  return (count)
}

# We want to check how many of the following actions we have:
# sort
# scan
# save
# aggr
# hash
# limit
# merge
# bcast
# hjoin
# dist