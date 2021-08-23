# Changelog

## Unreleased

## v0.3.0

### 🛑 Breaking changes 🛑
- changed the default image from `otel/opentelemetry-collector-contrib` to `quay.io/signalfx/splunk-otel-collector`. `$` characters in the configuration need to be doubled up because is parsed twice. (applicable only if custom configuration with `$` was added to this helm chart)

### 💡 Enhancements 💡

- updated the app version to `0.33.0`. This includes changes from the [opentelemetry-collector v0.33.0](https://github.com/open-telemetry/opentelemetry-collector/releases/tag/v0.33.0) and the [opentelemetry-collector-contrib v0.33.0](https://github.com/open-telemetry/opentelemetry-collector-contrib/releases/tag/v0.33.0) releases.
- automatically detect container runtime. (#41)
- doc update: multiline example (#36), performance summary table (#37)

### 🧰 Bug fixes 🧰

- duplicate id issue in filelog operator (#44)