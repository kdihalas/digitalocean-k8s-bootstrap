#!/usr/bin/env bash

source .do

echo ":: Creating the kubernetes cluster"
doctl kubernetes create --name ${CLUSTER_NAME} --node-pools "name=${DROPLET_POOL_NAME};size=${DROPLET_SIZE};count=${DROPLET_COUNT};${DROPLET_TAGS}" --region ${CLUSTER_REGION} --tag-names ${CLUSTER_TAGS} --version ${CLUSTER_VERSION} &> out.txt

echo ":: Waiting for kubernetes cluster to start"
while true; do
  STATUS=$(doctl kubernetes list -o json | jq '.[] | select(.name=="dev") | .status.state')
  if [ "${STATUS}" != '"provisioning"' ]; then
    break
  fi
  sleep 5;
done
echo ":: Downloading kubeconfig from DO"
doctl kubernetes kubeconfig dev > kubeconfig

export KUBECONFIG=$(pwd)/kubeconfig
echo ":: Check if kubeconfig works"
kubectl get nodes
if [ $? -ne 0 ]; then
  echo "Looks like kubeconfig is invalid please debug manually";
  exit -1;
fi

echo ":: Adding prerequisites"
helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/ &>> out.txt
helm repo add rook-beta https://charts.rook.io/master &>> out.txt

echo "::: Creating namespaces"
kubectl create ns dashboard &>> out.txt
kubectl create ns kube-public &>> out.txt
kubectl create ns monitoring &>> out.txt
kubectl create ns storage &>> out.txt
kubectl create ns storage-ceph &>> out.txt
kubectl create ns ingress &>> out.txt

echo ":: Installing helm"
echo ":: Creating service accounts"
kubectl create sa tiller -n kube-system &>> out.txt
kubectl create sa tiller -n kube-public &>> out.txt
kubectl create sa do-admin -n kube-system &>> out.txt

echo ":: Creating cluster role bindings"
kubectl create clusterrolebinding cluster-admin-do-admin --clusterrole=cluster-admin --serviceaccount=kube-system:do-admin &>> out.txt
kubectl create clusterrolebinding cluster-admin-system-tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller &>> out.txt
kubectl create clusterrolebinding cluster-admin-public-tiller --clusterrole=cluster-admin --serviceaccount=kube-public:tiller &>> out.txt
kubectl create clusterrolebinding cluster-admin-dashboard --clusterrole=cluster-admin --serviceaccount=dashboard:dashboard-kubernetes-dashboard &>> out.txt

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
