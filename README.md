RedshiftRDBA
============

DBA library for Amazon Redshift

Getting Started
===============

1. Install R (and RStudio)
--------------------------

There are many tutorial on how to install R and its popular IDE Rstudio.

The easiest way is to launch an EC2 instance with everything already preinstalled:

* Using a web browser: 

http://www.louisaslett.com/RStudio_AMI/

* Using AWS CLI (http://aws.amazon.com/cli/):

  `aws ec2 run-instances --image-id ami-1ffd6d2f`
    
    `--instance-type m3.xlarge` 
    
    `--security-groups RStudioServer`
    
    `--region us-west-2`

(Please remember to modify the user and password of the remote RStudio)

2. Grant permission to access your Redshift cluster to your local or remote R 
--------------------------

* Using a web browser: 

http://docs.aws.amazon.com/redshift/latest/mgmt/working-with-security-groups.html

* Using AWS CLI:

  `aws redshift authorize-cluster-security-group-ingress --cluster-security-group-name default --ec2-security-group-name RStudioServer`

3. Install the RedshiftRDBA library
-------------------------

Until it is nicely packaged, you need to copy the files to your machine and source them

Using the DBA library
====================

### Connecting to your Redshift cluster

`con <- clusterConnect("cluster-name.xxxxxxxxxx.us-west-2.redshift.amazonaws.com", "dev", "user", "password")`

### DB Summary

`DBSummaryTable <- DBSummary(con)`

`plotSummary(DBSummaryTable)`

![Chart Output Example](DBSummaryExample.png "DB Summary Example")

### Table Summary

`cloudfrontTable <- tableCols(con, "cloudfront")`

`plotTable(cloudfrontTable)`

![Chart Output Example](TableSummaryExample.png "Table Summary Example")


