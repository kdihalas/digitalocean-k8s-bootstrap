# Fast-food kubernetes for digitalocean
creates a DO kubernetes managed cluster and installs some addons.

### Prerequisites
1. kubectl (1.12)
2. helm (2.11)
3. jq
4. doctl (1.12)
5. Digitalocean token

#### Create a .do file in the same folder with install.sh
```
export DIGITALOCEAN_ENABLE_BETA=1
export DIGITALOCEAN_ACCESS_TOKEN=<your_do_token_here>

export CLUSTER_VERSION="1.12.3-do.1"
export CLUSTER_REGION="fra1"
export CLUSTER_NAME="dev"
export CLUSTER_TAGS="tag=ams"
export DROPLET_POOL_NAME="default"
export DROPLET_SIZE="s-2vcpu-4gb"
export DROPLET_COUNT="3"
export DROPLET_TAGS="tag=workers;tag=default"

```

### Addons
1. nginx-ingress
2. prometheus-operator
3. kube-prometheus
4. kubernetes-dashboard


### First run
1. Run install.sh and wait
```
# ./install.sh
```

2. After the script is done you will have 2 new files and a working cluster: .token, kubeconfig
3. Verify the cluster
```
export KUBECONFIG=KUBECONFIG

kubectl get all --all-namespaces

```
