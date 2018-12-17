#!/usr/bin/env bash

source .do
echo "## Scaling cluster ${CLUSTER_NAME} in region ${CLUSTER_REGION}"
echo "## Scaling pool ${DROPLET_POOL_NAME} to ${1} nodes"

echo doctl kubernetes cluster node-pool update ${CLUSTER_NAME} ${CLUSTER_NAME}-default-pool -c ${1}
