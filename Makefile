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

METRICS_EXPORTER_TAG ?= v0.5.1

$(info ---- TAG = $(TAG))

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
            .build/dashboard/cert-manager-acmesolver

# app/build:: .build/dashboard/deployer \
#             .build/dashboard/dashboard \
#             .build/dashboard/apache-exporter \
#             .build/dashboard/mysql \
#             .build/dashboard/mysqld-exporter \
#             .build/dashboard/prometheus-to-sd \
#             .build/dashboard/tester


.build/dashboard: | .build
	mkdir -p "$@"

.build/dashboard/deployer: deployer/* \
                           manifest/* \
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

.build/dashboard/cert-manager-controller: .build/var/CERT_MANAGER_TAG \
                            .build/var/TAG \
                            | .build/dashboard
	docker pull quay.io/jetstack/cert-manager-controller:$(CERT_MANAGER_TAG)
	docker tag quay.io/jetstack/cert-manager-controller:$(CERT_MANAGER_TAG) \
	    "$(REGISTRY)/dashboard/cert-manager-controller:$(TAG)"
	docker push "$(REGISTRY)/dashboard/cert-manager-controller:$(TAG)"
	@touch "$@"

.build/dashboard/cert-manager-acmesolver: .build/var/CERT_MANAGER_TAG \
                            .build/var/TAG \
                            | .build/dashboard
	docker pull quay.io/jetstack/cert-manager-acmesolver:$(CERT_MANAGER_TAG)
	docker tag quay.io/jetstack/cert-manager-acmesolver:$(CERT_MANAGER_TAG) \
	    "$(REGISTRY)/dashboard/cert-manager-acmesolver:$(TAG)"
	docker push "$(REGISTRY)/dashboard/cert-manager-acmesolver:$(TAG)"
	@touch "$@"

.build/dashboard/dashboard: .build/var/REGISTRY \
                            .build/var/TAG \
                            | .build/dashboard
	docker pull marketplace.gcr.io/google/dashboard5-php7-apache:$(TAG)
	docker tag marketplace.gcr.io/google/dashboard5-php7-apache:$(TAG) \
	    "$(REGISTRY)/dashboard:$(TAG)"
	docker push "$(REGISTRY)/dashboard:$(TAG)"
	@touch "$@"
