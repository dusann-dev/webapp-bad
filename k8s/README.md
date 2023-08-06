# Deployment to Kubernetes cluster

## Helm chart

You can install AppBAD service using local helm chart, providing MySQL connection and ElasticSearch details. The service is deployed as statefulset to allow restart of interrupted Hangfire jobs in case of pod restarts. You can set replica count, however, autoscaling is not supported as it could cause forgetting some of jobs.

Example to create application `web-anomally` using Helm chart:

```
helm install web-anomally ./appbad --set mysql.credsecret=mysqlcred
```

## Multi-tenancy support

If you want to have separate appbad application for each project use `mysql.database` parameter to configure database name and `elasticSearch.indexSuffix` to define format of index name (e.g., for scans it will be `scans_proj1` if `elasticSearch.indexSuffix=_proj1`).
This way projects will not be separate from security perspective but it allows you to reuse MySQL and ElasticSearch instances across different projects.
