#!/usr/bin/env bash

source lib.sh
STATUS=$(doctl kubernetes cluster list -o json | jq ".[] | select(.name==\"${CLUSTER_NAME}\") | .status.state")
if [ "${STATUS}" == "" ]; then
  echo ":: Creating the kubernetes cluster"
  doctl kubernetes cluster create ${CLUSTER_NAME} --count ${DROPLET_COUNT} --size ${DROPLET_SIZE} --region ${CLUSTER_REGION} --tag ${CLUSTER_TAGS} --version ${CLUSTER_VERSION}
else
  if [ "${STATUS}" == '"provisioning"' ]; then
    waitKubernetes
  fi
fi

createKubeconfig
checkKubeconfig

echo ":: Adding prerequisites"
helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/
helm repo add rook-beta https://charts.rook.io/master

echo "::: Creating namespaces"
createNs cert-manager
createNS dashboard
createNS kube-public
createNS monitoring
createNS ingress
createNS dns

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
helm init --force-upgrade --service-account tiller --tiller-namespace kube-public
helm init --force-upgrade --service-account tiller --tiller-namespace kube-system

echo ":: Waiting tiller to start"

waitForTiller "kube-public"
waitForTiller "kube-system"

echo ":: Instaling the addons"
echo ":: Installing nginx controller"
helm upgrade --tiller-namespace kube-public --namespace ingress --force --install ingress stable/nginx-ingress -f config/ingress/values.yaml

echo ":: Installing prometheus operator and kube-prometheus"
helm upgrade --tiller-namespace kube-public --namespace monitoring --force --install prometheus-operator coreos/prometheus-operator
helm upgrade --tiller-namespace kube-public --namespace monitoring --force --install kube-prometheus coreos/kube-prometheus -f config/monitoring/values.yaml
echo ":: To access grafana run:  kubectl port-forward -n monitoring service/kube-prometheus-grafana 8080:80 and open http://localhost:8080"

echo ":: Installing kubrnetes dashboard"
helm upgrade --tiller-namespace kube-public --namespace dashboard --force --install dashboard stable/kubernetes-dashboard -f config/dashboard/values.yaml
echo ":: To login to cluster run: kubectl port-forward -n dashboard service/dashboard-kubernetes-dashboard 8080:443 and use the provided token in .token file"

echo ":: Installing external dns"
cat manifests/external-dns.yaml | sed -e "s/YOUR_DIGITALOCEAN_API_KEY/${DIGITALOCEAN_ACCESS_TOKEN}/g" | kubectl apply -f -

echo ":: Installing cert-manager"
helm upgrade --tiller-namespace kube-public --namespace cert-manager --force --install cert-manager stable/cert-manager -f config/cert-manager/values.yaml
