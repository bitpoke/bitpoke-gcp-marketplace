# Convenience makefiles.
include gcloud.Makefile
include var.Makefile
include crd.Makefile

# app.Makefile provides the main targets for installing the
# application.
# It requires several APP_* variables defined as followed.
include app.Makefile

TAG ?= latest

CERT_MANAGER_TAG ?= v0.8.1
PROMETHEUS_OPERATOR_TAG ?= v0.30.1
INGRESS_OPERATOR_TAG ?= 0.24.1
WORDPRESS_OPERATOR_TAG ?= v0.3.7
MYSQL_OPERATOR_TAG ?= 0.3.2

$(info ---- TAG = $(TAG))

$(info ---- CERT_MANAGER_TAG = $(CERT_MANAGER_TAG))
$(info ---- PROMETHEUS_OPERATOR_TAG = $(PROMETHEUS_OPERATOR_TAG))
$(info ---- INGRESS_OPERATOR_TAG = $(INGRESS_OPERATOR_TAG))
$(info ---- WORDPRESS_OPERATOR_TAG = $(WORDPRESS_OPERATOR_TAG))
$(info ---- MYSQL_OPERATOR_TAG = $(MYSQL_OPERATOR_TAG))


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
  "letsEncryptEmail": "$(LETS_ENCRYPT_EMAIL)", \
  "letsEncryptServer": "$(LETS_ENCRYPT_SERVER)" \
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
                           manifest/manifest_deployer.yaml.template \
                           manifest/manifest_job.yaml.template \
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

.build/dashboard/dashboard: .build/var/TAG \
                            .build/var/REGISTRY \
                            | .build/dashboard
	$(call republish,\
	       gcr.io/press-labs-stack-public/dashboard:latest,\
	       $(REGISTRY)/dashboard:$(TAG))
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
                                 .build/var/REGISTRY \
                                 .build/var/CERT_MANAGER_TAG \
                                 | .build/dashboard
	$(call republish,\
         quay.io/jetstack/cert-manager-$*:$(CERT_MANAGER_TAG),\
         $(REGISTRY)/dashboard/cert-manager-$*:$(TAG))
	@touch "$@"


# prometheus operator images
.build/dashboard/prometheus-operator: .build/var/TAG \
                                      .build/var/REGISTRY \
                                      .build/var/PROMETHEUS_OPERATOR_TAG \
                                      | .build/dashboard
	$(call republish,\
         quay.io/coreos/prometheus-operator:$(PROMETHEUS_OPERATOR_TAG),\
         $(REGISTRY)/dashboard/prometheus-operator:$(TAG))
	@touch "$@"


# nginx-ingress operator images
.build/dashboard/ingress: .build/var/TAG \
                          .build/var/REGISTRY \
                          .build/var/INGRESS_OPERATOR_TAG \
                          | .build/dashboard
	$(call republish,\
	       quay.io/kubernetes-ingress-controller/nginx-ingress-controller:$(INGRESS_OPERATOR_TAG),\
         $(REGISTRY)/dashboard/ingress-controller:$(TAG))
	$(call republish,\
	       quay.io/presslabs/default-backend:latest,\
         $(REGISTRY)/dashboard/ingress-default-backend:$(TAG))
	@touch "$@"


# mysql-operator images
.build/dashboard/mysql-operator: .build/var/TAG \
                                 .build/var/REGISTRY \
                                 .build/var/MYSQL_OPERATOR_TAG \
                                 | .build/dashboard
	$(call republish,\
	       quay.io/presslabs/mysql-operator:$(MYSQL_OPERATOR_TAG),\
	       $(REGISTRY)/dashboard/mysql-operator:$(TAG))
	$(call republish,\
	       quay.io/presslabs/mysql-operator-orchestrator:$(MYSQL_OPERATOR_TAG),\
	       $(REGISTRY)/dashboard/mysql-orchestrator:$(TAG))
	@touch "$@"

# wordpress-operator images
.build/dashboard/wordpress-operator: .build/var/TAG \
                                     .build/var/REGISTRY \
                                     .build/var/WORDPRESS_OPERATOR_TAG \
                                     | .build/dashboard
	$(call republish,\
	       quay.io/presslabs/wordpress-operator:$(WORDPRESS_OPERATOR_TAG),\
	       $(REGISTRY)/dashboard/wordpress-operator:$(TAG))
	@touch "$@"

## Build the manifests

.build/manifest: | .build
	mkdir "$@"

.build/manifest/charts: | .build/manifest
	mkdir "$@"

DASHBOARD_CHART_PATH ?= charts/dashboard-gcm
.build/manifest/charts/dashboard-gcm: manifest/values.yaml \
                                  $(DASHBOARD_CHART_PATH) \
                                  | .build/manifest/charts
	helm dependency update $(DASHBOARD_CHART_PATH)
	helm template $(DASHBOARD_CHART_PATH) -f manifest/values.yaml \
			--name '$${name}' --namespace '$${namespace}' \
			--kube-version 1.10 \
			--output-dir .build/manifest/charts


.build/manifest/%: $(shell find manifest -name '*.yaml') | .build/manifest
	rm -rf "$@"
	cp -r manifest/$* "$@"


.build/manifest/manifest_globals.yaml: manifest/*.yaml \
                                       .build/manifest/charts/dashboard-gcm \
                                       .build/manifest/globals \
                                       | .build/manifest

	kustomize build .build/manifest/globals -o "$@" \
		--load_restrictor none


.build/manifest/manifest_crds.yaml.gz.b64enc: manifest/*.yaml \
                                              .build/manifest/charts/dashboard-gcm \
                                              .build/manifest/crds \
                                              | .build/manifest

# the CRDs are too long to sore them in a configmap so we achieve them before set in a config map.
# NOTE that gzip -n is used to make zipping idempotent, else the timestamp gets updated every time
# the file is created.
	kustomize build .build/manifest/crds \
		--load_restrictor none | name=$(NAME) envsubst | gzip -n | base64 > "$@"


manifest/manifest_deployer.yaml.template: manifest/*.yaml \
                                 .build/manifest/charts/dashboard-gcm \
                                 .build/manifest/deployer

	kustomize build .build/manifest/deployer -o "$@" \
		--load_restrictor none


manifest/manifest_job.yaml.template: manifest/*.yaml \
                                 .build/manifest/job \
                                 .build/manifest/manifest_globals.yaml \
                                 .build/manifest/manifest_crds.yaml.gz.b64enc

	kustomize build .build/manifest/job -o "$@" \
		--load_restrictor none


.PHONY: manifest
manifest: manifest/manifest_deployer.yaml.template manifest/manifest_job.yaml.template

# a simple rule to test if the generated manifests are ok
.PHONY: verify-manifest
verify-manifest: manifest/manifest_deployer.yaml.template manifest/manifest_job.yaml.template
# test if the kustomize replace all fields that needs to be replaced
	[ "$(shell grep SET_IN_KUSTOMIZE $^ )" = "" ] || exit 1
	[ "$(shell grep U0VUX0lOX0tVU1RPTUlaRQ== $^ )" = "" ] || exit 1
