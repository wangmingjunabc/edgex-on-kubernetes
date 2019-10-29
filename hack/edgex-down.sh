#!/bin/bash

#set -e

EDGEX_ROOT=$(dirname "${BASH_SOURCE}")/..

function delete_services {

  rancher kubectl delete -f "${EDGEX_ROOT}/services/consul-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/vault-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/rulesengine-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/export-distro-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/export-client-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/scheduler-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/command-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/data-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/metadata-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/notifications-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/logging-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/mongo-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/ui-edgex-service.yaml"
  rancher kubectl delete -f "${EDGEX_ROOT}/services/modbus-service.yaml"
}

function delete_deployments {

  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/volume-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/consul-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/config-seed-job.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/vault-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/rulesengine-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/export-distro-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/export-client-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/scheduler-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/command-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/data-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/metadata-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/notifications-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/logging-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/mongo-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/ui-deployment.yaml"
  sleep 10
  rancher kubectl delete -f "${EDGEX_ROOT}/deployments/device-modbus-deployment.yaml"
  sleep 10
}

echo "Deleting EdgeX deployments now!"
delete_deployments
echo "EdgeX deployments created successfully!"

echo "Deleting EdgeX services now!"
delete_services
echo "EdgeX services deleted successfully !"

