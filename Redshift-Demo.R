con <- clusterConnect("kinesis-demo.xxxxxxxxx.us-east-1.redshift.amazonaws.com", "users", "demouser", "putyourpasswordhere", 5439)


summaryData <- dbGetQuery(con, 
      "SELECT state, count(*) FROM users
      GROUP BY 1 ORDER by 2 DESC;")

library(ggplot2)
ggplot(summaryData, aes(x = state, y = count)) + geom_bar(stat = "identity")
