<p align="center">
<strong>
<a href=”#overview”>Overview</a>&nbsp;
<a href=”#architecture”>Architecture</a>&nbsp;
<a href="#getting-started">Getting Started</a>&nbsp;
<a href="#configuration">Configuration</a>&nbsp;
<a href="#deployment">Deployment</a>&nbsp;
<a href="#performance">Performance</a>
</strong>
</p>

<p align="center">
<a href="https://github.com/splunk/sck-otel/releases">
<img alt="GitHub release (latest by date including pre-releases)" src="https://img.shields.io/github/v/release/signalfx/splunk-otel-collector-chart?include_prereleases&style=for-the-badge">
</a>
<img alt="Beta" src="https://img.shields.io/badge/status-beta-informational?style=for-the-badge">
</p>

<p align="center">
<strong>
 <a href="#management">Management</a>&nbsp;
<a href="#search">Search</a>&nbsp;
<a href="#maintenance-and-support">Maintenance and Support</a>&nbsp;
<a href="#upgrade">Upgrade</a>&nbsp;
<a href="#contribute">Contribute</a>&nbsp;
<a href="#license">License</a>
</strong>
</p>

# Splunk Connect for Kubernetes-OpenTelemetry

> This project is currently in **BETA**. We welcome your questions, feedback, and contributions! You can create an issue or pull request to propose and collaborate on changes to this repository. Your input is part of our efforts to make a better product. The incremental features included in this repository will be folded into the [Splunk OpenTelemetry Connector](https://github.com/signalfx/splunk-otel-collector) and [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector) projects.  

## Overview

Use Splunk Connect for Kubernetes-OpenTelemetry to import and search Kubernetes logging data in your Splunk platform deployment. Splunk Connect for Kubernetes-OpenTelemetry supports importing and searching your Kubernetes logs on the following Kubernetes distributions:

* Amazon Elastic Kubernetes Service (Amazon EKS)
* Azure Kubernetes Service (AKS)
* Google Kubernetes Engine (GKE)
* Openshift
* and many others!

Splunk Inc. is a proud contributor to the Cloud Native Computing Foundation (CNCF). Splunk Connect for Kubernetes-OpenTelemetry utilizes and supports multiple CNCF components in the development of these tools to get data into Splunk.

## Architecture

Splunk Connect for Kubernetes-OpenTelemetry deploys a DaemonSet on each node. A DaemonSet ensures that all (or some) nodes run a copy of a pod. As nodes are added to the cluster, pods are added to them.

An OpenTelemetry container runs in the DaemonSet to collect logs. Splunk Connect for Kubernetes-OpenTelemetry uses the [node logging agent](https://kubernetes.io/docs/concepts/cluster-administration/logging/#using-a-node-logging-agent) method. See [Kubernetes Logging Architecture](https://kubernetes.io/docs/concepts/cluster-administration/logging/) for an overview of the types of Kubernetes logs from which you may wish to collect data as well as information on how to set up those logs.

Splunk Connect for Kubernetes-OpenTelemetry collects the following types of data:

* Logs: Splunk Connect for Kubernetes-OpenTelemetry collects two types of logs:
  * Logs from Kubernetes system components (https://kubernetes.io/docs/concepts/overview/components/)
  * Applications (container) logs

To collect the data, Splunk Connect for Kubernetes-OpenTelemetry uses OpenTelemetry and the following receivers, processors, exporters, and extensions:
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
* Splunk Connect for Kubernetes-OpenTelemetry uses multiple operators from [OpenTelemetry log collection operators](https://github.com/open-telemetry/opentelemetry-log-collection/tree/main/docs/operators) like regex_parser, recombine, restructure, json_parser, metadata for enriching logs with metadata and transforming/standardizing logs and metadata from various container runtimes
* [OpenTelemetry Splunk HEC exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/splunkhecexporter): to send logs to Splunk HTTP Event Collector. The [HTTP Event Collector](http://dev.splunk.com/view/event-collector/SP-CAAAE6M) collects all data sent to Splunk for indexing.

## Getting started

### Prerequisites

* Splunk Enterprise 7.0 or later
* An HTTP Event Collector (HEC) token. See the following topics for more information:
  * [Set up and use HTTP Event Collector in Splunk Web ](https://docs.splunk.com/Documentation/Splunk/8.2.0/Data/UsetheHTTPEventCollector)
  * [Scale HTTP Event Collector with distributed deployments](https://docs.splunk.com/Documentation/Splunk/8.2.0/Data/ScaleHTTPEventCollector)
* Knowledge of your Kubernetes configuration. You must know where your log information is being collected in your Kubernetes deployment.
* Administrator access to your Kubernetes cluster
* A minimum of one Splunk platform index ready to collect the log data. This index will be used for ingesting logs.
* (Optional) To install using Helm (recommended), verify that you are running Helm version 3.0 or higher in your Kubernetes configuration. See [helm/helm: The Kubernetes Package Manager](https://github.com/kubernetes/helm) for more information.

### Set up Splunk

Splunk Connect for Kubernetes-OpenTelemetry supports installation using Helm. Read the Prerequisites, Installation, and Deployment sections of this README before you start your deployment of Splunk Connect for Kubernetes-OpenTelemetry.

Before installing:

1. Create a minimum of one Splunk platform index. This index will index events, which will handle logs. If you do not configure this index, Splunk Connect for Kubernetes-OpenTelemetry uses the defaults created in your HEC token.
2. Create an HEC token if you do not already have one. If you are installing Splunk Connect for Kubernetes-OpenTelemetry on Splunk Cloud, contact [Splunk Customer Support](https://www.splunk.com/en_us/about-splunk/contact-us.html#tabs/tab_parsys_tabs_CustomerSupport_4). Splunk Customer Support will deploy the indexes for your environment and generate your HEC token.

### Set up the non-root user

Run pods as a non-root user. This section describes how to avoid running the Splunk Connect for Kubernetes-OpenTelemetry pod as the `root` user.

For example, the [values.yaml chart](https://github.com/splunk/sck-otel/blob/main/charts/sck-otel/values.yaml#L104) is, by default, set to run as a user with a UID and GID of `10001`, but this user does not have permission to read container log files typically owned by `root`. The following example shows how to create a user with GID 10001 and grant access to that GID.

```bash
# Create a user otel with uid=10001 and gid=10001.
sudo adduser --disabled-password --uid 10001 --no-create-home otel

# Set up a directory for storing checkpoints.
sudo mkdir /var/lib/otel_pos
sudo chgrp otel /var/lib/otel_pos
sudo chmod g+rwx /var/lib/otel_pos

# Set up container log directories.
# Check the symlinks file on `/var/log/pods/` and its target paths to determine where the files are.
ls -Rl /var/log/pods
# These are the default paths:
# `/var/lib/docker/containers` for docker
# `/var/log/crio/pods` for cri-o
# `/var/log/pods` for containerd
# Add your container log path, if different.
if [ -d "/var/lib/docker/containers" ]
then
    sudo chgrp -R otel /var/lib/docker/containers
    sudo chmod -R g+rwx /var/lib/docker/containers
    sudo setfacl -Rm d:g:otel:rwx,g:otel:rwx /var/lib/docker/containers
fi

if [ -d "/var/log/crio/pods" ]
then
    sudo chgrp -R otel /var/log/crio/pods
    sudo chmod -R g+rwx /var/log/crio/pods
    sudo setfacl -Rm d:g:otel:rwx,g:otel:rwx /var/log/crio/pods
fi

if [ -d "/var/log/pods" ]
then
    sudo chgrp -R otel /var/log/pods
    sudo chmod -R g+rwx /var/log/pods
    sudo setfacl -Rm d:g:otel:rwx,g:otel:rwx /var/log/pods
fi
```

## Configuration

See [values.yaml](https://github.com/splunk/sck-otel/blob/main/charts/sck-otel/values.yaml) for the default values file. This file provides configurable parameters and default values for Splunk Connect for Kubernetes-OpenTelemetry.

### Advanced configurations 

#### Add logs from different Kubernetes distributions and container runtimes (Docker, CRI-O, or containerd)

Select the proper container runtime for your Kubernetes distribution. See the [container runtime example](https://github.com/splunk/sck-otel/blob/main/charts/sck-otel/values.yaml#L47).

#### Add log files from Kubernetes host machines and volumes

Add additional log files to be ingested from Kubernetes host machines and volumes by configuring `extraHostPathMounts` and `extraHostFileConfig`. See the [extraHostFileValues example](https://github.com/splunk/sck-otel/blob/main/example/values/extraHostFileValues.yaml#L102).

#### Override the underlying OpenTelemetry Agent configuration

Use your own OpenTelemetry Agent configuration by building an [OpenTelemetry Agent configuration](https://github.com/splunk/sck-otel/blob/main/example/manifests/otel_config.yaml) to override the default configuration. See the [`configOverride` example](https://github.com/splunk/sck-otel/blob/main/example/values/extraHostFileValues.yaml#L115).

#### Add audit logs from Kubernetes host machines

Ingest audit logs from your Kubernetes cluster by configuring `extraHostPathMounts` and `extraHostFileConfig`. See the [service account creation example](https://github.com/splunk/sck-otel/blob/main/charts/sck-otel/values.yaml#L122).

#### Process multi-line logs

Configure the `multilineSupportConfig` section in values.yaml to enable parsing of multiline logs. See the [multilineSupportConfig example](https://github.com/splunk/sck-otel/blob/9bd92b9b2054b85eadfd744888cc19ebb46b0081/charts/sck-otel/values.yaml#L77).   
Splunk Connect for Kubernetes-OpenTelmetry supports parsing of multiline logs to help read, understand and troubleshoot the multiline logs in a better way.
Process multiline logs by configuring `multilineSupportConfig` section in values.yaml.

If you use a specific format for Python stack traces, take an example of your stack trace output and use [https://regex101.com/](https://regex101.com/) to find a golang regex that works for your format. Specify the format in the configuration file for the configuration option "first_entry_regex" and for the configuration option to pass in the appropriate container name.

#### Tweak performance and resources used by Splunk Connect for Kubernetes-OpenTelemetry

Change the available CPU and memory for the Opentelemtry Agent by configuring `resources:limits:cpu and resources:limits:memory`. See the [extraHostPathMounts example](https://github.com/splunk/sck-otel/blob/main/charts/sck-otel/values.yaml#L143).

## Deployment

Helm, maintained by the CNCF, allows the Kubernetes administrator to install, upgrade, and manage the applications running in their Kubernetes clusters. For more information on using and configuring Helm Charts, see the Helm [site](https://helm.sh/) and [repository](https://github.com/kubernetes/helm). The repository provides tutorials and product documentation. Helm is the only method that Splunk software supports for installing Splunk Connect for Kubernetes-OpenTelemetry.

To install and configure defaults with Helm 3.0+:

1. Add the Splunk chart repository:
```bash
helm repo add splunk-otel https://splunk.github.io/sck-otel/
```
2. Add the [values.yaml file](https://github.com/splunk/sck-otel/blob/main/charts/sck-otel/values.yaml) to your working directory. 
```bash
helm show values splunk-otel/sck-otel > values.yaml
```
3. Configure the values file. 
4. Install the chart:
```bash
helm install my-splunk-connect -f my_values.yaml splunk-otel/sck-otel
```

To learn more about using and modifying charts, see:
* [Charts](https://github.com/splunk/sck-otel/tree/main/charts)
* [Introduction to Helm](https://docs.helm.sh/using_helm/#using-helm)

## Performance

Some configurations used with Splunk Connect for Kubernetes-OpenTelemetry can have an impact on the overall performance of log ingestion. The more receivers, processors, exporters, and extensions that are added to any of the pipelines, the greater the performance impact.

Splunk Connect for Kubernetes-OpenTelemetry can exceed the default throughput of HEC. To best address capacity needs, monitor the HEC throughput and back pressure on Splunk Connect for Kubernetes-OpenTelemetry deployments and be prepared to add additional nodes as needed.

Here is the summary of performance benchmarks run internally.

| Log Generator Count | Total Generated EPS | Event Size (byte) | Agent CPU Usage | Agent EPS |
|---------------------|---------------------|-------------------|-----------------|-----------|
|                   1 |              27,000 |               256 |             1.6 |    27,000 |
|                   1 |              49,000 |               256 |             1.8 |    30,000 |
|                   1 |              49,000 |               516 |             1.8 |    28,000 |
|                   1 |              49,000 |              1024 |             1.8 |    24,000 |
|                   2 |              20,000 |               256 |             1.3 |    20,000 |
|                   7 |              40,000 |               256 |             2.4 |    40,000 |
|                   5 |              58,000 |               256 |             3.2 |    54,000 |
|                   7 |              82,000 |               256 |               3 |    52,000 |
|                  10 |              58,000 |               256 |             3.2 |    53,000 |

## Management 

Manage Splunk Connect for Kubernetes-OpenTelemetry logging with these supported annotations:

* Use `splunk.com/index` annotation on the pod or namespace to tell which Splunk platform indexes to ingest to. The Pod annotation will take precedence over the namespace annotation when both are annotated. For example, `kubectl annotate namespace kube-system splunk.com/index=k8s_events`.
* Use `splunk.com/sourcetype` annotation on the pod to overwrite the `sourcetype` field. If not set, it is dynamically generated to be `kube:container:CONTAINER_NAME`, where `CONTAINER_NAME` is the container name of the container running in the pod.
* Set `splunk.com/exclude` annotation to `true` on the pod or namespace to exclude its logs from being ingested to your Splunk platform deployment.
* Set `splunk.com/include` annotation to `true` on the pod and the `containerLogs.useSplunkIncludeAnnotation` flag to `true` to include its ingested logs from your Splunk platform deployment.

All other logs will be ignored. Do not use this feature with the above mentioned exclude feature. You can only use either the include feature or the exclude feature.

## Search

Splunk Connect for Kubernetes-OpenTelemetry sends events to Splunk that can contain extra metadata. Metadata values such as "k8s.pod.name", "k8s.pod.uid", "k8s.deployment.name","k8s.cluster.name", "k8s.namespace.name", "k8s.node.name", "k8s.pod.start_time", "container_name", "run_id", and "stream" will appear as fields when viewing the event data inside Splunk.

There are two solutions for running metadata searches in Splunk:

* Modify search to use `fieldname::value` instead of `fieldname=value`.
* Configure `fields.conf` on your downstream Splunk system to have the metadata fields available to be searched using `fieldname=value`. See [fields.conf.example](https://github.com/splunk/sck-otel/blob/main/example/fields.conf.example) for more information. 

For more information on index time field extraction, see [Where to put the configuration changes in a distributed environment](https://docs.splunk.com/Documentation/Splunk/latest/Data/Configureindex-timefieldextraction#Where_to_put_the_configuration_changes_in_a_distributed_environment).

## Maintenance and support

Splunk Connect for Kubernetes-OpenTelemetry is supported through Splunk Support, assuming you have a current [Splunk Support](https://www.splunk.com/en_us/about-splunk/contact-us.html#tabs/tab_parsys_tabs_CustomerSupport_4) entitlement. If you do not have a current Splunk Support entitlement, search [open and closed issues](https://github.com/splunk/sck-otel/issues?q=is%3Aissue). Create a new issue if necessary. 

The current maintainers of this project are the DataEdge team at Splunk.

## Contribute

We welcome feedback and contributions from the community! Please see the [contribution guidelines](https://github.com/splunk/sck-otel/blob/main/CONTRIBUTING.md) to learn how to get involved. PR contributions require acceptance of both the code of conduct and the contributor license agreement.

## Upgrade

### From version 0.2.x  to version 0.3.0

If using `.Values.configOverride` and there are expressions that refer to the log record, double up the `$` characters for those expressions. See [Expressions](https://github.com/open-telemetry/opentelemetry-log-collection/blob/main/docs/types/expression.md) for more information.

## License

See [LICENSE](https://github.com/splunk/sck-otel/blob/main/LICENSE) for the terms and conditions for use, reproduction, and distribution.
