#!/usr/bin/env bash
source .do

exec 1>out.stdout.log
exec 2>out.stderr.log

waitKubernetes() {
  echo ":: Waiting for kubernetes cluster to start"
  while true; do
    STATUS=$(doctl kubernetes list -o json | jq ".[] | select(.name==\"${CLUSTER_NAME}\") | .status.state")
    if [ "${STATUS}" != '"provisioning"' ]; then
      break
    fi
    sleep 5;
  done
}

checkKubeconfig() {
  export KUBECONFIG=$(pwd)/kubeconfig
  echo ":: Check if kubeconfig works"
  kubectl get nodes
  if [ $? -ne 0 ]; then
    echo "Looks like kubeconfig is invalid please debug manually";
    exit -1;
  fi
}

createNS() {
  kubectl create ns $1;
}

createSA() {
  kubectl create sa $1 --namespace $2;
}

createCRB() {
  kubectl create clusterrolebinding $1 --clusterrole=$2 --serviceaccount=$3
}
