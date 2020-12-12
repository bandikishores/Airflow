BIN      = $(GOPATH)/bin
PACKAGE  = workflow-service
BASE     = $(PWD)
DOCKER   = docker
PYTHON   = python3
PIP      = pip3
GOENV 	 = env GO111MODULE=on GOPRIVATE=github.com/bandikishores
GO       = $(GOENV) go
GODOC    = godoc
GOFMT    = gofmt
PKGS     = $(or $(PKG),$(shell cd $(BASE)/bootstrap && env GOPATH=$(GOPATH) $(GO) list ./... | grep main))
AIRFLOW_VERSION = 1.10.12
GIT_COMMIT    ?= $(shell git describe --always --match=v* 2> /dev/null || echo unknown)

# Versioning
PATCH_VERSION ?= $(shell if [ -z "$(BUILD_NUMBER)" ] && [ "$(BUILD_NUMBER)xxx" == "xxx" ]; then echo "dev"; else echo $(BUILD_NUMBER); fi)

# This needs to be manually updated according to semver rules
VERSION ?= v0.2.$(PATCH_VERSION)

# Prod image names
IMAGE_VERSION = $(VERSION)-$(GIT_COMMIT)
IMAGE_BASE_NAME_PROD = bandi-docker.jfrog.io/$(PACKAGE)
LATEST_IMAGE_PROD = $(IMAGE_BASE_NAME_PROD):latest
IMAGE_NAME_PROD = $(IMAGE_BASE_NAME_PROD):$(IMAGE_VERSION)
IMAGE_NAME_SEMVER_PROD=$(IMAGE_BASE_NAME_PROD):$(VERSION)

# Dev image names
IMAGE_BASE_NAME_DEV = bandi-docker.jfrog.io/$(PACKAGE)
IMAGE_NAME_DEV = $(IMAGE_BASE_NAME_DEV):$(IMAGE_VERSION)
IMAGE_BASE_NAME_BOOTSTRAP = bandi-docker.jfrog.io/workflow-bootstrap
IMAGE_NAME_BOOTSTRAP = $(IMAGE_BASE_NAME_BOOTSTRAP):$(IMAGE_VERSION)
DOCKER_BUILD_ARGS = --rm
DOCKER_BUILD_PROD_ARGS = --rm

.PHONY: all lint build build-bootstrap
all:

# Tools
GOLINT = $(BIN)/golint -set_exit_status
$(BIN)/golint: | $(BASE) ; $(info $(M) installing golint…)
	$Q $(GO) get -u golang.org/x/lint/golint

# Force use of SSH instead of HTTPS for the private repos (BOTH STATEMENTS ARE NEEDED in pipeline)
.PHONY: configure-git
configure-git:
	git config --global --replace-all url."git@bitbucket.org:".insteadOf "https://bitbucket.org"
	git config --global --replace-all url."git@bitbucket.org:bandicom".insteadOf "https://bandi.com/"

# Dependency management
.PHONY: download
download: configure-git
	$Q cd $(BASE) && $(GO) mod download; $(info $(M) retrieving dependencies…)

.PHONY: install-dependencies
install-dependencies: configure-git $(BIN)/golint

.PHONY: lint
lint:
	$Q cd $(BASE)/bootstrap && $(GOLINT) $(PKGS) ; $(info $(M) running golint…)

.PHONY: fmt
fmt: ; $(info $(M) running gofmt…) @ ## Run gofmt on all source files
	@ret=0 && for d in $$($(GO) list -f '{{.Dir}}' ./...); do \
		$(GOFMT) -l -w $$d/*.go || ret=$$? ; \
	 done ; exit $$ret

.PHONY: build-dags
build-dags: ## Build Dags
	$Q cd $(BASE) && $(PYTHON) -m compileall -f airflow-data/dags/; $(info $(M) compiling dags...)

.PHONY: build
build: # Build bootstrap
	@cd $(BASE)/bootstrap && go mod vendor
	$Q cd $(BASE)/bootstrap && $(GO) build -ldflags $(LD_FLAGS) \
		-o bin/bootstrap ./main ; $(info $(M) building bootstrap executable…)

.PHONY: build-all
build-all: build-dags build

.PHONY: docker-build
docker-build: ## Build docker image
	@cd $(BASE)
	DOCKER_IMAGE_NAME=$(IMAGE_NAME_DEV)
	$(DOCKER) build '$(DOCKER_BUILD_ARGS)' \
		-t $(PACKAGE):${PATCH_VERSION} \
		-t $(PACKAGE):$(IMAGE_VERSION) \
		-t $(IMAGE_NAME_DEV) \
		-t $(IMAGE_BASE_NAME_DEV):dev \
		-t $(PACKAGE):dev \
		-f Dockerfile .; \
		$(info $(M) building docker image…)

.PHONY: docker-push
docker-push: docker-build ## Build and publish docker image
	$Q $(DOCKER) push $(IMAGE_NAME_DEV); $(info $(M) pushing docker image…)

.PHONY: docker-push-dev-image
docker-push-dev-image: docker-build
	$Q $(DOCKER) push $(IMAGE_BASE_NAME_DEV):dev; $(info $(M) pushing docker dev image…)	

.PHONY: docker-build-prod
docker-build-prod: ## Build docker image
	@cd $(BASE)
	DOCKER_IMAGE_NAME=$(LATEST_IMAGE_PROD)
	$(DOCKER) build '$(DOCKER_BUILD_PROD_ARGS)' \
		-t $(IMAGE_NAME_PROD) \
		-t $(IMAGE_NAME_SEMVER_PROD) \
		-t $(LATEST_IMAGE_PROD) \
		-f Dockerfile .; \
		$(info $(M) building docker prod image…)

.PHONY: docker-push-prod
docker-push-prod: docker-build-prod ## Build and publish docker image
	$Q echo "$(IMAGE_NAME_PROD)" "$(IMAGE_NAME_SEMVER_PROD)" "$(LATEST_IMAGE_PROD)" | xargs -n 1 $(DOCKER) push; $(info $(M) pushing docker image…)

.PHONY: docker-build-bootstrap
docker-build-bootstrap: #Build docker image for Bootstrap
	@cd $(BASE)
	$(DOCKER) build '$(DOCKER_BUILD_ARGS)' \
		-t $(IMAGE_NAME_BOOTSTRAP) \
		-t $(IMAGE_BASE_NAME_BOOTSTRAP):dev \
		-f bootstrap/Dockerfile .; \
		$(info $(M) building docker image for workflow bootstrap)

.PHONY: build-push-bootstrap
build-push-bootstrap:
	$(info $(M) build-push-bootstrap:)
	$Q $(DOCKER) push $(IMAGE_NAME_BOOTSTRAP); $(info $(M) pushing docker image bootstrap..)

# Create a new tag if the current branch is being merged into master.
.PHONY: master-tag
master-tag:
	git tag $(VERSION)
	git push origin --tags

.PHONY: clean
clean: ; $(info $(M) cleaning…)	@ ## Cleanup everything
	@rm -rf airflow-data/dags/__pycache__