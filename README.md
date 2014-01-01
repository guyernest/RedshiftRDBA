RedshiftRDBA
============

DBA library for Amazon Redshift

Getting Started
===============

1. Install R (and RStudio)

There are many tutorial on how to install R and its popular IDE Rstudio.

The easiest way is to launch an EC2 instance with everything already preinstalled:

** Using a web browser: http://www.louisaslett.com/RStudio_AMI/

** Using AWS CLI (http://aws.amazon.com/cli/):
aws ec2 run-instances --image-id ami-1ffd6d2f 
  --instance-type m3.xlarge 
  --security-groups RStudioServer 
  --region us-west-2
