#!/usr/bin/env bash

source lib.sh
STATUS=$(doctl kubernetes list -o json | jq ".[] | select(.name==\"${CLUSTER_NAME}\") | .status.state")
if [ "${STATUS}" == "" ]; then
  echo ":: Creating the kubernetes cluster"
  doctl kubernetes create --name ${CLUSTER_NAME} --node-pools "name=${DROPLET_POOL_NAME};size=${DROPLET_SIZE};count=${DROPLET_COUNT};${DROPLET_TAGS}" --region ${CLUSTER_REGION} --tag-names ${CLUSTER_TAGS} --version ${CLUSTER_VERSION} &> out.txt
  waitKubernetes
else
  if [ "${STATUS}" == '"provisioning"' ]; then
    waitKubernetes
  fi
fi

echo ":: Downloading kubeconfig from DO"
doctl kubernetes kubeconfig dev > kubeconfig

checkKubeconfig

echo ":: Adding prerequisites"
helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/
helm repo add rook-beta https://charts.rook.io/master

echo "::: Creating namespaces"
createNS dashboard
createNS kube-public
createNS monitoring
createNS ingress

echo ":: Installing helm"
echo ":: Creating service accounts"
createSA tiller kube-system
createSA tiller kube-public
createSA do-admin kube-system

echo ":: Creating cluster role bindings"
createCRB cluster-admin-do-admin cluster-admin "kube-system:do-admin"
createCRB cluster-admin-system-tiller cluster-admin "kube-system:tiller"
createCRB cluster-admin-public-tiller cluster-admin "kube-public:tiller"
createCRB cluster-admin-dashboard cluster-admin "dashboard:dashboard-kubernetes-dashboard"

echo ":: Writing token to file .token (use this to login to dashboard)"
kubectl get secret -n kube-system | grep do-admin | awk '{print $1}' | kubectl get secret -n kube-system -o jsonpath='{.items[0].data.token}' | base64 -d > .token

echo ":: Initializing helm"
helm init --force-upgrade --service-account tiller --tiller-namespace kube-public &>> out.txt
helm init --force-upgrade --service-account tiller --tiller-namespace kube-system &>> out.txt

echo ":: Waiting tiller to start"

sleep 20;

echo ":: Instaling the addons"
echo ":: Installing nginx controller"
helm upgrade --tiller-namespace kube-public --namespace ingress --force --install ingress stable/nginx-ingress -f config/ingress/values.yaml &>> out.txt

echo ":: Installing prometheus operator and kube-prometheus"
helm upgrade --tiller-namespace kube-public --namespace monitoring --force --install prometheus-operator coreos/prometheus-operator &>> out.txt
helm upgrade --tiller-namespace kube-public --namespace monitoring --force --install kube-prometheus coreos/kube-prometheus -f config/monitoring/values.yaml &>> out.txt
echo ":: To access grafana run:  kubectl port-forward -n monitoring service/kube-prometheus-grafana 8080:80 and open http://localhost:8080"

echo ":: Installing kubrnetes dashboard"
helm upgrade --tiller-namespace kube-public --namespace dashboard --force --install dashboard stable/kubernetes-dashboard -f config/dashboard/values.yaml &>> out.txt
echo ":: To login to cluster run: kubectl port-forward -n dashboard service/dashboard-kubernetes-dashboard 8080:443 and use the provided token in .token file"
