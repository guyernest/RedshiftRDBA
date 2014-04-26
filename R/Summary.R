# General DB functions

clusterConnect <- function(host, dbname, user, pass, port=5439 ){
  if("RPostgreSQL" %in% rownames(installed.packages()) == FALSE) 
    {install.packages("RPostgreSQL")}
  require(RPostgreSQL)
  drv <- dbDriver("PostgreSQL")
  con <- dbConnect(drv, dbname=dbname, host=host, user=user, pass=pass, port=port)
  #Defining the prepare statements for the table queries
  dbGetQuery(con, "PREPARE table_cols (char) as select * from PG_TABLE_DEF where tablename=$1;")
  dbGetQuery(con, "PREPARE table_space_cols (char) as 
    select trim(relname) as table_name, col, count(*) as slices
    from stv_blocklist s, pg_class p
    where s.tbl=p.oid and relname = $1
    group by 1,2
    order by 1,2;")
    
  return(con)
}

cleanAnalysisTables <- function(con) {
  dbSendQuery(con, "DROP TABLE temp_staging_tables_1;")
  dbSendQuery(con, "DROP TABLE temp_staging_tables_2;")
  dbSendQuery(con, "DROP TABLE temp_tables_report;")
}

analyzeTableDesign <- function(con) {
  
  dbSendQuery(con, "CREATE TEMP TABLE temp_staging_tables_1
                 (schemaname TEXT,
                  tablename TEXT,
                  tableid BIGINT,
                  size_in_megabytes BIGINT);")
  
  dbSendQuery(con, "INSERT INTO temp_staging_tables_1
SELECT n.nspname, c.relname, c.oid, 
      (SELECT COUNT(*) FROM STV_BLOCKLIST b WHERE b.tbl = c.oid)
FROM pg_namespace n, pg_class c
WHERE n.oid = c.relnamespace 
  AND nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema')
  AND c.relname <> 'temp_staging_tables_1';")
  
  dbSendQuery(con, "CREATE TEMP TABLE temp_staging_tables_2
                 (tableid BIGINT,
                  min_blocks_per_slice BIGINT,
                  max_blocks_per_slice BIGINT,
                  slice_count BIGINT);")
  
  dbSendQuery(con, "INSERT INTO temp_staging_tables_2
      SELECT tableid, MIN(c), MAX(c), COUNT(DISTINCT slice)
      FROM (SELECT t.tableid, slice, COUNT(*) AS c
        FROM temp_staging_tables_1 t, STV_BLOCKLIST b
        WHERE t.tableid = b.tbl
        GROUP BY t.tableid, slice)
      GROUP BY tableid;")
 
  dbSendQuery(con, "CREATE TEMP TABLE temp_tables_report
                 (schemaname TEXT,
                 tablename TEXT,
                 tableid BIGINT,
                 size_in_mb BIGINT,
                 has_dist_key INT,
                 has_sort_key INT,
                 has_col_encoding INT,
                 pct_skew_across_slices FLOAT,
                 pct_slices_populated FLOAT);")
  
  dbSendQuery(con, "INSERT INTO temp_tables_report
      SELECT t1.*,
       CASE WHEN EXISTS (SELECT *
              FROM pg_attribute a
              WHERE t1.tableid = a.attrelid
              AND a.attnum > 0
              AND NOT a.attisdropped
              AND a.attisdistkey = 't')
              THEN 1 ELSE 0 END,
        CASE WHEN EXISTS (SELECT *
              FROM pg_attribute a
              WHERE t1.tableid = a.attrelid
              AND a.attnum > 0
              AND NOT a.attisdropped
              AND a.attsortkeyord > 0)
              THEN 1 ELSE 0 END,
        CASE WHEN EXISTS (SELECT *
              FROM pg_attribute a
              WHERE t1.tableid = a.attrelid
              AND a.attnum > 0
              AND NOT a.attisdropped
              AND a.attencodingtype <> 0)
              THEN 1 ELSE 0 END,
              100 * CAST(t2.max_blocks_per_slice - t2.min_blocks_per_slice AS FLOAT)
              / CASE WHEN (t2.min_blocks_per_slice = 0) 
              THEN 1 ELSE t2.min_blocks_per_slice END,
              CAST(100 * t2.slice_count AS FLOAT) / (SELECT COUNT(*) FROM STV_SLICES)
              FROM temp_staging_tables_1 t1, temp_staging_tables_2 t2
              WHERE t1.tableid = t2.tableid;")
  
  summaryData <- dbGetQuery(con, "SELECT * FROM temp_tables_report
      ORDER BY schemaname, tablename;")

  #summaryData <- fetch(summaryQuery, n=-1)  
  summaryData$size_in_kb <- summaryData$size_in_mb*1024  
  
  return (summaryData)
}


# These functions are querying the PG (catalogue) tables

analyzeCatalog <- function(con) {
  catalogData <- dbGetQuery(con, "select nspname, trim(relname) as table_name, max(attnum) as num_cols
    from pg_attribute a, pg_namespace n, pg_class c
    where n.oid = c.relnamespace and  a.attrelid = c.oid
    and c.relname not like '%pkey'
    and n.nspname not like 'pg%'
    and n.nspname not like 'information%'
    group by 1, 2
    order by 1, 2;")
  
  stv_tbl_permData <- dbGetQuery(con, "select trim(nspname), trim(relname)  as table_name, sum(rows) as rows, sum(rows)-sum(sorted_rows) AS unsorted_rows
    from pg_class, pg_namespace, pg_database, stv_tbl_perm
    where pg_namespace.oid = relnamespace
    and pg_class.oid = stv_tbl_perm.id
    and pg_database.oid = stv_tbl_perm.db_id
    group by 1, 2
    order by 1, 2;")
  mergedTable <- merge(x=catalogData, y=stv_tbl_permData, by="table_name", all.x=TRUE)

  return (mergedTable)
}

stv_query <- function(con) {
  stv_tbl_permQuery <- dbSendQuery(con, "SELECT TRIM(pgdb.datname) AS DATABASE, TRIM(pgn.nspname) AS Schema,
      TRIM(a.name) AS TABLE, id AS TableId,  b.mbytes, a.ROWS, a.unsorted_rows 
      FROM ( SELECT db_id, id, name, SUM(ROWS) AS ROWS, SUM(ROWS)-SUM(sorted_rows) AS unsorted_rows FROM stv_tbl_perm a GROUP BY db_id, id, name ) AS a 
      JOIN pg_class AS pgc ON pgc.oid = a.id
      JOIN pg_namespace AS pgn ON pgn.oid = pgc.relnamespace
      JOIN pg_database AS pgdb ON pgdb.oid = a.db_id
      LEFT OUTER JOIN (SELECT tbl, COUNT(*) AS mbytes 
      FROM stv_blocklist GROUP BY tbl) b ON a.id=b.tbl
      ORDER BY 1,2,3;")
  stv_tbl_permData <- fetch(stv_tbl_permQuery, n=-1)  
  return (stv_tbl_permData)

}

DBSummary <- function(con) {
  mergedTable <- analyzeCatalog(con)
  summaryTable <- analyzeTableDesign(con)
  mergeAgain <- merge(x=mergedTable, y=summaryTable, by.x="table_name", by.y = "tablename", all.x=TRUE)
  mergeAgain$avg <- floor((mergeAgain$size_in_kb/mergeAgain$rows)*1024)
  return (mergeAgain)
}

plotSummary <- function(summaryTable) {
  if("reshape2" %in% rownames(installed.packages()) == FALSE) 
    {install.packages("reshape2")}
  require(reshape2)
  row.names(summaryTable) <- summaryTable$table_name
  summaryTable$percent_unsorted <- summaryTable$unsorted_rows/summaryTable$rows*100
  dfm <- melt(summaryTable[,c('table_name','size_in_kb','rows','unsorted_rows','avg', 'num_cols', 'percent_unsorted')],id.vars = 1)
  if("ggplot2" %in% rownames(installed.packages()) == FALSE) 
    {install.packages("ggplot2","scales")}
  require(ggplot2)
  require(scales)
  tile <- ggplot(dfm,aes(x = table_name,y = value)) +
  geom_bar(data=subset(dfm, variable=='rows' | variable=='size_in_kb'), 
           aes(fill = variable),position = "dodge", stat="identity") +
  scale_y_sqrt(labels = comma) +
  geom_bar(data=subset(dfm, variable=='unsorted_rows'), 
           aes(y=value), stat="identity", alpha=0.2, colour="red", width=0.5) +   
  geom_text(data=subset(dfm, variable=='percent_unsorted'), 
            aes(y= 100, label = sprintf("%.1f %%",value)), 
            vjust=-1, size=3) +    
  geom_text(data=subset(dfm, variable=='avg'), 
            aes(y= 0, label = paste(value,"B",sep="")), vjust=-0.8, hjust=-1, size=4, angle = 90) +  
  geom_text(data=subset(dfm, variable=='num_cols'), 
            aes(y= 0, label = paste("<-",value,"->",sep="")), vjust=1, hjust=-1, size=4, angle = 90) +  
  labs(title = "Data Distribution in DB Tables", x="Avg. Rec/Bytes    <-#Cols->\nUnsorted %\nTable Name", y="", size=1) +
  theme(axis.title.x = element_text(size = rel(0.75)), axis.text.x = element_text(angle = 90, hjust = 1))

  return (tile)
}
