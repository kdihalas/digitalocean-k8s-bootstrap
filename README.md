# Fast-food kubernetes for digitalocean
creates a DO kubernetes managed cluster and installs some addons.

## Installing
### Prerequisites
1. kubectl (1.12)
2. helm (2.11)
3. jq
4. doctl (1.12.2-release)
5. Digitalocean token with read/write

### Create a .do file in the same folder with install.sh
```
export DIGITALOCEAN_ENABLE_BETA=1
export DIGITALOCEAN_ACCESS_TOKEN=<your_do_token_here>

export CLUSTER_VERSION="1.12.3-do.1"
export CLUSTER_REGION="fra1"
export CLUSTER_NAME="dev"
export CLUSTER_TAGS="fra"
export DROPLET_SIZE="s-2vcpu-4gb"
export DROPLET_COUNT="3"

```
### Install
1. Run install.sh and wait
```
# ./install.sh
```

2. After the script is done you will have 2 new files and a working cluster: .token, kubeconfig
3. Verify the cluster
```
export KUBECONFIG=$(pwd)/kubeconfig

kubectl get all --all-namespaces

```

### Scale
```
# scale to 10 nodes
./scale.sh 10

# scale down to 3 nodes
./scale.sh 3
```

## Addons
1. nginx-ingress
2. prometheus-operator
3. kube-prometheus
4. kubernetes-dashboard
5. external-dns
6. cert-manager

### TODO
1. add the full values.yaml files in config section
2. deploy rook for persistent storage to avoid the 7 block devices to 1 node limitation
3. create some examples on how to use the cluster
