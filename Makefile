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

# ifdef IMAGE_DASHBOARD
#   IMAGE_DASHBOARD_FIELD = , "dashboardImage": "$(IMAGE_DASHBOARD)"
# endif

APP_PARAMETERS ?= { \
  "name": "$(NAME)", \
  "namespace": "$(NAMESPACE)" \
  $(IMAGE_DASHBOARD_FIELD) \
}

APP_TEST_PARAMETERS ?= "{}"

TESTER_IMAGE ?= $(REGISTRY)/dashboard/tester:$(TAG)

app/build:: .build/dashboard/deployer \
            .build/dashboard/cert-manager-controller \
            .build/dashboard/cert-manager-acmesolver \
            .build/dashboard/cert-manager-webhook \
            .build/dashboard/cert-manager-cainjector

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


# cert-manager images
.build/dashboard/cert-manager-%: .build/var/CERT_MANAGER_TAG \
                                 .build/var/TAG \
                                 | .build/dashboard
	docker pull quay.io/jetstack/cert-manager-$*:$(CERT_MANAGER_TAG)
	docker tag quay.io/jetstack/cert-manager-$*:$(CERT_MANAGER_TAG) \
	    "$(REGISTRY)/dashboard/cert-manager-$*:$(TAG)"
	docker push "$(REGISTRY)/dashboard/cert-manager-$*:$(TAG)"
	@touch "$@"


## Build the manifests

.build/manifest: | .build
	mkdir "$@"

.build/charts: | .build
	mkdir "$@"

.build/charts/stack: .build/var/STACK_CHART_VERSION | .build/charts
	# https://github.com/helm/helm/issues/5773
	cd .build/charts && \
	helm fetch presslabs/stack --version $(STACK_CHART_VERSION) --untar


.build/manifest/charts: | .build/manifest
	mkdir "$@"


.build/manifest/charts/stack: manifest/values.yaml \
                              .build/charts/stack \
                              | .build/manifest/charts
	helm template .build/charts/stack -f manifest/values.yaml \
			--name '$${name}' --namespace '$${namespace}' \
			--output-dir .build/manifest/charts


.build/manifest/%: $(shell find manifest -name '*.yaml') | .build/manifest
	rm -rf "$@"
	cp -r manifest/$* "$@"


.build/manifest/manifest_deployer.yaml: manifest/* \
                               .build/manifest/charts/stack \
                               .build/manifest/kustomization.yaml \
                               .build/manifest/deployer \
                               .build/manifest/job \
                               | .build/manifest
	kustomize build .build/manifest/deployer -o "$@" \
		--load_restrictor none


.build/manifest/manifest_job.yaml: manifest/* \
																	 .build/manifest/charts/stack \
																	 .build/manifest/kustomization.yaml \
																	 .build/manifest/deployer \
																	 .build/manifest/job \
                                   | .build/manifest
	kustomize build .build/manifest/job/chart -o "$@" \
		--load_restrictor none


.build/manifests.yaml.template: .build/manifest/manifest_deployer.yaml \
                                .build/manifest/manifest_job.yaml \
                                | .build
	rm -f "$@"
	# this will create the config map with additional required resources (e.g. crds)
	# and the job that applies them
	kustomize build .build/manifest --load_restrictor none -o "$@"

