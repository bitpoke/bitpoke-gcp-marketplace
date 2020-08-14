.PHONY: .git.publish
.git.publish:
	@$(MAKE) -f Makefile.new .git.publish

# Convenience makefiles.
include gcloud.Makefile
include var.Makefile
include crd.Makefile

# app.Makefile provides the main targets for installing the
# application.
# It requires several APP_* variables defined as followed.
include app.Makefile

ifeq ($(shell uname -s | tr '[:upper:]' '[:lower:]'),darwin)
	SEDI = sed -i ''
else
	SEDI = sed -i
endif

TAG ?= latest

DASHBOARD_CHART_PATH ?= charts/dashboard-gcm

DASHBOARD_IMAGE ?= gcr.io/press-labs-dashboard/dashboard-gcp-marketplace-amd64
DASHBOARD_TAG ?= $(shell git describe --tags --abbrev=0)
STACK_TAG ?= 0.10.2

$(info ---- TAG = $(TAG))

$(info ---- DASHBOARD_TAG = $(DASHBOARD_TAG))
$(info ---- STACK_TAG = $(STACK_TAG))


APP_DEPLOYER_IMAGE ?= $(REGISTRY)/dashboard/deployer:$(TAG)
NAME ?= dashboard-1

APP_PARAMETERS ?= { \
  "name": "$(NAME)", \
  "namespace": "$(NAMESPACE)", \
  "dashboardDomain": "$(DOMAIN)", \
  "reportingSecret": "$(REPORTING_SECRET)", \
  "gcpWorkloadIdentityEnabled": true, \
  "gcpApplicationManagerEnabled": true \
}

APP_TEST_PARAMETERS ?= "{}"

TESTER_IMAGE ?= $(REGISTRY)/dashboard/tester:$(TAG)

app/build:: .build/dashboard/deployer \
            .build/dashboard/dashboard \
            .build/dashboard/stack-installer

## Republish docker images to Google registry

.build/dashboard: | .build
	mkdir -p "$@"

# build deployer image
.build/dashboard/deployer: deployer/* \
                           manifests \
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
                            .build/var/DASHBOARD_TAG \
                            | .build/dashboard
	$(call republish,\
	       $(DASHBOARD_IMAGE):$(DASHBOARD_TAG),\
	       $(REGISTRY)/dashboard:$(TAG))
	$(call republish,\
				 spaceonfire/k8s-deploy-tools,\
	       $(REGISTRY)/dashboard/k8s-deploy-tools:$(TAG))

	@touch "$@"

.build/dashboard/stack-installer: .build/var/REGISTRY \
                                  .build/var/DASHBOARD_TAG \
                                  .build/var/TAG \
                                  | .build/dashboard
	$(call republish,\
				 quay.io/presslabs/stack-installer:$(STACK_TAG),\
	       $(REGISTRY)/dashboard/stack-installer:$(TAG))

	@touch "$@"



## Build the manifests

.build/manifest: | .build
	mkdir "$@"

.build/manifest/charts: | .build/manifest
	mkdir "$@"

.build/manifest/%: $(shell find manifest -name '*.yaml') | .build/manifest
	rm -rf "$@"
	cp -r manifest/$* "$@"

.build/manifest/charts/dashboard-gcm: manifest/values.yaml \
                                  $(DASHBOARD_CHART_PATH) \
                                  | .build/manifest/charts
	helm dependency update $(DASHBOARD_CHART_PATH)
	helm template $(DASHBOARD_CHART_PATH) -f manifest/values.yaml \
			--name 'helm-release-name' --namespace 'helm-namespace' \
			--kube-version 1.16 \
			--output-dir .build/manifest/charts
# it we need to replace the release name and namespace with our placeholders
	find .build/manifest/charts -type f -print0 | xargs -0 $(SEDI) 's/helm-release-name/$${name}/g'
	find .build/manifest/charts -type f -print0 | xargs -0 $(SEDI) 's/helm-namespace/$${namespace}/g'



KUSTOMIZE ?= "kustomize"

.build/manifest/manifest_globals.yaml: manifest/*.yaml \
                                       .build/manifest/charts/dashboard-gcm \
                                       .build/manifest/globals \
                                       | .build/manifest

	$(KUSTOMIZE) build .build/manifest/globals -o "$@" \
		--load_restrictor none --reorder none


manifest/manifest_dashboard.yaml.template: manifest/*.yaml \
                                 .build/manifest/charts/dashboard-gcm \
                                 .build/manifest/dashboard

	$(KUSTOMIZE) build .build/manifest/dashboard -o "$@" \
		--load_restrictor none


manifest/manifest_globals_job.yaml.template: manifest/*.yaml \
                                 .build/manifest/job \
                                 .build/manifest/manifest_globals.yaml

	$(KUSTOMIZE) build .build/manifest/job -o "$@" \
		--load_restrictor none

manifest/manifest_stack_installer_job.yaml.template: manifest/*.yaml \
                                 .build/manifest/stack_values.yaml \
                                 .build/manifest/cm_values.yaml \
                                 .build/manifest/stack

	$(KUSTOMIZE) build .build/manifest/stack -o "$@" \
		--load_restrictor none


.PHONY: manifests
manifests: manifest/manifest_dashboard.yaml.template \
           manifest/manifest_globals_job.yaml.template \
           manifest/manifest_stack_installer_job.yaml.template

.PHONY: clean-manifests
clean-manifests:
	rm -rf .build/manifest*
	rm -f manifest/manifest_*

# a simple rule to test if the generated manifests are ok
.PHONY: verify-manifests
verify-manifests: clean-manifests manifests
# check for missing files or not used in kustomize
	./scripts/check_files.sh .build/manifest/charts \
	  manifest/dashboard/kustomization.yaml \
	  manifest/globals/kustomization.yaml
