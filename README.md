# Overview
<walkthrough-tutorial-duration duration="15"></walkthrough-tutorial-duration>

The Bitpoke App for WordPress is a commercial solution that uses advanced cloud technology and the Kubernetes container orchestration platform to scale the most widely used CMS nowadays, WordPress. Bitpoke App for WordPress provides a versatile and simple to use cloud-native hosting platform that offers the possibility to create, deploy, scale, manage and monitor WordPress sites directly from the dashboard, or right from the Kubernetes cluster using kubectl.

The product was developed as a horizontal scaling solution for WordPress agencies, big publishers, site owners, and hosting companies with millions of users per second struggling to find solutions that combine the Kubernetes flexibility and the security offered by Google Cloud Platform.

[Learn more](https://www.bitpoke.io/wordpress/)

## Architecture

The Bitpoke App for WordPress operates over [bitpoke/stack](https://github.com/bitpoke/stack) which is
a collection of operators used for deploying a WordPress site.

The following operators are included with this application:
 * [**WordPress Operator**](https://github.com/bitpoke/wordpress-operator) the operator in charge
   of creating the deployment for a site
 * [**MySQL Operator**](https://github.com/bitpoke/mysql-operator) which creates the MySQL
   databases for sites.
 * [**Cert Manager**](https://github.com/jetstack/cert-manager) used for managing and issuance TLS
   certificates.
 * [**Nginx Ingress Controller**](https://github.com/kubernetes/ingress-nginx) for configuring NGINX.
 * [**Prometheus Operator**](https://github.com/prometheus-operator/prometheus-operator) for metrics collection.

## Manual Installation Instructions

> __NOTE__
>
> We recommend you to install the Bitpoke App for WordPress with just a few clicks directly from the [Google Cloud Marketplace](https://console.cloud.google.com/marketplace/product/press-labs-public/presslabs-dashboard), but you can also follow the instructions to install it manually.

To install Bitpoke App for WordPress manually, you can use [Google Cloud Shell](https://ssh.cloud.google.com/?cloudshell_git_repo=https://github.com/bitpoke/bitpoke-gcp-marketplace&cloudshell_git_branch=release-1.8&cloudshell_tutorial=README.md&shellonly=true) or a local
workstation to complete these steps.

[![Open in Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/?cloudshell_git_repo=https://github.com/bitpoke/bitpoke-gcp-marketplace&cloudshell_git_branch=release-1.8&cloudshell_tutorial=README.md&shellonly=true)

## Set up command-line tools

You'll need the following tools in your development environment. If you are
using Cloud Shell, these tools are installed in your environment by default.

-   [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
-   [gcloud](https://cloud.google.com/sdk/gcloud/)
-   [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)
-   [helm](https://helm.sh/docs/intro/quickstart/)

## Create a Google Kubernetes Cluster
> __NOTE__
>
> Bitpoke App for WordPress requires a GKE cluster with [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity), [Config Connector](https://cloud.google.com/config-connector/docs/how-to/install-upgrade-uninstall) and [Application Manager](https://cloud.google.com/kubernetes-engine/docs/how-to/add-on/application-delivery) add ons.

<walkthrough-project-setup></walkthrough-project-setup>
<walkthrough-watcher-constant key="cluster-name" value="bitpoke-1"></walkthrough-watcher-constant>
<walkthrough-watcher-constant key="zone" value="us-west1-a"></walkthrough-watcher-constant>

Create a new cluster from the command line:

```sh
export PROJECT={{project-name}}
export CLUSTER={{cluster-name}}
export ZONE={{zone}}
export MACHINE_TYPE="e2-standard-2"
export NUM_NODES="4"
```

```sh
gcloud container clusters create "$CLUSTER" --zone "$ZONE" --workload-pool=$PROJECT.svc.id.goog --addons=ApplicationManager,ConfigConnector,HorizontalPodAutoscaling --machine-type=${MACHINE_TYPE} --num-nodes=${NUM_NODES}
```

Configure `kubectl` to connect to the new cluster.

```sh
gcloud container clusters get-credentials "$CLUSTER" --zone "$ZONE"
```

### Configure and Verify the provisioned Kubernetes Cluster

#### Verify Application Manager

Application Manager run its components in the `application-system` namespace. You can verify the Pods are ready by running the following command:

```sh
kubectl wait -n application-system --for=condition=available --timeout=10s deployment --all
```

If Application Manager is installed correctly, the output is similar to the following:

```terminal
deployment.apps/application-controller-manager condition met
```

> __NOTE__
>
> Application Manager might not be properly set-up due to issue [201423655](https://issuetracker.google.com/issues/201423655).
> If that's the case follow the instructions in the bug report.

#### Configure Config Connector

To configure the Config Connector, [follow the instructions provided in the Google Cloud Documentation](https://cloud.google.com/config-connector/docs/how-to/install-upgrade-uninstall).

## Add and update the Bitpoke Helm Repository

```sh
helm repo add bitpoke https://helm-charts.bitpoke.io
helm repo update
```

## Prepare the application environment

#### Configure the environment

Choose the instance name and namespace for the app:

```sh
export name=bitpoke-1
export namespace=bitpoke
export domain=domain.example.com
```

> __NOTE__
>
> It's highly recommended to [reserve a dedicated IP](https://cloud.google.com/compute/docs/ip-addresses/reserve-static-external-ip-address) for your deployment. This way, on upgrades your deployed sites won't change heir IP address.

```sh
export loadBalancerIP="YOUR RESERVED IP"
```

#### Create the application namespace

```sh
kubectl create namespace "${namespace}"
```

#### Obtain license key

You can [generate the license key](https://console.cloud.google.com/marketplace/kubernetes/config/press-labs-public/presslabs-dashboard) on the
Marketplace application page from _Deploy via command line_ tab.

Apply the license key

```sh
kubectl -n $namespace apply -f license.yaml
```

Set reporting secret name

```sh
export reportingSecret="$(kubectl -n $namespace get -o jsonpath={.metadata.name} -f license.yaml)"
```

## Install the application


#### Expand the application manifest template

We recommend that you save the expanded
manifest file for future updates to the application.

```sh
helm template -n "${namespace}" "${name}" bitpoke/bitpoke --skip-tests -f values.yaml --set-string marketplace.loadBalancerIP="${loadBalancerIP}" --set-string marketplace.domain="${domain}" --set-string metering.gcp.secretName="${reportingSecret}" > "${name}_manifest.yaml"
```

#### Apply the manifest to your Kubernetes cluster

Use `kubectl` to apply the manifest to your Kubernetes cluster:

```sh
kubectl -n "${namespace}" apply -f "${name}_manifest.yaml"
```

## Congratulations!

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

To get the GCP Console URL for your app, run the following command:

```sh
echo "https://console.cloud.google.com/kubernetes/application/${ZONE}/${CLUSTER}/${namespace}/${name}"
```

To view your app, open the URL in your browser.
