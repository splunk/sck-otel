[![CircleCI](https://circleci.com/gh/git-lfs/git-lfs.svg?style=shield&circle-token=856152c2b02bfd236f54d21e1f581f3e4ebf47ad)](https://circleci.com/gh/splunk/sck-otel)


# What does Splunk Connect for Kubernetes-OpenTelemetry do?

Splunk Connect for Kubernetes-OpenTelemetry provides a way to import and search your Kubernetes logging data in your Splunk platform deployment. Splunk Connect for Kubernetes-OpenTelemetry supports importing and searching your kubernetes logs on the following kubernetes distributions:

* Amazon Elastic Kubernetes Service (Amazon EKS)
* Azure Kubernetes Service (AKS)
* Google Kubernetes Engine (GKE)
* Openshift
* and many others!


Splunk Inc. is a proud contributor to the Cloud Native Computing Foundation (CNCF). Splunk Connect for Kubernetes-OpenTelemetry utilizes and supports multiple CNCF components in the development of these tools to get data into Splunk.


## Prerequisites

* Splunk Enterprise 7.0 or later
* An HEC token. See the following topics for more information:
  * https://docs.splunk.com/Documentation/Splunk/8.2.0/Data/UsetheHTTPEventCollector
  * https://docs.splunk.com/Documentation/Splunk/8.2.0/Data/ScaleHTTPEventCollector
* You should be familiar with your Kubernetes configuration and know where your log information is collected in your Kubernetes deployment.
* Administrator access to your Kubernetes cluster.
* To install using Helm (we recommend Helm 3.0+), verify you are running Helm in your Kubernetes configuration. See https://github.com/kubernetes/helm for more information.
* A minimum of one Splunk platform indexes ready to collect the log data. This index will be used for ingesting logs.


## Before you begin
Splunk Connect for Kubernetes-OpenTelemetry supports installation using Helm. Read the Prerequisites and Installation and Deployment documentation before you start your deployment of Splunk Connect for Kubernetes-OpenTelemetry.

Perform the following steps before you install:

1. Create a minimum of one Splunk platform index. One events index, which will handle logs.
If you do not configure this index, Splunk Connect for Kubernetes-OpenTelemetry uses the defaults created in your HTTP Event Collector (HEC) token.

2. Create a HEC token if you do not already have one. If you are installing the connector on Splunk Cloud, file a ticket with Splunk Customer Service and they will deploy the indexes for your environment, and generate your HEC token.


## Deploy with Helm 3.0+

Helm, maintained by the CNCF, allows the Kubernetes administrator to install, upgrade, and manage the applications running in their Kubernetes clusters.  For more information on how to use and configure Helm Charts,  see the Helm [site](https://helm.sh/) and [repository](https://github.com/kubernetes/helm) for tutorials and product documentation. Helm is the only method that the Splunk software supports for installing Splunk Connect for Kubernetes.

To install and configure defaults with Helm:

* Add Splunk chart repo
```bash
helm repo add splunk https://splunk.github.io/sck-otel/
```

* Get values file in your working directory

```bash
helm show values splunk/sck-otel > values.yaml
```

* Prepare this Values file. This file has a lot of documentation for configuring Splunk Connect for Kubernetes-OpenTelemetry. Look at this [example](https://github.com/splunk/sck-otel/blob/main/charts/opentelemetry-collector/values.yaml). Once you have a Values file, you can simply install the chart with by running

```bash
helm install my-splunk-connect -f my_values.yaml splunk/sck-otel
```

To learn more about using and modifying charts, see:
* https://github.com/splunk/sck-otel/tree/main/charts
* https://docs.helm.sh/using_helm/#using-helm.


## Configuration variables for Helm

The default values file can be found here [default values file](https://github.com/splunk/sck-otel/blob/main/charts/opentelemetry-collector/values.yaml)


# Architecture

Splunk Connect for Kubernetes-OpenTelemetry deploys a DaemonSet on each node. And in the DaemonSet, a Opentelemetry container runs and does the collecting job. Splunk Connect for Kubernetes-OpenTelemetry uses the [node logging agent](https://kubernetes.io/docs/concepts/cluster-administration/logging/#using-a-node-logging-agent) method. See the [Kubernetes Logging Architecture](https://kubernetes.io/docs/concepts/cluster-administration/logging/) for an overview of the types of Kubernetes logs from which you may wish to collect data as well as information on how to set up those logs.
Splunk Connect for Kubernetes-OpenTelemetry collects the following types of data:

* Logs: Splunk Connect for Kubernetes-OpenTelemetry collects two types of logs:
  * Logs from Kubernetes system components (https://kubernetes.io/docs/concepts/overview/components/)
  * Applications (container) logs

To collect the data, Splunk Connect for Kubernetes-OpenTelemetry leverages OpenTelemetry and the following receivers, processors, exporters and extensions:
* [OpenTelemetry](https://opentelemetry.io/)
* [OpenTelemetry collector](https://github.com/open-telemetry/opentelemetry-collector)
* [OpenTelemetry contrib collector](https://github.com/open-telemetry/opentelemetry-collector-contrib)
* [OpenTelemetry log collection](https://github.com/open-telemetry/opentelemetry-log-collection)
* [OpenTelemetry file storage extension](https://pkg.go.dev/github.com/open-telemetry/opentelemetry-collector-contrib/extension/storage) for checkpointing
* [OpenTelemetry health check extension](https://pkg.go.dev/github.com/open-telemetry/opentelemetry-collector/extension/healthcheckextension) for overall health and status of the OpenTelemetry agent
* [OpenTelemetry filelog receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver) for tailing and parsing logs from files using the [opentelemetry-log-collection](https://github.com/open-telemetry/opentelemetry-log-collection) library
* [OpenTelemetry batch processor](https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/batchprocessor) for compressing logs data and reduce the number of outgoing connections required to transmit the data
* [OpenTelemetry memory limiter processor](https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/memorylimiter) to prevent out of memory situations on the OpenTelemetry agent
* [OpenTelemetry kubernetes tagger processor](https://pkg.go.dev/github.com/open-telemetry/opentelemetry-collector-contrib/processor/k8sprocessor) for automatic tagging of logs with k8s metadata
* [OpenTelemetry resource processor](https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/resourceprocessor) to apply changes on resource attributes
* [OpenTelemetry attributes processor](https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/attributesprocessor) to modify attributes of logs
* We also use multiple operators from [OpenTelemetry log collection operators](https://github.com/open-telemetry/opentelemetry-log-collection/tree/main/docs/operators) like regex_parser, recombine, restructure, json_parser, metadata for enriching logs with metadata and transforming/standardizing logs and metadata from various container runtimes
* [OpenTelemetry Splunk HEC exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/splunkhecexporter): to send logs to Splunk HTTP Event Collector. The [HTTP Event Collector](http://dev.splunk.com/view/event-collector/SP-CAAAE6M) collects all data sent to Splunk for indexing.


# Performance of Splunk Connect for Kubernetes-OpenTelemetry

Some configurations used with Splunk Connect for Kubernetes-OpenTelemetry can have an impact on overall performance of log ingestion. In general, the more receivers, processors, exporters and extensions that are added to one of the pipelines, the greater the performance impact.

Splunk Connect for Kubernetes-OpenTelemetry can exceed the default throughput of HEC. To best address capacity needs, Splunk recommends that you monitor the HEC throughput and back pressure on Splunk Connect for Kubernetes-OpenTelemetry deployments and be prepared to add additional nodes as needed.


# Managing SCK Log Ingestion by Using Annotations

Manage Splunk Connect for Kubernetes-OpenTelemetry Logging with these supported annotations.
* Use `splunk.com/index` annotation on pod and/or namespace to tell which Splunk platform indexes to ingest to. Pod annotation will take precedence over namespace annotation when both are annotated.
  ex) `kubectl annotate namespace kube-system splunk.com/index=k8s_events`
* Set `splunk.com/exclude` annotation to `true` on pod and/or namespace to exclude its logs from ingested to your Splunk platform deployment.
* Use `splunk.com/sourcetype` annotation on pod to overwrite `sourcetype` field. If not set, it is dynamically generated to be `kube:container:CONTAINER_NAME` where CONTAINER_NAME is the container name of the container running in the pod.


# Searching for SCK metadata in Splunk
Splunk Connect for Kubernetes-OpenTelemetry sends events to Splunk which can contain extra meta-data attached to each event. Metadata values such as "k8s.pod.name", "k8s.pod.uid", "k8s.deployment.name","k8s.cluster.name", "k8s.namespace.name", "k8s.node.name", "k8s.pod.start_time", "container_name", "run_id" and "stream" will appear as fields when viewing the event data inside Splunk.
There are two solutions for running searches in Splunk on meta-data.

* Modify search to use`fieldname::value` instead of `fieldname=value`.
* Configure `fields.conf` on your downstream Splunk system to have your meta-data fields available to be searched using `fieldname=value`. Example: [fields.conf.example](https://github.com/splunk/sck-otel/blob/main/example/fields.conf.example)

For more information on index time field extraction please view this [guide](https://docs.splunk.com/Documentation/Splunk/latest/Data/Configureindex-timefieldextraction#Where_to_put_the_configuration_changes_in_a_distributed_environment).

# Advanced Configurations for Splunk Connect for Kubernetes-OpenTelemetry

## Adding logs from different kubernetes distributions and container runtimes like(docker, cri-o, containerd)

Select the proper container runtime for your kubernetes distribution.

[Example](https://github.com/splunk/sck-otel/blob/main/charts/opentelemetry-collector/values.yaml#L47)


## Adding log files from kubernetes host machines/volumes

You can add additional log files to be ingested from kubernetes host machines and kubernetes volumes by configuring extraHostPathMounts and extraHostFileConfig in the values.yaml file used to deploy Splunk Connect for Kubernetes-OpenTelemetry.

[Example](https://github.com/splunk/sck-otel/blob/main/example/values/extraHostFileValues.yaml#L102)

## Override underlying OpenTelemetry Agent configuration
If you want to use your own OpenTelemetry Agent configuration, you can build a [OpenTelemetry Agent config](https://github.com/splunk/sck-otel/blob/main/example/manifests/otel_config.yaml) and override our default config by configuring configOverride in the values.yaml file used to deploy Splunk Connect for Kubernetes-OpenTelemetry.


## Adding Audit logs from kubernetes host machines
You can ingest audit logs from your kubernetes cluster by configuring extraHostPathMounts and extraHostFileConfig in the values.yaml file used to deploy Splunk Connect for Kubernetes-OpenTelemetry.

[Example](https://github.com/splunk/sck-otel/blob/main/charts/opentelemetry-collector/values.yaml#L122)

## Processing Multi-Line Logs

TBD


## Tweak Performance/resources used by Splunk Connect for Kubernetes-OpenTelemetry

If you want to tweak performance/cpu and memory resources used by  Splunk Connect for Kubernetes-OpenTelemetry change the available cpu and memory for the Opentelemtry Agent by configuring resources:limits:cpu and resources:limits:memory in the values.yaml file used to deploy Splunk Connect for Kubernetes-OpenTelemetry.

[Example](https://github.com/splunk/sck-otel/blob/main/charts/opentelemetry-collector/values.yaml#L143)


# Maintenance And Support
Splunk Connect for Kubernetes-OpenTelemetry is supported through Splunk Support assuming the customer has a current Splunk support entitlement ([Splunk Support](https://www.splunk.com/en_us/about-splunk/contact-us.html#tabs/tab_parsys_tabs_CustomerSupport_4)). For customers that do not have a current Splunk support entitlement, please search [open and closed issues](https://github.com/splunk/splunk-connect-for-kubernetes/issues?q=is%3Aissue) and create a new issue if not already there.
The current maintainers of this project are the DataEdge team at Splunk.


# License

See [LICENSE](https://github.com/splunk/sck-otel/blob/main/LICENSE).
