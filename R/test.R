con <- clusterConnect("cf-logs.xxxxxxxxxx.us-west-2.redshift.amazonaws.com", "dev", "user", "password")

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
