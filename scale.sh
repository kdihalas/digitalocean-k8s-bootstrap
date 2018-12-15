#!/usr/bin/env bash

source .do
echo "## Scaling cluster ${CLUSTER_NAME} in region ${CLUSTER_REGION}"
echo "## Scaling pool ${DROPLET_POOL_NAME} to ${1} nodes"

doctl kubernetes node-pool update ${CLUSTER_NAME} ${DROPLET_POOL_NAME} -c ${1}
