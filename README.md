# Overview

The Presslabs Dashboard app is a commercial solution that uses advanced cloud technology and the Kubernetes container orchestration platform to scale the most widely used CMS nowadays, WordPress. Presslabs Dashboard provides a versatile and simple to use cloud-native hosting platform that offers the possibility to create, deploy, scale, manage and monitor WordPress sites directly from the dashboard, or right from the Kubernetes cluster using kubectl.

The product was developed as a horizontal scaling solution for WordPress agencies, big publishers, site owners, and hosting companies with millions of users per second struggling to find solutions that combine the Kubernetes flexibility and the security offered by Google Cloud Platform.

[Learn more](https://www.presslabs.com/dashboard/)

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
 * [**Presslabs Dashboard**](https://www.presslabs.com/dashboard/)


# Installation

> ###### NOTE
>
> We recommend you to install the Presslabs Dashboard app with just a few clicks directly from the [Google Cloud Marketplace](https://console.cloud.google.com/marketplace/details/press-labs-public/presslabs-dashboard), but you can also use command line instructions to install it manually.

## Recommended: Quick install with Google Cloud Marketplace

Get up and running with a few clicks! Install this Dashboard app to a Google
Kubernetes Engine cluster using [Google Cloud Marketplace](https://console.cloud.google.com/marketplace/details/press-labs-public/presslabs-dashboard). Check the [Dashboard documentation](https://www.presslabs.com/docs/dashboard/installation/dashboard-prerequisites/) for step by step tutorials.

## Command line instructions

If you want to install Dashboard manually, you can use [Google Cloud Shell](https://cloud.google.com/shell/) or a local
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

#### Enable Application Addon

```shell
gcloud beta container clusters update "$CLUSTER" --zone "$ZONE" --update-addons ApplicationManager=ENABLED
```

For more information about Application Addon, please check
[this](https://cloud.google.com/kubernetes-engine/docs/how-to/add-on/application-delivery#setting_up).

#### Clone this repo

Clone this repo and the associated tools repo:

```shell
git clone --recursive https://github.com/presslabs/dashboard-gcp-marketplace.git
```

### Install the Application

Navigate to the cloned repo

```shell
cd dashboard-gcp-marketplace
```

Select the release branch

```shell
git checkout release-1.6
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
TAG=1.6.0 # you must include the patch version; e.g.: 1.5.0, 1.6.0-rc.1, 1.7.2

export imageDashboardFull="${REGISTRY}/dashboard:${TAG}"
export imageStackInstallerFull="${REGISTRY}/dashboard/stack-installer:${TAG}"
export imageK8sDeployToolsFull="${REGISTRY}/dashboard/k8s-deploy-tools:${TAG}"

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
         "imageDashboardFull" \
         "imageK8sDeployToolsFull" \
         "imageStackInstallerFull"; do
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
[Marketplace](https://console.cloud.google.com/marketplace/kubernetes/config/press-labs-public/presslabs-dashboard?version=1.6)
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
export deployerTag=$TAG

for f in manifest/*.yaml.template; do \
  cat $f | envsubst '$name $namespace $dashboardDomain $imageDashboardFull $imageStackInstallerFull $serviceAccount $reportingSecret $imageK8sDeployToolsFull $dashboardIP $deployerTag' >> "${name}_manifest.yaml"; \
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
