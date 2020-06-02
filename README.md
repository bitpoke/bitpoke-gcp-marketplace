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
 * **Presslabs Dashboard**
 
 
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

#### Install the Application resource definition and install the Application controller

An Application resource is a collection of individual Kubernetes components,
such as Services, Deployments, and so on, that you can manage as a group.

To set up your cluster to understand Application resources and to install the 
Application controller, run the following command:

```shell
curl https://raw.githubusercontent.com/kubernetes-sigs/application/v0.8.2/deploy/kube-app-manager-aio.yaml \
  | sed 's/quay.io\/kubernetes-sigs\/kube-app-manager:v0.8.1/gcr.io\/press-labs-public\/application-manager:v0.8.2/' \
  | kubectl apply -f -
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

Set application domain name:

```shell
export dashboardDomain=domain.example.com
```

Configure the container images:

```shell
REGISTRY=gcr.io/press-labs-public
TAG=1.4

export dashboardImage="${REGISTRY}/dashboard:${TAG}"
export stackInstallerImage="${REGISTRY}/dashboard/stack-installer:${TAG}"
export kubectlImage=${REGISTRY}/dashboard/k8s-deploy-tools:${TAG}

# optional
export dashboardIP=
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
         "kubectlImage" \
         "stackInstallerImage"; do
  repo=$(echo ${!i} | cut -d: -f1);
  digest=$(docker pull ${!i} | sed -n -e 's/Digest: //p');
  export $i="$repo@$digest";
  env | grep $i;
done
```

#### Create a namespace in your Kubernetes cluster

If you use a different namespace than `default`, run the command below to create
a new namespace:

```shell
kubectl create namespace "$namespace"
```

#### Generate license key

You can obtain the license key, by going to 
[Marketplace](https://console.cloud.google.com/marketplace/kubernetes/config/press-labs-public/presslabs-dashboard?version=1.4) 
and generate it.

Apply the license key

```shell
kubectl apply -f license.yaml -n $namespace
```

Set reporting secret name

```shell
# this is the name the license that can be generated from the product page in Google Marketplace
export reportingSecret=
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
kubectl create clusterrolebinding ${name}_dashboard --clusterrole=cluster-admin --serviceaccount=$namespace:$serviceAccount
```


#### Expand the application manifest template

Use `envsubst` to expand the template. We recommend that you save the expanded
manifest file for future updates to the application.

```shell
for f in manifest/*.yaml.template; do \
  cat $f | envsubst '$name $namespace $dashboardDomain $dashboardImage $stackInstallerImage $serviceAccount $reportingSecret $kubectlImage $dashboardIP' >> "${name}_manifest.yaml"; \
  echo "---" >> "${name}_manifest.yaml"; \
done
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
