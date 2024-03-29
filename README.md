# Overview
<walkthrough-tutorial-duration duration="15"></walkthrough-tutorial-duration>

The Bitpoke App for WordPress is a versatile and simple to use cloud-native hosting platform to create, deploy, scale, manage and monitor WordPress sites.

It is as a multi-tenant, horizontal scaling solution for high-end agencies, publishers, shops, and hosting companies looking for modern solutions that combine the Kubernetes flexibility with the security offered by Google Cloud.

[Learn more](https://www.bitpoke.io/wordpress/)

## Architecture

The Bitpoke App for WordPress operates over [bitpoke/stack](https://github.com/bitpoke/stack) which is an open system built on Kubernetes operators used for deploying a WordPress site.

The following operators are included with this application:
 * [**Bitpoke WordPress Operator**](https://github.com/bitpoke/wordpress-operator) in charge of creating the deployment for a WordPress site.
 * [**Bitpoke MySQL Operator**](https://github.com/bitpoke/mysql-operator) creates and manages the MySQL databases 
 * [**Cert Manager**](https://github.com/jetstack/cert-manager) used for managing and issuing TLS certificates.
 * [**Nginx Ingress Controller**](https://github.com/kubernetes/ingress-nginx) for configuring NGINX.
 * [**Prometheus Operator**](https://github.com/prometheus-operator/prometheus-operator) for metrics collection.

## Manual Installation Instructions

We recommend you to install the Bitpoke App for WordPress with just a few clicks directly from the [Google Cloud Marketplace](https://console.cloud.google.com/marketplace/product/press-labs-public/presslabs-dashboard), but you can also follow these instructions to install it via command line. We recommend using [Google Cloud Shell](https://ssh.cloud.google.com/?cloudshell_git_repo=https://github.com/bitpoke/bitpoke-gcp-marketplace&cloudshell_git_branch=release-1.8&cloudshell_tutorial=README.md&shellonly=true) but a local workstation is also an option. 
If you are not using Cloud Shell, you'll need the following tools installed in your development environment: [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git), [gcloud](https://cloud.google.com/sdk/gcloud/), [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/), [helm](https://helm.sh/docs/intro/quickstart/).

[![Open in Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.svg)](https://ssh.cloud.google.com/?cloudshell_git_repo=https://github.com/bitpoke/bitpoke-gcp-marketplace&cloudshell_git_branch=release-1.8&cloudshell_tutorial=README.md&cloudshell_workspace=.&shellonly=true)

If you're seeing this from Google Cloud Shell, start by pressing `Next`.

## Create a Google Kubernetes Cluster

Bitpoke App for WordPress requires a GKE cluster with [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity), [Config Connector](https://cloud.google.com/config-connector/docs/how-to/install-upgrade-uninstall) and [Application Manager](https://cloud.google.com/kubernetes-engine/docs/how-to/add-on/application-delivery) add ons.

<walkthrough-project-setup></walkthrough-project-setup>
<walkthrough-watcher-constant key="cluster-name" value="bitpoke-1"></walkthrough-watcher-constant>
<walkthrough-watcher-constant key="zone" value="us-west1-a"></walkthrough-watcher-constant>
<walkthrough-watcher-constant key="domain" value="app.mysite.com"></walkthrough-watcher-constant>
<walkthrough-watcher-constant key="ip" value="12.34.56.78"></walkthrough-watcher-constant>


Create a new cluster from the command line:

```sh
export PROJECT={{project-name}}
export CLUSTER={{cluster-name}}
export ZONE={{zone}}
export MACHINE_TYPE="e2-standard-2"
export NUM_NODES="4"
```

Set the project for the current workspace by running:

```sh
gcloud config set project "$PROJECT"
```

For regular production nodes, use the command:

```sh
gcloud beta container clusters create "{{cluster-name}}" --zone "$ZONE" --workload-pool=$PROJECT.svc.id.goog --addons=ApplicationManager,ConfigConnector,HorizontalPodAutoscaling --machine-type=${MACHINE_TYPE} --num-nodes=${NUM_NODES}
```

For a cost-effective preemptible nodes cluster, you should run:

```sh
gcloud beta container clusters create "{{cluster-name}}" --zone "$ZONE" --preemptible --workload-pool=$PROJECT.svc.id.goog --addons=ApplicationManager,ConfigConnector,HorizontalPodAutoscaling --machine-type=${MACHINE_TYPE} --num-nodes=${NUM_NODES}
```

Configure `kubectl` to connect to the new cluster:

```sh
gcloud container clusters get-credentials "{{cluster-name}}" --zone "$ZONE"
```

## Verify Application Manager

Application Manager run its components in the `application-system` namespace. You can verify the Pods are ready by running the following command:

```sh
kubectl wait -n application-system --for=condition=available --timeout=10s deployment --all
```

If Application Manager is installed correctly, the output is similar to the following:

```terminal
deployment.apps/application-controller-manager condition met
```
If not, the Application Manager might not be properly set-up due to issue [201423655](https://issuetracker.google.com/issues/201423655).
If that's the case run the following command:

```sh
kubectl apply -f kalm-gcp-fix-201423655.yaml
```

## Configure Config Connector

First, create an IAM service account, by running in Cloud Shell:

```sh
gcloud iam service-accounts create cnrm-system
```

Second, give elevated permissions to the new service account:

```sh
gcloud projects add-iam-policy-binding {{project-name}} \
    --member="serviceAccount:cnrm-system@{{project-name}}.iam.gserviceaccount.com" \
    --role="roles/owner"
```

Third, create an IAM policy binding between the IAM service account and the predefined Kubernetes service account that Config Connector runs:

```sh
gcloud iam service-accounts add-iam-policy-binding \
cnrm-system@{{project-name}}.iam.gserviceaccount.com \
    --member="serviceAccount:{{project-name}}.svc.id.goog[cnrm-system/cnrm-controller-manager]" \
    --role="roles/iam.workloadIdentityUser"
```

Click <walkthrough-editor-select-regex filePath="configconnector.yaml" regex="PLACEHOLDER">here to edit</walkthrough-editor-select-regex> configconnector.yaml and replace `PLACEHOLDER` with {{project-name}}. Save and close.

Then run the following command:

```sh
kubectl apply -f configconnector.yaml
```

## Prepare the application environment

Add and update the Bitpoke Helm Repository:

```sh
helm repo add bitpoke https://helm-charts.bitpoke.io
helm repo update
```

Next, we'll configure the environment. Choose the instance name and namespace for the app:

```sh
export name=bitpoke-1
export namespace=bitpoke
export domain={{domain}}
```

> __NOTE__
>
> It's highly recommended to [reserve a dedicated IP](https://cloud.google.com/compute/docs/ip-addresses/reserve-static-external-ip-address) for your deployment. so that on upgrades your deployed sites won't change their IP address.

```sh
export loadBalancerIP="{{ip}}"
```

Now we'll create the application namespace:

```sh
kubectl create namespace "${namespace}"
```

## Obtain license key

You need to generate the license key on the Marketplace application page from _Deploy via command line_ [tab](https://console.cloud.google.com/marketplace/kubernetes/config/press-labs-public/presslabs-dashboard).

Now upload the `license.yaml` file to the Google Cloud Shell by clicking on the three vertical dots icon and selecting the file.

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

We recommend that you save the expanded manifest file for future updates to the application.

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
