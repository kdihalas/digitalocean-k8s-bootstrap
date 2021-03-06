#!/usr/bin/env bash
source .do

exec 1>out.stdout.log
exec 2>out.stderr.log

waitKubernetes() {
  echo ":: Waiting for kubernetes cluster to start"
  while true; do
    STATUS=$(doctl kubernetes cluster list -o json | jq ".[] | select(.name==\"${CLUSTER_NAME}\") | .status.state")
    if [ "${STATUS}" != '"provisioning"' ]; then
      break
    fi
    sleep 5;
  done
}

waitForTiller() {
  while true; do
    STATUS=$(kubectl get pod -n $1 -l app=helm -o json | jq '.items[0].status.phase')
    if [ "${STATUS}" == '"Running"' ]; then
      break;
    fi
    sleep 5;
  done
}

createKubeconfig() {
  doctl kubernetes cluster kubeconfig show ${CLUSTER_NAME} > kubeconfig
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
