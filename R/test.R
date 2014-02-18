con <- clusterConnect("cluster-dns", "db-name", "user", "password", 5349)

# DB Overview
DBSummaryTable <- DBSummary(con)
plotSummary(DBSummaryTable)

# Table Overview
cloudfrontTable <- tableCols(con, "cloudfront")
plotTable(cloudfrontTable)

# Analyzing the queries
plotQueryDistribution(con)
hourHeatMap(con)

# Analyzing the queues
serviceClassAvg <- analyzeQueuePerServiceClass(con)
plotQueuePerServiceClass(serviceClassAvg)
