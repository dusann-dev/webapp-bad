# AWS Deployment

As for now, AppBAD service works with MySQL database to hold metadata and ElasticSearch to hold scans, detection results and application logs.

In AWS cloud environment you can use [Aurora](https://aws.amazon.com/rds/aurora) or [RDS](https://aws.amazon.com/rds/mysql/) MySQL database, and OpenSearch can be used instead of ElasticSearch. Both of these can be configured to reside in VPC and therefore private connection to AppBAD service can be established. 

AppBAD service itself can be deployed as [ECS](https://aws.amazon.com/ecs) Task or [AppRunner](https://aws.amazon.com/apprunner/) instance. You only need to fill in environment variables to configure connection to MySQL database and ElasticSearch.

Secure access to api can be achieved using [Api Gateway](https://aws.amazon.com/api-gateway/).