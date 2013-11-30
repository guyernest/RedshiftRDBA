# Focus on the design of a specific table

tableCols <- function(con, tableName) {
  executeCommand <- paste("EXECUTE table_cols ('",strwrap(tableName),"')",  sep = "")
  colQueryData <- dbGetQuery(con, executeCommand)
  
  executeCommand <- paste("EXECUTE table_space_cols ('",strwrap(tableName),"')",  sep = "")
  colSpaceQueryData <- dbGetQuery(con, executeCommand)
  colQueryData$slices <-colSpaceQueryData$slices[1:nrow(colQueryData)]
  return (colQueryData)
}

plotTable <- function(summaryTable) {
  require(reshape2)
  dfm <- melt(summaryTable[,c('column','type','encoding','slices', 'distkey', 'sortkey')],id.vars = 1)
  require(ggplot2)
  require(scales)
  tile <- ggplot(dfm,aes(x = column,y = value)) +
    geom_bar(data=subset(dfm, variable=='slices'),aes(y = as.integer(value)), fill="#66CC33", stat="identity") +
    scale_y_sqrt() +
    geom_text(data=subset(dfm, variable=='type'), aes(y= 1, label = value), color="#0033CC") +  
    geom_text(data=subset(dfm, variable=='encoding'), aes(y= Inf, label = paste("(",value,")",sep="")),hjust=1)
  if (sum(summaryTable$distkey)>0) {
    tile <- tile + geom_text(data=subset(dfm, variable=='distkey' & value==TRUE), aes(y= 0, label = "D"), color="red",hjust=1)    
  }
  if (sum(summaryTable$sortkey)>0) {
    tile <- tile + geom_text(data=subset(dfm, variable=='sortkey' & value>0), aes(y= 0, label = value), color="red",hjust=2.5) 
  }
  tile <- tile + labs(title = paste("Data Distribution in Table:",summaryTable[1,2]), x="Column Name (encoding)", y="1MB Blocks (LOG Scale)") +
    coord_flip()
  
  return (tile)
}


#This query is getting the amount of storage each column in the table is using
# It is adding as the last 3 columns system columns for (INSERT_XID, DELETE_XID, and ROW_ID (OID))
select trim(relname) as table_name, col, count(*) as slices
from stv_blocklist s, pg_class p
where s.tbl=p.oid and relname = 'cf_logs'
group by 1,2
order by 1,2;

# This query is getting the user table schema, name, oid and number of blocks used
SELECT trim(n.nspname), trim(c.relname), c.oid, 
(SELECT COUNT(*) FROM STV_BLOCKLIST b WHERE b.tbl = c.oid)
FROM pg_namespace n, pg_class c
WHERE n.oid = c.relnamespace 
AND nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema')

#This query is getting the information of a table
select * from PG_TABLE_DEF where tablename='cf_logs';

# This query is getting the columns of a table in order with their data type
select column_name, ordinal_position, data_type from information_schema.columns where
table_name='cf_logs'
order by 2


# This query is getting the number of rows that are each slice of the cluster for each table

select trim(name) as table, stv_blocklist.slice, stv_tbl_perm.rows
from stv_blocklist,stv_tbl_perm
where stv_blocklist.tbl=stv_tbl_perm.id
and stv_tbl_perm.slice=stv_blocklist.slice
and stv_tbl_perm.id > 10000 and name not like '%#m%'
and name not like 'systable%'
group by name, stv_blocklist.slice, stv_tbl_perm.rows
order by 3 desc;
