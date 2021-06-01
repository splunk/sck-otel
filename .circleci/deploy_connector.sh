#!/usr/bin/env bash
set -e
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

#Make sure to check and clean previously failed deployment
echo "Checking if previous deployment exist..."
if [ "`helm ls --short`" == "" ]; then
   echo "Nothing to clean, ready for deployment"
else
   helm delete $(helm ls --short)
fi
echo "Deploying sck-otel-connect with latest changes"
helm install ci-sck --set image.repository=$OTEL_CONTRIB_IMAGE \
--set image.tag=$OTEL_CONTRIB_IMAGE_TAG \
--set splunk_hec.index=$CI_INDEX_EVENTS \
--set splunk_hec.token=$CI_SPLUNK_HEC_TOKEN \
--set splunk_hec.endpoint=https://$CI_SPLUNK_HOST:8088/services/collector \
--set containers.containerRuntime=$CONTAINER_RUNTIME \
-f .circleci/sck_otel_values.yaml charts/opentelemetry-collector/
#wait for deployment to finish
until kubectl get pod | grep Running | [[ $(wc -l) == 1 ]]; do
   sleep 1;
done
