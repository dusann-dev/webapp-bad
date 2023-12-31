# Web Application Behavior Anomaly Detection POC

This repo contains POC for AppBAD (Application Behavior Anomaly Detection), targetting web applications.

The solution works with scans of web page element. Learning algorithm tries to generate a baseline which would encapsulate the pattern of element. The baseline would be later used to detect anomalous behaviour.

## Architecture

The POC contains only the most neccessary features to provide simple structure to organize experiments and explore various configurations. It is intended for research therefore many aspects of solution are not considered: security, scalability, high availability, performance.

Generating a model is initiated by creating a learning request which contains learning algorithm configuration, scans filter, etc.. Based on the request a learning task and its subtasks are created. You can configure task to partition learning for different pages and/or elements.

### Service
It provides REST api to execute operations while abstracting from internal representation. Api exposes openApi documentation and swagger page.
You can use [httpRepl](https://learn.microsoft.com/en-us/aspnet/core/web-api/http-repl/?view=aspnetcore-7.0&tabs=windows) or [Postman](https://www.postman.com/) to communicate with api comfortably. 
    
Longer tasks are handled by [Hangfire](https://www.hangfire.io) library which stores a job into database and initiates work in a separate thread. This applies to learning task and evaluation of new scan according detection rules. For detailed list of jobs you can reach to Hangfire dashboard.

### Metadata Storage

Learning tasks and detection rules are stored in MySQL database.

### Scans and results storage

Scans and detection results are stored in ElasticSearch. To browse them you can use [Kibana](https://www.elastic.co/what-is/kibana) which allows you to create dashboards, alerts to work with data effectively.

## Deployment

Use docker-compose file to create a deployment in docker for testing purpose. It will deploy the service, MySQL database, elastic search instance and kibana.

Create docker deployment:
```
docker compose up
```
Finalize security setup of ElasticSearch according and Kibana according [documentation](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/docker.html#docker-keystore-bind-mount). This step is optional but recommended.

### Kubernetes deployment

You can find more information and instructions [here](k8s/README.md)

### AWS deployment

You can find more information and instructions [here](aws/README.md)

## Example flow

1. Decide which parts of web application you want to scan.
1. Periodically send scans to AppBAD endpoint.
Use can use script `New-AppBADScansFromCSV.ps1` to send scans according list of pages (the second column defines xpath of scanned element) defined in CSV.
1. Create a learning task to generate model out of scans.
1. Create a detection rule out of the learning task. 
1. Monitor anomalies reported the rule. Adjust configuration of the rule to mitigate false alerts.
1. Return to step 3 if the application changes behaviour, e.g., due to code change. 

## Adding a scan

Send POST request to `/api/scan` with JSON payload below:
```
{
    "context":
    {
        "url":"/example",
        "elementXPath":"//div",
        "tags":[],
        "data":[{"posX":0,"posY":0,"width":0,"height":0,"domContent":"<div>hello</div>"}],
        "timestamp":"2021-05-16T13:37:11.5791437Z"
    }
}
```

Make sure that `domContent` property contains full html of element at the time of scanning, especially when content of node is loaded asynchronously. Otherwise model generated by learning algorithm will be skewed.


## Generating model

### Algorithm

Currently there is only one algorithm for generating a model. The algorithm compares html nodes across scans and tries to create a baseline for them.
Regarding text values (node innner text or attribute value), if a value is different across scans the algorithm attempts to describe common properties for text value: number, timestamp, prefix.

You can adjust configuration of algorithm in `learnerSettings` field.

### Learning task request format

Send POST request to `/api/learning` with JSON payload below:

```
{
    "name": "My project",
    "description": "",
    "contextFilter": {
        "urlRegex": "",
        "xPathPrefix": ""
    },
    "partitionOptions": 1,
    "range": {
        "start": "2023-06-04T00:00:00",
        "end": "0001-06-05T00:00:00"
    },
    "learnerType": "CompareDOMBaselineLearner",
    "learnerSettings": { 
        "SkipTags" : "script,svg",
        "SkipAttributes" : "viewBox,style",
        "SkipAttributeRegex" : "^_ngcontent-.*,^_nghost-*",
        "NodeCountMinThreshold" : 0.2 
        "LogLevel" : "Debug"
     }
}
```
You can turn on detailed logging of learning algorithm by setting `LogLevel`. 

### Partitioning

Scans filtered by `contextFilter` might come from different pages and typically you want extract a model for each page separately. You tell by `partitionOptions` whether you want to split learning task by url and root element xpath (`partitionOptions = 1`). By default learning task is split only by root element xpath (`partitionOptions = 0`) which might be useful if you want to extract a model from page with different in url, forming the content of page, and therefore create more general model.

### Model validation

It can happen that generated model will be poor: the number of node rules will be very low compared to typical number of nodes in input. This can be caused for example by presence of outliers in inputs or generally very diverse set of inputs. On the other hand, it might be desired to extract a common baseline for larger diverse set of inputs. You can set expectations of model by defining additional learner settings (`learnerSettings` dictionary):

| Setting Name            | Description                 |
|-----------|---------|
|`NodeCountMinThreshold`    | Ratio of node rules and minimum nodes count across scans is lower or equal to `NodeCountMinThreshold` |
|`NodeCountMaxThreshold`    | Ratio of node rules and maximum nodes count across scans is lower or equal to `NodeCountMaxThreshold` |
|`NodeCountAvgThreshold`    | Ratio of node rules and average nodes count across scans is lower or equal to `NodeCountAvgThreshold`|
|`NodeCountPercentileThreshold`    | Ratio of node rules and percentile value of nodes count (determined by `NodeCountPercentile`) across scans is lower or equal to `NodeCountPercentileThreshold` |
|`NodeCountPercentile`    | Percent of inputs sorted in ascending order by nodes count, e.g., 80%.|

Note that any settings to skip particular nodes (via xpath or tag name definition) are taken into consideration in calculation of nodes count.

## Creating a detection rule

A detection rule is created on top of learning task from which to take model, defined by its id (`learningTaskId`).

Send POST request to `/api/detectionrule` with JSON payload below:

```
{
    "ruleName": "My project detection",
    "learningTaskId": "0477ed52-0f74-402f-920b-8d06da9859d4",
    "evaluator": "WebScanBaselineEvaluator",
    "contextFilter": {
        "urlRegex": "^\/example\/*",
        "xPathPrefix": ""
    },
    "evaluatorSettings": { 
        "SkipAttributes" : "class",
        "MissingElementScore" : 1.2
    }
}
```
You can set `contextFilter` to apply detection rule only to certain set of scans.

### Evaluator

Evaluator is a function which compares model to a new web element scan and scores any differences.

Currently, there is only one type of evaluator: `WebScanBaselineEvaluator`
Evaluator settings allow you to overide configuration of evaluator, e.g. score for particular violation against model.

### Overriding of a model in a detection rule

You can change a part of model used for detection rule by definition of `detectionRuleOverides`. It allows you to alter model definition for certain xpath. This can be useful when we are generally ok with generated model but certain part of it responsible for a lot of false alarms. Or, on the other hand, we want apply more strict rule.

## Anomaly detection results

Summary of detection results per detection rule is available at `/api/detectionresults/{ruleId}`. By default it shows statistisc per page for the last 5 minutes. You can define time period supplying query parameters `from` and `to`.

To get detailed detection results go to Kibana and search in `results` index.
