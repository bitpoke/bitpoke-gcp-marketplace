# Convenience makefiles.
include gcloud.Makefile
include var.Makefile
include crd.Makefile

# app.Makefile provides the main targets for installing the
# application.
# It requires several APP_* variables defined as followed.
include app.Makefile

TAG ?= latest
STACK_CHART_VERSION ?= v0.3.7
CERT_MANAGER_TAG ?= v0.8.1
METRICS_EXPORTER_TAG ?= v0.5.1

$(info ---- TAG = $(TAG))
$(info ---- STACK_CHART_VERSION = $(STACK_CHART_VERSION))
$(info ---- CERT_MANAGER_TAG = $(CERT_MANAGER_TAG))


APP_DEPLOYER_IMAGE ?= $(REGISTRY)/dashboard/deployer:$(TAG)
NAME ?= dashboard-1

APP_PARAMETERS ?= { \
  "name": "$(NAME)", \
  "namespace": "$(NAMESPACE)", \
	"dashboardDomain": "$(DOMAIN)", \
	"dashboardProjectID": "$(GCP_PROJECT_ID)", \
	"dashboardServiceAccountKey": "$(SERVICE_ACCOUNT_KEY)", \
	"dashboardOIDCClientID": "$(OIDC_CLIENT_ID)", \
	"dashboardOIDCSecret": "$(OIDC_SECRET)", \
	"dashboardOIDCIssuer": "$(OIDC_ISSUER)", \
  "mysqlOrchestratorPassword": "$(ORCHESTRATOR_PASSOWRD)", \
	"letsEncryptEmail": "$(LETS_ENCRYPT_EMAIL)" \
}

APP_TEST_PARAMETERS ?= "{}"

TESTER_IMAGE ?= $(REGISTRY)/dashboard/tester:$(TAG)

app/build:: .build/dashboard/deployer \
            .build/dashboard/dashboard \
            .build/dashboard/cert-manager \
            .build/dashboard/prometheus-operator \
					  .build/dashboard/ingress \
					  .build/dashboard/mysql-operator \
					  .build/dashboard/wordpress-operator

## Republish docker images to Google registry

.build/dashboard: | .build
	mkdir -p "$@"

# build deployer image
.build/dashboard/deployer: deployer/* \
                           .build/manifests.yaml.template \
                           schema.yaml \
                           .build/var/APP_DEPLOYER_IMAGE \
                           .build/var/MARKETPLACE_TOOLS_TAG \
                           .build/var/REGISTRY \
                           .build/var/TAG \
                           | .build/dashboard
	docker build \
	    --build-arg REGISTRY="$(REGISTRY)/dashboard" \
	    --build-arg TAG="$(TAG)" \
	    --build-arg MARKETPLACE_TOOLS_TAG="$(MARKETPLACE_TOOLS_TAG)" \
	    --tag "$(APP_DEPLOYER_IMAGE)" \
	    -f deployer/Dockerfile \
	    .
	docker push "$(APP_DEPLOYER_IMAGE)"
	@touch "$@"


define republish
	docker pull $(1)
	docker tag $(1) $(2)
	docker push $(2)
endef

.build/dashboard/dashboard: | .build/dashboard
	$(call republish,\
	       gcr.io/press-labs-stack-public/dashboard:latest,\
	       $(REGISTRY)/dashboard/dashboard:$(TAG))
	$(call republish,\
	       bitnami/kubectl:latest,\
	       $(REGISTRY)/dashboard/kubectl:$(TAG))
	@touch "$@"

# cert-manager images
.build/dashboard/cert-manager: .build/dashboard/cert-manager-controller \
															 .build/dashboard/cert-manager-acmesolver \
															 .build/dashboard/cert-manager-webhook \
															 .build/dashboard/cert-manager-cainjector
	@touch "$@"

.build/dashboard/cert-manager-%: .build/var/TAG \
                                 .build/var/CERT_MANAGER_TAG \
                                 | .build/dashboard
	$(call republish,\
         quay.io/jetstack/cert-manager-$*:$(CERT_MANAGER_TAG),\
         $(REGISTRY)/dashboard/cert-manager-$*:$(TAG))
	@touch "$@"


# prometheus operator images
.build/dashboard/prometheus-operator: | .build/dashboard
	$(call republish,\
         quay.io/coreos/prometheus-operator:v0.30.1,\
         $(REGISTRY)/dashboard/prometheus-operator:$(TAG))
	$(call republish,\
         quay.io/coreos/prometheus-config-reloader:v0.30.1,\
         $(REGISTRY)/dashboard/prometheus-config-reloader:$(TAG))
	$(call republish,\
         quay.io/coreos/configmap-reload:v0.0.1,\
         $(REGISTRY)/dashboard/prometheus-configmap-reload:$(TAG))
	$(call republish,\
         quay.io/prometheus/prometheus:v2.9.1,\
         $(REGISTRY)/dashboard/prometheus-prometheus:$(TAG))
	@touch "$@"


# nginx-ingress operator images
.build/dashboard/ingress: | .build/dashboard
	$(call republish,\
	       quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.24.1,\
         $(REGISTRY)/dashboard/ingress-controller:$(TAG))
	$(call republish,\
	       quay.io/presslabs/default-backend:latest,\
         $(REGISTRY)/dashboard/ingress-default-backend:$(TAG))
	@touch "$@"


# mysql-operator images
.build/dashboard/mysql-operator: .build/dashboard/mysql-percona-5.7.26 \
                                 | .build/dashboard
	$(call republish,\
	       quay.io/presslabs/mysql-operator:0.3.0,\
	       $(REGISTRY)/dashboard/mysql-operator:$(TAG))
	$(call republish,\
	       quay.io/presslabs/mysql-operator-orchestrator:0.3.0,\
	       $(REGISTRY)/dashboard/mysql-orchestrator:$(TAG))
	$(call republish,\
	       quay.io/presslabs/mysql-operator-sidecar:0.3.0,\
	       $(REGISTRY)/dashboard/mysql-sidecar:$(TAG))
	$(call republish,\
	       prom/mysqld-exporter:v0.11.0,\
	       $(REGISTRY)/dashboard/mysql-metrics:$(TAG))
	@touch "$@"

.build/dashboard/mysql-percona-%: | .build/dashboard
	$(call republish,\
	       percona:$*,\
	       $(REGISTRY)/dashboard/mysql-percona:$*)
	@touch "$@"


# wordpress-operator images
.build/dashboard/wordpress-operator: .build/dashboard/wordpress-runtime-5.2-7.3.4-r164 \
                                     | .build/dashboard
	$(call republish,\
	       quay.io/presslabs/wordpress-operator:v0.3.7,\
	       $(REGISTRY)/dashboard/wordpress-operator:$(TAG))
	$(call republish,\
				 docker.io/library/buildpack-deps:stretch-scm,\
	       $(REGISTRY)/dashboard/wordpress-gitclone:$(TAG))
	$(call republish,\
	       quay.io/presslabs/rclone:latest,\
	       $(REGISTRY)/dashboard/wordpress-rclone:$(TAG))
	@touch "$@"

.build/dashboard/wordpress-runtime-%: | .build/dashboard
	$(call republish,\
	       quay.io/presslabs/wordpress-runtime:$*,\
	       $(REGISTRY)/dashbaord/wordpress-operator:$*)
	@touch "$@"

## Build the manifests

.build/manifest: | .build
	mkdir "$@"

.build/manifest/charts: | .build/manifest
	mkdir "$@"

charts:
	mkdir "$@"

charts/stack: .build/var/STACK_CHART_VERSION | charts
	# https://github.com/helm/helm/issues/5773
	cd charts && \
	helm fetch presslabs/stack --version $(STACK_CHART_VERSION) --untar

charts/dashboard: | charts
	# this works only in dashbaord repository
	cp -r ../../chart/dashboard $@

# *_CHART_PATH var is used in development to be able to specify a custom path to a chart
STACK_CHART_PATH ?= charts/stack
.build/manifest/charts/stack: manifest/values_stack.yaml \
                              $(STACK_CHART_PATH) \
                              | .build/manifest/charts
	helm template $(STACK_CHART_PATH) -f manifest/values_stack.yaml \
			--name '$${name}' --namespace '$${namespace}' \
			--kube-version 1.9 \
			--output-dir .build/manifest/charts

DASHBOARD_CHART_PATH ?= charts/dashboard
.build/manifest/charts/dashboard: manifest/values_dashboard.yaml \
                                  $(DASHBOARD_CHART_PATH) \
                                  | .build/manifest/charts
	helm template $(DASHBOARD_CHART_PATH) -f manifest/values_dashboard.yaml \
			--name '$${name}' --namespace '$${namespace}' \
			--kube-version 1.9 \
			--output-dir .build/manifest/charts


.build/manifest/%: $(shell find manifest -name '*.yaml') | .build/manifest
	rm -rf "$@"
	cp -r manifest/$* "$@"


.build/manifest/manifest_deployer.yaml: manifest/* \
                               .build/manifest/charts/stack \
                               .build/manifest/charts/dashboard \
                               .build/manifest/kustomization.yaml \
                               .build/manifest/deployer \
                               .build/manifest/job \
                               | .build/manifest
	kustomize build .build/manifest/deployer -o "$@" \
		--load_restrictor none


.build/manifest/manifest_globals.yaml: manifest/* \
																	 .build/manifest/charts/stack \
                                   .build/manifest/charts/dashboard \
																	 .build/manifest/kustomization.yaml \
																	 .build/manifest/deployer \
																	 .build/manifest/job \
                                   | .build/manifest
	kustomize build .build/manifest/job/globals -o "$@" \
		--load_restrictor none

.build/manifest/manifest_crds.yaml.gz.b64enc: manifest/* \
																	 .build/manifest/job \
                                   | .build/manifest
	kustomize build .build/manifest/job/crds \
		--load_restrictor none | name=$(NAME) envsubst | gzip | base64 > "$@"


.build/manifests.yaml.template: .build/manifest/manifest_deployer.yaml \
                                .build/manifest/manifest_globals.yaml \
                                .build/manifest/manifest_crds.yaml.gz.b64enc \
                                | .build
	rm -f "$@"
	# this will create the config map with additional required resources (e.g. crds)
	# and the job that applies them
	kustomize build .build/manifest --load_restrictor none -o "$@"

