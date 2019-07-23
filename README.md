# Overview

The Presslabs Dashboard is the scalable Kubernetes-based self-service WordPress hosting, deployment
and management platform.

## Architecture

The Presslabs Dashboard operates over [presslabs/stack](https://github.com/presslabs/stack) which is
a collection of operators used for deploying a WordPress site.

The following operators are included in this application:
 * [**WordPress Operator**](https://github.com/presslabs/wordpress-operator) the operator in charge
   of creating the deployment for a site
 * [**MySQL Operator**](https://github.com/presslabs/mysql-operator) which creates the MySQL
   databases for sites.
 * [**Cert Manager**](https://github.com/jetstack/cert-manager) used for managing and issuance TLS
   certificates.
 * [**Nginx Ingress Controller**](https://github.com/kubernetes/ingress-nginx) for configuring NGINX.
 * [**Prometheus Operator**](https://github.com/coreos/prometheus-operator) used for deploying
   Prometheus for monitoring
 * [**Presslabs Dashboard**]()
 
 
# Installation

## Quick install with Google Cloud Marketplace

Get up and running with a few clicks! Install this Dashboard app to a Google
Kubernetes Engine cluster using Google Cloud Marketplace. Follow the
[on-screen instructions](https://console.cloud.google.com/marketplace/details/google/). 

## Command line instructions

You can use [Google Cloud Shell](https://cloud.google.com/shell/) or a local
workstation to complete these steps.

[![Open in Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/presslabs/dashboard-gcp-marketplace&cloudshell_open_in_editor=README.md)

### Prerequisites

#### Set up command-line tools

You'll need the following tools in your development environment. If you are
using Cloud Shell, these tools are installed in your environment by default.

-   [gcloud](https://cloud.google.com/sdk/gcloud/)
-   [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)
-   [docker](https://docs.docker.com/install/)
-   [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
-   [make](https://www.gnu.org/software/make/)
-   [helm](https://helm.sh/)
-   [kustomize](https://kustomize.io/)

Configure `gcloud` as a Docker credential helper:

```shell
gcloud auth configure-docker
```

#### Create a Google Kubernetes Engine cluster

Create a new cluster from the command line:

```shell
export CLUSTER=wordpress-cluster
export ZONE=us-west1-a

gcloud container clusters create "$CLUSTER" --zone "$ZONE"
```

Configure `kubectl` to connect to the new cluster.

```shell
gcloud container clusters get-credentials "$CLUSTER" --zone "$ZONE"
```

#### Clone this repo

Clone this repo and the associated tools repo:

```shell
git clone --recursive https://github.com/presslabs/dashboard-gcp-marketplace.git
```

#### Install the Application resource definition

An Application resource is a collection of individual Kubernetes components,
such as Services, Deployments, and so on, that you can manage as a group.

To set up your cluster to understand Application resources, run the following
command:

```shell
kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
```

You need to run this command once.

The Application resource is defined by the
[Kubernetes SIG-apps](https://github.com/kubernetes/community/tree/master/sig-apps)
community. The source code can be found on
[github.com/kubernetes-sigs/application](https://github.com/kubernetes-sigs/application).

### Install the Application

Navigate to the cloned repo

```shell
cd dashboard-gcp-marketplace
```

#### Configure the app with environment variables

Choose the instance name and namespace for the app:

```shell
export name=dashboard-1
export namespace=default
```

Set application secrets and configuration like domain name, Google project ID and OIDC credentials:

```shell
export dashboardDomain=domain.example.com
export dashboardProjectID=<google cloud project id>
export dashboardServiceAccountKey=<service account key base64 encoded>
export dashboardOIDCClientID=<oidc client id base64 encoded>
export dashboardOIDCSecret=<oidc secret base64 encoded>
export dashboardOIDCIssuer=<oidc issuer base64 encoded>
```

Configure the container images:

```shell
REGISTRY=gcr.io/presslabs/dashboard
TAG=latest

export dashboardImage="${REGISTRY}/dashboard:${TAG}"

export certManagerImage="${REGISTRY}/cert-manager-controller:${TAG}"
export certManagerImageRegistry="${REGISTRY}/cert-manager-controller"
export certManagerImageTag="${TAG}"
export certAcmeSolverImage="${REGISTRY}/cert-manager-acmesolver:${TAG}"
export certWebhookImage="${REGISTRY}/cert-manager-webhook:${TAG}"
export certWebhookImageRegistry="${REGISTRY}/cert-manager-webhook"
export certWebhookImageTag="${TAG}"
export certCAinjectorImage="${REGISTRY}/cert-manager-cainjector:${TAG}"
export certCAinjectorImageRegistry="${REGISTRY}/cert-manager-cainjector"
export certCAinjectorImageTag="${TAG}"

export promOperatorImage="${REGISTRY}/prometheus-operator:${TAG}"
export promOperatorImageRegistry="${REGISTRY}/prometheus-operator"
export promOperatorImageTag="${TAG}"
export promConfigMapReloadImage="${REGISTRY}/prometheus-configmap-reload:${TAG}"
export promConfigMapReloadImageRegistry="${REGISTRY}/prometheus-configmap-reload"
export promConfigMapReloadImageTag="${TAG}"
export promConfigReloaderImage="${REGISTRY}/prometheus-config-reloader:${TAG}"
export promConfigReloaderImageRegistry="${REGISTRY}/prometheus-config-reloader"
export promConfigReloaderImageTag="${TAG}"
export promImage="${REGISTRY}/prometheus-prometheus:${TAG}"
export promImageRegistry="${REGISTRY}/prometheus-prometheus"
export promImageTag="${TAG}"

export ingressImage="${REGISTRY}/ingress-controller:${TAG}"
export ingressImageRegstry="${REGISTRY}/ingress-controller"
export ingressImageTag="${TAG}"
export ingressDefaultBackendImage="${REGISTRY}/ingress-default-backend:${TAG}"
export ingressDefaultBackendImageRegistry="${REGISTRY}/ingress-default-backend"
export ingressDefaultBackendImageTag="${TAG}"

export mysqlControllerImage="${REGISTRY}/mysql-operator:${TAG}"
export mysqlOrchestratorImage="${REGISTRY}/mysql-orchestrator:${TAG}"
export mysqlSidecarImage="${REGISTRY}/mysql-sidecar:${TAG}"
export mysqlMetricsImage="${REGISTRY}/mysql-metrics:${TAG}"
# all Percona docker images versions that are used by MySQL clusters
export mysqlPerconaImage="${REGISTRY}/mysql-percona:5.7.26"

export wordpressOperatorImage="${REGISTRY}/wordpress-operator:${TAG}"
export wordpressRuntimeImage="${REGISTRY}/wordpress-runtime:${TAG}"
export wordpressRcloneImage="${REGISTRY}/wordpress-rclone:${TAG}"
export wordpressGitCloneImage="${REGISTRY}/wordpress-gitclone:${TAG}"
```

The images above are referenced by
[tag](https://docs.docker.com/engine/reference/commandline/tag). We recommend
that you pin each image to an immutable
[content digest](https://docs.docker.com/registry/spec/api/#content-digests).
This ensures that the installed application always uses the same images, until
you are ready to upgrade. To get the digest for the image, use the following
script:

```shell
for i in \
         "dashboardImage" \
         "certManagerImage" \
         "certAcmeSolverImage" \
         "certWebhookImage" \
         "certCAinjectorImage" \
         "promOperatorImage" \
         "promConfigMapReloadImage" \
         "promConfigReloaderImage" \
         "promImage" \
         "ingressImage" \
         "ingressDefaultBackendImage" \
         "mysqlControllerImage" \
         "mysqlOrchestratorImage" \
         "mysqlSidecarImage" \
         "mysqlMetricsImage" \
         "wordpressOperatorImage" \
         "wordpressRuntimeImage" \
         "wordpressRcloneImage" \
         "wordpressGitCloneImage"; do
  repo=$(echo ${!i} | cut -d: -f1);
  digest=$(docker pull ${!i} | sed -n -e 's/Digest: //p');
  export $i="$repo@$digest";
  env | grep $i;
done
```

Generate a random password for Orchestrator topology user:

```shell
# Install pwgen and base64
sudo apt-get install -y pwgen base64

# Set the Orchestrator topology password
export mysqlOrchestratorPassword="$(pwgen 12 1 | tr -d '\n' | base64)"
```

#### Create a namespace in your Kubernetes cluster

If you use a different namespace than `default`, run the command below to create
a new namespace:

```shell
kubectl create namespace "$namespace"
```

#### Create the Service Accounts

##### Make sure you are a Cluster Admin

Creating custom cluster roles requires being a Cluster Admin. To assign the
Cluster Admin role to your user account, run the following command:

```shell
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user $(gcloud config get-value account)
```

##### Create dedicated Service Accounts

Define the environment variables:

```shell
export serviceAccount="${name}-dashboard"
```

Create the service account:

```shell
kubectl create serviceaccount -n $namespace $serviceAccount
kubectl create clusterrolebinding ${name}_dashboard --clusterrole=cluster-admin --serviceaccount=$serviceAccount
```


#### Generate application manifest

Use `make` to generate application template that contains all needed resources.
```
make .build/manifests.yaml.template
```

#### Expand the application manifest template

Use `envsubst` to expand the template. We recommend that you save the expanded
manifest file for future updates to the application.

```shell
cat .build/manifests.yaml.template | envsubst '$name $namespace $dashboardDomain $dashboardImage $dashboardServiceAccount $dashboardProjectID $dashboardOIDCClient $dashboardOIDCSecret $dashboardOIDCIssuer $serviceAccount $certManagerImageRegistry $certManagerImageTag $certAcmeSolverImageRegistry $certAcmeSolverImageTag  $certWebhookImageRegistry $certWebhookImageTag $certCAinjectorImageRegistry $certCAinjectorImageTag $promOperatorImageRegistry $promOperatorImageTag $promConfigMapReloadImageRegistry $promConfigMapReloadImageTag $promConfigReloaderImageRegistry $promConfigReloaderImageTag $promImageRegistry $promImageTag $ingressImageRegistry $ingressImageTag $ingressDefaultBackendImageRegistry $ingressDefaultBackendImageTag $mysqlControllerImage $mysqlOrchestratorImage $mysqlSidecarImage $mysqlMetricsImage $mysqlPerconaImage $mysqlOrchestratorPassowrd $wordpressOperatorImage $wordpressRuntimeImage $wordpressRcloneImage $wordpressGitCloneImage ' \
  > "${name}_manifest.yaml"
```

#### Apply the manifest to your Kubernetes cluster

Use `kubectl` to apply the manifest to your Kubernetes cluster:

```shell
kubectl apply -f "${name}_manifest.yaml" --namespace "${namespace}"
```

#### View the app in the Google Cloud Platform Console

To get the GCP Console URL for your app, run the following command:

```shell
echo "https://console.cloud.google.com/kubernetes/application/${ZONE}/${CLUSTER}/${namespace}/${name}"
```

To view your app, open the URL in your browser.
