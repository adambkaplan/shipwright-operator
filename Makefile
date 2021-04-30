# VERSION defines the project version for the bundle. 
# Update this value when you upgrade the version of your project.
# To re-generate a bundle for another specific version without changing the standard setup, you can:
# - use the VERSION as arg of the bundle target (e.g make bundle VERSION=0.0.2)
# - use environment variables to overwrite this value (e.g export VERSION=0.0.2)
VERSION ?= 0.0.1

# CHANNELS define the bundle channels used in the bundle. 
# Add a new line here if you would like to change its default config. (E.g CHANNELS = "preview,fast,stable")
# To re-generate a bundle for other specific channels without changing the standard setup, you can:
# - use the CHANNELS as arg of the bundle target (e.g make bundle CHANNELS=preview,fast,stable)
# - use environment variables to overwrite this value (e.g export CHANNELS="preview,fast,stable")
ifneq ($(origin CHANNELS), undefined)
BUNDLE_CHANNELS := --channels=$(CHANNELS)
endif

# DEFAULT_CHANNEL defines the default channel used in the bundle. 
# Add a new line here if you would like to change its default config. (E.g DEFAULT_CHANNEL = "stable")
# To re-generate a bundle for any other default channel without changing the default setup, you can:
# - use the DEFAULT_CHANNEL as arg of the bundle target (e.g make bundle DEFAULT_CHANNEL=stable)
# - use environment variables to overwrite this value (e.g export DEFAULT_CHANNEL="stable")
ifneq ($(origin DEFAULT_CHANNEL), undefined)
BUNDLE_DEFAULT_CHANNEL := --default-channel=$(DEFAULT_CHANNEL)
endif
BUNDLE_METADATA_OPTS ?= $(BUNDLE_CHANNELS) $(BUNDLE_DEFAULT_CHANNEL)

# BUNDLE_IMG defines the image:tag used for the bundle. 
# You can use it as an arg. (E.g make bundle-build BUNDLE_IMG=<some-registry>/<project-name-bundle>:<tag>)
BUNDLE_IMG ?= quay.io/shipwright/operator-bundle:$(VERSION)

# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:trivialVersions=true,preserveUnknownFields=false"

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

CONTAINER_ENGINE ?= docker
IMAGE_REPO ?= quay.io/shipwright
TAG ?= latest
IMAGE_PUSH ?= true

all: operator

build: operator

# Run tests
BINDATA = $(shell pwd)/cmd/operator/kodata
test: generate fmt vet manifests
	KO_DATA_PATH=${BINDATA} hack/test-with-envtest.sh

# Build manager binary
operator: generate fmt vet
	go build -o bin/operator ./cmd/operator

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate fmt vet manifests
	go run ./cmd/operator

# Install CRDs into a cluster
install: manifests kustomize
	$(KUSTOMIZE) build config/crd | kubectl apply -f -

# Uninstall CRDs from a cluster
uninstall: manifests kustomize
	$(KUSTOMIZE) build config/crd | kubectl delete -f -

# Deploy controller in the configured Kubernetes cluster in ~/.kube/config
deploy: manifests kustomize
	cd config/manager && $(KUSTOMIZE) edit set image controller="${IMAGE_REPO}/operator:${TAG}"
	$(KUSTOMIZE) build config/default | kubectl apply -f -

# UnDeploy controller from the configured Kubernetes cluster in ~/.kube/config
undeploy:
	$(KUSTOMIZE) build config/default | kubectl delete -f -

# Generate manifests e.g. CRD, RBAC etc.
manifests: controller-gen
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases
	# Fix pluralization of ShipwrightBuilds in generated manifests
	# This can be removed when operator-sdk is upgraded to v1.5.x
	hack/fix-plurals.sh

# Verify manifests were generated and committed to git
verify-manifests: manifests
	hack/check-git-status.sh manifests

# Run go fmt against code
fmt:
	go fmt ./...

# Verify formatting and ensure git status is clean
verify-fmt: fmt
	hack/check-git-status.sh fmt

# Run go vet against code
vet:
	go vet ./...

# Generate code
generate: controller-gen
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

# Verify code was generated and git status is clean
verify-generate: generate
	hack/check-git-status.sh generate

KO_DEST = $(shell pwd)/bin
KO = $(KO_DEST)/ko
ko:
	hack/install-ko.sh $(KO_DEST)

# Build and push the image with ko
ko-publish: ko
	KO_DOCKER_REPO=${IMAGE_REPO} $(KO) publish --base-import-paths --push=${IMAGE_PUSH} -t ${TAG} ./cmd/operator

ko-deploy: manifests kustomize ko
	cd config/manager && $(KUSTOMIZE) edit set image controller="ko://github.com/shipwright-io/operator/cmd/operator"
	$(KUSTOMIZE) build config/default | KO_DOCKER_REPO=${IMAGE_REPO} $(KO) apply --base-import-paths --push=${IMAGE_PUSH} -t ${TAG} -f -

# Download controller-gen locally if necessary
CONTROLLER_GEN = $(shell pwd)/bin/controller-gen
controller-gen:
	$(call go-get-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen@v0.4.1)

# Download kustomize locally if necessary
KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize:
	$(call go-get-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v3@v3.8.7)

OPERATOR_SDK = $(shell pwd)/bin/operator-sdk
operator-sdk:
	hack/install-operator-sdk.sh $(OPERATOR_SDK)

GINKGO = $(shell pwd)/bin/ginkgo
ginkgo:
	$(call go-get-tool,$(GINKGO),github.com/onsi/ginkgo/ginkgo@v1.14.1)

# go-get-tool will 'go get' any package $2 and install it to $1.
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-get-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo "Downloading $(2)" ;\
GOBIN=$(PROJECT_DIR)/bin go get $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef

# Generate bundle manifests and metadata, then validate generated files.
.PHONY: bundle
bundle: manifests kustomize operator-sdk
	$(OPERATOR_SDK) generate kustomize manifests -q
	cd config/manager && $(KUSTOMIZE) edit set image controller="${IMAGE_REPO}/operator:${TAG}"
	$(KUSTOMIZE) build config/manifests | $(OPERATOR_SDK) generate bundle -q --overwrite --version $(VERSION) $(BUNDLE_METADATA_OPTS)
	$(OPERATOR_SDK) bundle validate ./bundle

# Verify bundle manifests were generated and committed to git
verify-bundle: bundle
	hack/check-git-status.sh bundle

# Build the bundle image.
.PHONY: bundle-build
bundle-build:
	$(CONTAINER_ENGINE) build -f bundle.Dockerfile -t $(BUNDLE_IMG) .

test-e2e: ginkgo
	$(GINKGO) --nodes=1 --v --reportPassed ./test/e2e 

test-e2e-operator: ko-deploy test-e2e