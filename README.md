# Splunk Connect for Kubernetes-OpenTelemetry

### This project was created for beta testing, which is now complete.  The incremental features included in this repo have been folded into the Helm chart, [Splunk OpenTelemetry Collector for Kubernetes](https://github.com/signalfx/splunk-otel-collector-chart) as of [Release 0.38](https://github.com/signalfx/splunk-otel-collector-chart/releases/tag/splunk-otel-collector-0.38.0). 

### Please refer to that repository for all content.



## Additional information
The [Splunk OpenTelemetry Collector for Kubernetes](https://github.com/signalfx/splunk-otel-collector-chart) 
is a Helm chart that provides a higher-performance update and clean migration for 
[Splunk Connector for Kubernetes](https://splunkbase.splunk.com/app/4497/) users, with 10x+ performance improvement.  

Customers that are [migrating from the Splunk Connect for Kubernetes](https://github.com/signalfx/splunk-otel-collector-chart/blob/main/docs/migration-from-sck.md) 
to the new Splunk OpenTelemetry Collector for Kubernetes will notice the following benefits:
* significant logs collection performance improvements with use of OTel native logs vs SCK’s use of FLuentD, 
* extensive metrics for the agent itself, 
* additional resource metadata, 
* alignment with OpenTelemetry metrics and resource naming or retain the existing SCK naming, or both,
* a single agent with options to collect all of their logs, metrics and traces telemetry data and send it on to Splunk platform, Splunk Observability Cloud, and other receivers.


