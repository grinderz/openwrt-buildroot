MAKEFLAGS += --warn-undefined-variables

# this Makefile is an orchestrator: target order matters, parallelism lives in sub-makes
.NOTPARALLEL:

.ONESHELL:
.SHELLFLAGS := -o errtrace -o pipefail -o noclobber -o errexit -o nounset -c
SHELL := bash

UID := $(shell id -u)
export UID
GID := $(shell id -g)
export GID


# local user config (gitignored, see local.mk.example): set OWRT_RELEASE,
# SRC_TARGET, SRC_SUBTARGET etc there instead of editing this Makefile;
# CLI variables still win over it
-include local.mk

# version selection: make OWRT_RELEASE=<name> ... where versions/<name>.mk exists
OWRT_RELEASE ?= 24.10.7
ifeq ($(wildcard versions/$(OWRT_RELEASE).mk),)
    $(error unknown OWRT_RELEASE '$(OWRT_RELEASE)', available: $(basename $(notdir $(wildcard versions/*.mk))))
endif
include versions/$(OWRT_RELEASE).mk

# src target selection, override from local.mk or CLI:
#   make src.all SRC_TARGET=mediatek SRC_SUBTARGET=filogic
SRC_TARGET ?= ramips
SRC_SUBTARGET ?= mt7621

# optional vars from version files; src targets are guarded below
OWRT_BRANCH ?=
OWRT_DIR ?=
SRC_OWRT_GIT ?=

OWRT_BRANCH_SAFE := $(subst /,-,$(OWRT_BRANCH))
# revision straight from the tree: the native getver.sh needs the full
# commit history, which src.clone provides via --filter=blob:none
OWRT_GIT_VERSION := $(shell cd $(OWRT_DIR) 2>/dev/null && ./scripts/getver.sh 2>/dev/null || echo unknown)

ifeq ($(OWRT_VERSION_MAJOR_MINOR), master)
	OWRT_DOWNLOAD_AREA_PATH := snapshots
	MANIFEST_VERSION :=
	IMG_BUILDER_FILE_VERSION :=
	CONFIG_DIR_VERSION := $(OWRT_VERSION_MAJOR_MINOR)
	VALIDATE_VERMAGIC := 0

	ifeq ($(OWRT_BRANCH),)
		GIT_REF := $(OWRT_VERSION_MAJOR_MINOR)
		OWRT_VERSION := $(OWRT_VERSION_MAJOR_MINOR)-$(OWRT_GIT_VERSION)
		IMG_BUILDER_IMAGE_TAG := $(GIT_REF)
	else
		GIT_REF := $(OWRT_BRANCH)
		OWRT_VERSION := $(OWRT_BRANCH_SAFE)-$(OWRT_GIT_VERSION)
		IMG_BUILDER_IMAGE_TAG := $(OWRT_BRANCH_SAFE)
	endif

else
	ifeq ($(OWRT_VERSION_PATCH),)
		OWRT_DOWNLOAD_AREA_PATH := releases/$(OWRT_VERSION_MAJOR_MINOR)-SNAPSHOT
		MANIFEST_VERSION := $(OWRT_VERSION_MAJOR_MINOR)-snapshot-$(OWRT_GIT_VERSION)
		IMG_BUILDER_FILE_VERSION := $(OWRT_VERSION_MAJOR_MINOR)-SNAPSHOT
		CONFIG_DIR_VERSION := $(OWRT_VERSION_MAJOR_MINOR)
		VALIDATE_VERMAGIC := 0

		ifeq ($(OWRT_BRANCH),)
			GIT_REF := openwrt-$(OWRT_VERSION_MAJOR_MINOR)
			OWRT_VERSION := $(OWRT_VERSION_MAJOR_MINOR)-$(OWRT_GIT_VERSION)
		else
			GIT_REF := $(OWRT_BRANCH)
			OWRT_VERSION := $(OWRT_BRANCH_SAFE)-$(OWRT_GIT_VERSION)
		endif

		IMG_BUILDER_IMAGE_TAG := $(GIT_REF)
	else
		OWRT_DOWNLOAD_AREA_PATH := releases/$(OWRT_VERSION_MAJOR_MINOR).$(OWRT_VERSION_PATCH)
		GIT_REF := v$(OWRT_VERSION_MAJOR_MINOR).$(OWRT_VERSION_PATCH)
		MANIFEST_VERSION := $(OWRT_VERSION_MAJOR_MINOR).$(OWRT_VERSION_PATCH)
		IMG_BUILDER_IMAGE_TAG := $(GIT_REF)
		IMG_BUILDER_FILE_VERSION := $(MANIFEST_VERSION)
		OWRT_VERSION := $(OWRT_VERSION_MAJOR_MINOR).$(OWRT_VERSION_PATCH)
		CONFIG_DIR_VERSION := $(OWRT_VERSION)
		VALIDATE_VERMAGIC := 1
	endif
endif

OWRT_DOWNLOAD_AREA_URL := https://downloads.openwrt.org
OWRT_TARGETS_URL := $(OWRT_DOWNLOAD_AREA_URL)/$(OWRT_DOWNLOAD_AREA_PATH)/targets
ARTIFACTS_DIR := artifacts

# flaky-network tolerant curl: --retry alone skips TLS/connection errors,
# --retry-all-errors covers them (costs 3 extra tries on hard 404s)
CURL := curl -sSf --retry 3 --retry-all-errors --retry-delay 2 --max-time 120

SRC_DIR := srcbuilder/$(CONFIG_DIR_VERSION)
SRC_TARGETS_DIR := $(SRC_DIR)/targets
# per-version generic config wins over the shared one
SRC_GENERIC_CONFIG := $(firstword $(wildcard $(SRC_TARGETS_DIR)/generic/config.mk) srcbuilder/generic.mk)
# optional custom feeds appended to feeds.conf.default; per-version wins
SRC_FEEDS_EXTRA := $(firstword $(wildcard $(SRC_DIR)/feeds-extra.conf) $(wildcard srcbuilder/feeds-extra.conf))
SRC_CONFIG_URL := $(OWRT_TARGETS_URL)/$(SRC_TARGET)/$(SRC_SUBTARGET)/config.buildinfo
SRC_QUILT_PATCHES := ../$(SRC_DIR)/patches

SRC_ARTIFACTS_DIR := $(ARTIFACTS_DIR)/src/$(CONFIG_DIR_VERSION)
SRC_ARTIFACTS_ARCHIVE_FILE := openwrt-$(OWRT_VERSION)-$(SRC_TARGET)-$(SRC_SUBTARGET)-$$(date +%F).tar.zst
SRC_BINARY_TARGETS_DIR := $(OWRT_DIR)/bin/targets/$(SRC_TARGET)/$(SRC_SUBTARGET)
# file name prefix shared with the per-config lookup in Img/Builder/Docker/Build
IMG_BUILDER_FILE_PREFIX := openwrt-imagebuilder-$(addsuffix -,$(IMG_BUILDER_FILE_VERSION))
SRC_IMG_BUILDER_FILE := $(IMG_BUILDER_FILE_PREFIX)$(SRC_TARGET)-$(SRC_SUBTARGET).Linux-x86_64.tar.zst

IMG_BUILDER_IMAGE ?= quay.io/openwrt/imagebuilder

IMG_DIR := imagebuilder/$(CONFIG_DIR_VERSION)
IMG_ARTIFACTS_DIR := $(ARTIFACTS_DIR)/img/$(CONFIG_DIR_VERSION)
IMG_TMP_DIR := $(IMG_ARTIFACTS_DIR)/tmp
IMG_FILES_DIR_NAME := files
IMG_GENERIC_FILES_DIR := $(IMG_DIR)/$(IMG_FILES_DIR_NAME)

IMG_SRC_BUILDER_IMAGE ?= varch/openwrt-imagebuilder

SDK_IMAGE ?= quay.io/openwrt/sdk
SDK_BUILDER_IMAGE ?= varch/openwrt-sdkbuilder
SDK_FILE_PATTERN := openwrt-sdk-*$(SRC_TARGET)-$(SRC_SUBTARGET)_*.Linux-x86_64.tar.zst
SDK_LOCAL_PKGS_DIR := sdkbuilder/packages
SDK_FEEDS_EXTRA := sdkbuilder/feeds-extra.conf
# persistent sdk workdir: a named volume on /builder keeps the feeds checkout,
# dl/ and build/staging dirs between pkg builds of the same sdk image, so only
# changed packages recompile. Docker seeds an empty named volume from the
# image on first use. Keyed by builder type + target + release tag; NOT
# refreshed when the image is re-pulled under the same tag — reset with
# pkg.clean.state. Disable per run with SDK_STATE=0.
SDK_STATE ?= 1
SDK_STATE_VOLUME = owrt-pkg-$(notdir $(SDK_DOCKER_IMAGE))-$(SRC_TARGET)-$(SRC_SUBTARGET)-$(IMG_BUILDER_IMAGE_TAG)
# compiler cache inside the sdk container (cache dir lives in the state
# volume, so it only pays off with SDK_STATE=1): speeds up recompiles after
# package version bumps or a pkg.clean.state. Disable with SDK_CCACHE=0.
SDK_CCACHE ?= 1

PKG_ARTIFACTS_DIR := $(ARTIFACTS_DIR)/pkg/$(CONFIG_DIR_VERSION)
PKG_TMP_DIR := $(PKG_ARTIFACTS_DIR)/tmp

ARGS ?=

# archive contents are mostly pre-compressed, so a low zstd level is enough
ARCHIVE_ZSTD_OPTS ?= -T0 -3

# defaults for optional profile/device config.mk vars and target-specific vars,
# so --warn-undefined-variables stays quiet on configs that do not set them
CONFIG_DEVICE ?=
CONFIG_ROOTFS_PARTSIZE ?=
CONFIG_KERNEL_VERMAGIC ?=
CONFIG_DOCKER_IMAGE ?=
CONFIG_DOCKER_PULL ?=
CONFIG_BUILDER_TYPE ?=
SDK_DOCKER_IMAGE ?=
SDK_DOCKER_PULL ?=

# guard: src targets (except src.docker.*) need OWRT_DIR from a version file
SRC_GUARDED_GOALS := $(filter-out src.docker.%,$(filter src.% _src.% asu.meta.%,$(MAKECMDGOALS)))
ifneq ($(SRC_GUARDED_GOALS),)
    ifeq ($(OWRT_DIR),)
        $(error OWRT_DIR is not set: define it in versions/$(OWRT_RELEASE).mk)
    endif
    ifneq ($(filter src.clone,$(SRC_GUARDED_GOALS)),)
        ifeq ($(SRC_OWRT_GIT),)
            $(error SRC_OWRT_GIT is not set: define it in versions/$(OWRT_RELEASE).mk)
        endif
    endif
endif


##@ General


# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk command is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.DEFAULT_GOAL := help
.PHONY: help
help: ## Display this help screen
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
		/^[a-zA-Z_0-9\-\\.%]+:.*?##/ { printf "  \033[36m%-29s\033[0m %s\n", $$1, $$2 } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

define Setup/Vars
	@echo " - setup vars $(1)"
	$(if $(wildcard $(1)),,$(error config not found: $(1)))
	$(eval include $(1))
endef


##@ Info Targets


.PHONY: info
info:
	@echo "OWRT_RELEASE: $(OWRT_RELEASE)"
	@echo "SRC_TARGET: $(SRC_TARGET)"
	@echo "SRC_SUBTARGET: $(SRC_SUBTARGET)"
	@echo "OWRT_GIT_VERSION: $(OWRT_GIT_VERSION)"
	@echo "OWRT_VERSION: $(OWRT_VERSION)"
	@echo "OWRT_VERSION_MAJOR_MINOR: $(OWRT_VERSION_MAJOR_MINOR)"
	@echo "OWRT_VERSION_PATCH: $(OWRT_VERSION_PATCH)"
	@echo "MANIFEST_VERSION: $(MANIFEST_VERSION)"
	@echo "IMG_BUILDER_IMAGE_TAG: $(IMG_BUILDER_IMAGE_TAG)"
	@echo "CONFIG_DIR_VERSION: $(CONFIG_DIR_VERSION)"
	@echo "SRC_QUILT_PATCHES: $(SRC_QUILT_PATCHES)"
	@echo "SRC_TARGETS_DIR: $(SRC_TARGETS_DIR)"
	@echo "VALIDATE_VERMAGIC: $(VALIDATE_VERMAGIC)"


##@ Image Builder Targets


define Img/Make
    @echo " - docker make image"
	docker run --pull=$(CONFIG_DOCKER_PULL) --rm --user root -v "./$(IMG_TMP_DIR)/":/builder/bin \
		-i $(CONFIG_DOCKER_IMAGE):$(CONFIG_TARGET)-$(CONFIG_SUBTARGET)-$(IMG_BUILDER_IMAGE_TAG) /bin/bash << EOT
	set -o errtrace -o pipefail -o noclobber -o errexit -o nounset
	cleanup() {
  		chown -R $(UID):$(GID) /builder/bin
	}

	trap cleanup EXIT

	if [ -f bin/repositories-extra.conf ]; then
		echo " - custom repositories"
		cat bin/repositories-extra.conf >> repositories.conf
		sed -i '/check_signature/d' repositories.conf
	fi

	make image \
		PROFILE=$(CONFIG_PROFILE) \
		PACKAGES="$(CONFIG_CUSTOM_PKGS)" \
		FILES="bin/$(IMG_FILES_DIR_NAME)" \
		$(if $(CONFIG_ROOTFS_PARTSIZE),ROOTFS_PARTSIZE=$(CONFIG_ROOTFS_PARTSIZE))
	EOT
endef

define Img/Archive
	SH_IMG_TARGETS_DIR=$(IMG_TMP_DIR)/targets/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)
	
	if [ ! -d "$${SH_IMG_TARGETS_DIR}" ]; then
		echo " - dir not exists: $${SH_IMG_TARGETS_DIR}"
		exit 1
	fi

	if [ -z "$$(find "$${SH_IMG_TARGETS_DIR}/" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
		echo " - empty dir: $${SH_IMG_TARGETS_DIR}"
		exit 1
	fi

	SH_ARCHIVE_NAME=openwrt-$(OWRT_VERSION)-$(CONFIG_TARGET)-$(CONFIG_SUBTARGET)-$(CONFIG_PROFILE)
	SH_ARCHIVE_NAME=$${SH_ARCHIVE_NAME}$(if $(CONFIG_DEVICE),-$(CONFIG_DEVICE))-$(CONFIG_BUILDER_TYPE)-$$(date +%F).tar.zst
	@echo " - archiving: $${SH_ARCHIVE_NAME}"

	tar -C $(IMG_TMP_DIR) --exclude=./repositories-extra.conf -cf - . \
		| zstd $(ARCHIVE_ZSTD_OPTS) -f -o $(IMG_ARTIFACTS_DIR)/$${SH_ARCHIVE_NAME}
endef

define Img/Files/Copy
	@[ -d "${1}" ] || exit 1
	if [ -d "${1}" ] && [ -n "$$(find "${1}/" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
		echo " - setup files: ${1}"
		mkdir -p "$(IMG_TMP_DIR)/$(IMG_FILES_DIR_NAME)"
		cp -rf ${1}/* $(IMG_TMP_DIR)/$(IMG_FILES_DIR_NAME)/
	fi
endef

define Img/Repos
	SH_REPOS_FILES=""
	for SH_REPOS_SRC in $(IMG_DIR)/repositories-extra.conf \
			$(IMG_DIR)/profiles/$(CONFIG_PROFILE)/repositories-extra.conf \
			$(if $(CONFIG_DEVICE),$(IMG_DIR)/devices/$(CONFIG_DEVICE)/repositories-extra.conf); do
		if [ -f "$${SH_REPOS_SRC}" ]; then
			SH_REPOS_FILES="$${SH_REPOS_FILES} $${SH_REPOS_SRC}"
		fi
	done

	if [ -n "$${SH_REPOS_FILES}" ]; then
		echo " - custom repositories:$${SH_REPOS_FILES}"
		cat $${SH_REPOS_FILES} >| $(IMG_TMP_DIR)/repositories-extra.conf
	fi
endef

define Img/Files
	if [ -d "$(IMG_GENERIC_FILES_DIR)" ]; then
		@$(call Img/Files/Copy,$(IMG_GENERIC_FILES_DIR))
	fi

	SH_DEVICE_FILES_DIR=$(IMG_DIR)/devices/$(CONFIG_DEVICE)/$(IMG_FILES_DIR_NAME)
	if [ -n "$(CONFIG_DEVICE)" ] && [ -d "$${SH_DEVICE_FILES_DIR}" ]; then
		@$(call Img/Files/Copy,$${SH_DEVICE_FILES_DIR})
	fi

	SH_PROFILE_FILES_DIR=$(IMG_DIR)/profiles/$(CONFIG_PROFILE)/$(IMG_FILES_DIR_NAME)
	if [ -n "$(CONFIG_PROFILE)" ] && [ -d "$${SH_PROFILE_FILES_DIR}" ]; then
		@$(call Img/Files/Copy,$${SH_PROFILE_FILES_DIR})
	fi
endef

# always materialize the file so COPY in the Dockerfiles has a source;
# empty file means no extra repositories get baked in
define Img/ReposExtra/File
	mkdir -p $(IMG_TMP_DIR)
	: >| $(IMG_TMP_DIR)/ib-repositories-extra.conf
	for SH_REPOS_SRC in $(IMG_DIR)/repositories-extra.conf \
			$(IMG_DIR)/profiles/$(CONFIG_PROFILE)/repositories-extra.conf \
			$(if $(CONFIG_DEVICE),$(IMG_DIR)/devices/$(CONFIG_DEVICE)/repositories-extra.conf); do
		if [ -f "$${SH_REPOS_SRC}" ]; then
			cat "$${SH_REPOS_SRC}" >> $(IMG_TMP_DIR)/ib-repositories-extra.conf
		fi
	done
endef

define Img/Builder/Docker/Build
    @echo " - imagebuilder docker build"
	$(call Img/ReposExtra/File)
	docker buildx build -t $(CONFIG_DOCKER_IMAGE):$(CONFIG_TARGET)-$(CONFIG_SUBTARGET)-$(IMG_BUILDER_IMAGE_TAG) \
		-f imgbuilder.Dockerfile \
		--build-arg SRC_ARTIFACTS_DIR=$(SRC_ARTIFACTS_DIR) \
		--build-arg SRC_IMG_BUILDER_FILE=$(IMG_BUILDER_FILE_PREFIX)$(CONFIG_TARGET)-$(CONFIG_SUBTARGET).Linux-x86_64.tar.zst \
		--build-arg IB_REPOS_EXTRA_FILE=$(IMG_TMP_DIR)/ib-repositories-extra.conf \
		.
endef

# thin image for asu: official imagebuilder base plus baked-in third-party
# repositories (imgbuilder-official.Dockerfile) — no src build required.
# tagged as $(IMG_SRC_BUILDER_IMAGE) so asu.push.* and the asu registry
# base container pick it up unchanged
define Img/Builder/Official/Docker/Build
    @echo " - imagebuilder docker build (official base + extra repos)"
	$(call Img/ReposExtra/File)
	docker buildx build --pull -t $(IMG_SRC_BUILDER_IMAGE):$(CONFIG_TARGET)-$(CONFIG_SUBTARGET)-$(IMG_BUILDER_IMAGE_TAG) \
		-f imgbuilder-official.Dockerfile \
		--build-arg IB_BASE_IMAGE=$(IMG_BUILDER_IMAGE):$(CONFIG_TARGET)-$(CONFIG_SUBTARGET)-$(IMG_BUILDER_IMAGE_TAG) \
		--build-arg IB_REPOS_EXTRA_FILE=$(IMG_TMP_DIR)/ib-repositories-extra.conf \
		.
endef

define Img/Info
	echo " - src target default packages"
	grep -s DEFAULT_PACKAGES $(OWRT_DIR)/target/linux/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)/target.mk || :

	SH_JQ_RULES='.linux_kernel.vermagic,.default_packages'
	SH_JQ_RULES="$${SH_JQ_RULES}"',.profiles."$(CONFIG_PROFILE)".device_packages,.profiles."$(CONFIG_PROFILE)".images'
	SH_SRC_PROFILE_FILE=$(OWRT_DIR)/bin/targets/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)/profiles.json
	if [ -f "$${SH_SRC_PROFILE_FILE}" ]; then
		echo " - src profile: vermagic, default-packages, device-packages, images"
		jq $${SH_JQ_RULES} "$${SH_SRC_PROFILE_FILE}"
	fi

	echo " - download area profile: vermagic, default-packages, device-packages, images"
	$(CURL) $(OWRT_TARGETS_URL)/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)/profiles.json | jq $${SH_JQ_RULES}
endef

define Img/Download/Pkgs
	echo " - download area profile: default-packages, device-packages"
	$(CURL) $(OWRT_TARGETS_URL)/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)/profiles.json \
		| jq -r '.default_packages + .profiles."$(CONFIG_PROFILE)".device_packages | join(" ")'
endef

$(IMG_ARTIFACTS_DIR):
	@mkdir -p $@

.PHONY: img.clean.tmp
img.clean.tmp: ## Clean tmp dir
	@rm -rf $(IMG_TMP_DIR)

.PHONY: img.recreate.tmp
img.recreate.tmp: img.clean.tmp ## Recreate tmp dir
	# files dir always exists (may stay empty): Img/Make passes FILES=bin/files
	# unconditionally and the imagebuilder fails on a missing path
	@mkdir -p $(IMG_TMP_DIR)/$(IMG_FILES_DIR_NAME)

.PHONY: img.clean.artifacts
img.clean.artifacts: ## Clean image artifacts
	@rm -rf "$(IMG_ARTIFACTS_DIR)"

_img.info.%:
	$(call Setup/Vars,$(IMG_DIR)/profiles/$*/config.mk)

	$(call Img/Info)

# $(1): profiles | devices
define Img/Pipeline
	$(call Setup/Vars,$(IMG_DIR)/$(1)/$*/config.mk)
	$(call Img/Files)
	$(call Img/Repos)
	$(call Img/Make)
	$(call Img/Archive)
endef

_img.profile.%: img.recreate.tmp
	$(call Img/Pipeline,profiles)

_img.device.%: img.recreate.tmp
	$(call Img/Pipeline,devices)

_img.src.build.profile.%:
	$(call Setup/Vars,$(IMG_DIR)/profiles/$*/config.mk)
	$(call Img/Builder/Docker/Build)

_img.src.build.device.%:
	$(call Setup/Vars,$(IMG_DIR)/devices/$*/config.mk)
	$(call Img/Builder/Docker/Build)

_img.official.build.profile.%:
	$(call Setup/Vars,$(IMG_DIR)/profiles/$*/config.mk)
	$(call Img/Builder/Official/Docker/Build)

_img.official.build.device.%:
	$(call Setup/Vars,$(IMG_DIR)/devices/$*/config.mk)
	$(call Img/Builder/Official/Docker/Build)

img.download.pkgs.profile.%:
	$(call Setup/Vars,$(IMG_DIR)/profiles/$*/config.mk)
	$(call Img/Download/Pkgs)

img.download.pkgs.device.%:
	$(call Setup/Vars,$(IMG_DIR)/devices/$*/config.mk)
	$(call Img/Download/Pkgs)

img.profile.%: CONFIG_DOCKER_IMAGE := $(IMG_BUILDER_IMAGE)
img.profile.%: CONFIG_DOCKER_PULL := always
img.profile.%: CONFIG_BUILDER_TYPE := b
img.profile.%: _img.profile.% ## Build image by profile
	@echo

img.src.profile.%: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.src.profile.%: CONFIG_DOCKER_PULL := never
img.src.profile.%: CONFIG_BUILDER_TYPE := s
img.src.profile.%: _img.src.build.profile.% _img.profile.% ## Build image by profile from src image builder
	@echo

img.official.profile.%: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.official.profile.%: CONFIG_DOCKER_PULL := never
img.official.profile.%: CONFIG_BUILDER_TYPE := o
img.official.profile.%: _img.official.build.profile.% _img.profile.% ## Build image by profile from official builder with baked extra repos
	@echo

img.info.profile.%: _img.info.% ## Show info from profile
	@echo

img.device.%: CONFIG_DOCKER_IMAGE := $(IMG_BUILDER_IMAGE)
img.device.%: CONFIG_DOCKER_PULL := always
img.device.%: CONFIG_BUILDER_TYPE := b
img.device.%: _img.device.% ## Build image by device
	@echo

img.src.device.%: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.src.device.%: CONFIG_DOCKER_PULL := never
img.src.device.%: CONFIG_BUILDER_TYPE := s
img.src.device.%: _img.src.build.device.% _img.device.% ## Build image by device from src image builder
	@echo

img.official.device.%: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.official.device.%: CONFIG_DOCKER_PULL := never
img.official.device.%: CONFIG_BUILDER_TYPE := o
img.official.device.%: _img.official.build.device.% _img.device.% ## Build image by device from official builder with baked extra repos
	@echo


##@ SDK Builder Targets


define Sdk/Builder/Docker/Build
	@if [ -z "$$(find $(SRC_ARTIFACTS_DIR) -maxdepth 1 -name '$(SDK_FILE_PATTERN)' -print -quit 2>/dev/null)" ]; then
		echo " - sdk archive not found: $(SRC_ARTIFACTS_DIR)/$(SDK_FILE_PATTERN) (run src build first)"
		exit 1
	fi

	@echo " - sdkbuilder docker build"
	docker buildx build -t $(SDK_BUILDER_IMAGE):$(SRC_TARGET)-$(SRC_SUBTARGET)-$(IMG_BUILDER_IMAGE_TAG) \
		-f sdkbuilder.Dockerfile \
		--build-arg SRC_ARTIFACTS_DIR=$(SRC_ARTIFACTS_DIR) \
		--build-arg SRC_SDK_FILE_PATTERN=$(SDK_FILE_PATTERN) \
		.
endef

# -v mounts for local package sources present under $(SDK_LOCAL_PKGS_DIR); $(1) = package list
Sdk/LocalPkgMounts = \
	$(foreach p,$(1),$(if $(wildcard $(SDK_LOCAL_PKGS_DIR)/$(p)),-v "./$(SDK_LOCAL_PKGS_DIR)/$(p)":/builder/package/$(p)))

# $(1): one or more package names, space separated. One container run builds
# them all: feeds are cloned and the kernel-module set packaged once, not per
# package.
define Sdk/Make
	@echo " - docker make package(s) ${1}"
	# no --user root: the sdk is a full buildroot and refuses to compile as root;
	# pkg.recreate.tmp opens the bin mount for the container's buildbot uid.
	# the build's exit code is captured (not errexit-fatal) so the chown-back
	# run below executes even for a failed compile, then re-raised at the end
	SH_BUILD_RC=0
	docker run --pull=$(SDK_DOCKER_PULL) --rm \
		$(if $(filter 1,$(SDK_STATE)),-v "$(SDK_STATE_VOLUME)":/builder) \
		-v "./$(PKG_TMP_DIR)/":/builder/bin \
		$(call Sdk/LocalPkgMounts,${1}) \
		$(if $(wildcard $(SDK_FEEDS_EXTRA)),-v "./$(SDK_FEEDS_EXTRA)":/builder/feeds-extra.conf:ro) \
		-i $(SDK_DOCKER_IMAGE):$(SRC_TARGET)-$(SRC_SUBTARGET)-$(IMG_BUILDER_IMAGE_TAG) /bin/bash << EOT || SH_BUILD_RC=$$?
	set -o errtrace -o pipefail -o noclobber -o errexit -o nounset

	if [ -f feeds-extra.conf ]; then
		echo " - custom feeds"
		cat feeds.conf.default feeds-extra.conf >| feeds.conf
	fi

	# tolerated failures: with a persisted /builder the tag-pinned feeds
	# (e.g. base;vX.Y.Z) sit on a detached HEAD where the update's git pull
	# fails, but the checkout itself is already correct; a feed that is
	# genuinely missing still fails the feeds install / compile below
	./scripts/feeds update -a || echo " - warning: some feeds failed to update (pinned checkouts?), continuing"
	./scripts/feeds install ${1} || :
	if [ "$(SDK_CCACHE)" = "1" ] && ! grep -q '^CONFIG_CCACHE=y' .config 2>/dev/null; then
		echo 'CONFIG_CCACHE=y' >> .config
	fi
	make defconfig
	make $(foreach p,${1},package/$(p)/compile) -j\$$(nproc)
	EOT

	# the sdk build above runs as the container's buildbot uid (it refuses to
	# compile as root), so the bin mount ends up container-owned and a later
	# pkg.clean.tmp fails on hosts where the uids differ; a root run of the
	# same image (chown only, no compile) hands the files back
	docker run --pull=never --rm --user root -v "./$(PKG_TMP_DIR)/":/builder/bin \
		$(SDK_DOCKER_IMAGE):$(SRC_TARGET)-$(SRC_SUBTARGET)-$(IMG_BUILDER_IMAGE_TAG) chown -R $(UID):$(GID) /builder/bin
	# re-raise a failed build (an `exit` here would also skip the rest of the
	# .ONESHELL recipe on success, e.g. Pkg/Collect)
	[ "$${SH_BUILD_RC}" -eq 0 ]
endef

define Pkg/Collect
	SH_PKG_FILES=$$(find "$(PKG_TMP_DIR)" \( -name '*.ipk' -o -name '*.apk' \) -print 2>/dev/null || :)
	if [ -z "$${SH_PKG_FILES}" ]; then
		echo " - no packages built: $(PKG_TMP_DIR)"
		exit 1
	fi

	echo "$${SH_PKG_FILES}" | while read -r SH_PKG_FILE; do
		echo " - collecting: $${SH_PKG_FILE}"
		cp -f "$${SH_PKG_FILE}" "$(PKG_ARTIFACTS_DIR)/"
	done
endef

$(PKG_ARTIFACTS_DIR):
	@mkdir -p $@

# an sdk build killed before its post-build chown leaves container-owned
# files behind; when the plain rm fails on those, clear the dir contents
# from a root container and remove the (host-owned) dir itself after
.PHONY: pkg.clean.tmp
pkg.clean.tmp: ## Clean pkg tmp dir
	@if [ -d "$(PKG_TMP_DIR)" ] && ! rm -rf $(PKG_TMP_DIR) 2>/dev/null; then
		echo " - container-owned files in $(PKG_TMP_DIR), cleaning via docker"
		docker run --rm --user root -v "./$(PKG_TMP_DIR)/":/cleanup alpine find /cleanup -mindepth 1 -delete
		rm -rf $(PKG_TMP_DIR)
	fi

.PHONY: pkg.recreate.tmp
pkg.recreate.tmp: pkg.clean.tmp ## Recreate pkg tmp dir
	@mkdir -p $(PKG_TMP_DIR)
	chmod 777 $(PKG_TMP_DIR)

.PHONY: pkg.clean.artifacts
pkg.clean.artifacts: ## Clean pkg artifacts
	@rm -rf "$(PKG_ARTIFACTS_DIR)"

.PHONY: pkg.clean.state
pkg.clean.state: ## Remove persistent sdk state volumes for current target/release
	@docker volume ls -q --filter name=owrt-pkg- \
		| grep -F -- "-$(SRC_TARGET)-$(SRC_SUBTARGET)-$(IMG_BUILDER_IMAGE_TAG)" \
		| xargs -r docker volume rm || :

.PHONY: pkg.clean.state.all
pkg.clean.state.all: ## Remove ALL persistent sdk state volumes
	@docker volume ls -q --filter name=owrt-pkg- | xargs -r docker volume rm || :

.PHONY: pkg.clean.feedbuilder
pkg.clean.feedbuilder: ## Remove feeds-extra files generated by openwrt-feed-builder
	@rm -rf "$(ARTIFACTS_DIR)/feedbuilder"

_sdk.docker.build:
	$(call Sdk/Builder/Docker/Build)

# packages for pkg.build / pkg.sdk.build, space separated:
#   make pkg.build PKGS="kmod-amneziawg amneziawg-tools"
PKGS ?=

_pkg.build.%: $(PKG_ARTIFACTS_DIR) pkg.recreate.tmp
	$(call Sdk/Make,$*)
	$(call Pkg/Collect)

_pkg.build: $(PKG_ARTIFACTS_DIR) pkg.recreate.tmp
	$(if $(PKGS),,$(error PKGS is not set, e.g. make pkg.build PKGS="pkg1 pkg2"))
	$(call Sdk/Make,$(PKGS))
	$(call Pkg/Collect)

.PHONY: sdk.build
sdk.build: _sdk.docker.build ## Build sdk builder docker image
	@echo

pkg.%: SDK_DOCKER_IMAGE := $(SDK_IMAGE)
pkg.%: SDK_DOCKER_PULL := always
pkg.%: _pkg.build.% ## Build package from official sdk image
	@echo

pkg.sdk.%: SDK_DOCKER_IMAGE := $(SDK_BUILDER_IMAGE)
pkg.sdk.%: SDK_DOCKER_PULL := never
pkg.sdk.%: _sdk.docker.build _pkg.build.% ## Build package from src sdk builder
	@echo

# explicit rules win over the pkg.% / pkg.sdk.% patterns above
pkg.build: SDK_DOCKER_IMAGE := $(SDK_IMAGE)
pkg.build: SDK_DOCKER_PULL := always
pkg.build: _pkg.build ## Build PKGS="a b c" from official sdk image in one container run
	@echo

pkg.sdk.build: SDK_DOCKER_IMAGE := $(SDK_BUILDER_IMAGE)
pkg.sdk.build: SDK_DOCKER_PULL := never
pkg.sdk.build: _sdk.docker.build _pkg.build ## Build PKGS="a b c" from src sdk builder in one container run
	@echo


##@ ASU Server Targets


ASU_DIR := asu
ASU_COMPOSE := docker compose -f $(ASU_DIR)/docker-compose.yaml
ASU_REGISTRY := localhost:5001
ASU_BASE_CONTAINER_OFFICIAL := ghcr.io/openwrt/imagebuilder
ASU_BASE_CONTAINER_SRC := registry:5000/$(IMG_SRC_BUILDER_IMAGE)
ASU_UPSTREAM_OFFICIAL := https://downloads.openwrt.org
# must be reachable both by the asu server and by clients (owut on routers
# resolves upstream_url itself), so use the public proxy address, which
# routes /releases/ and /.versions.json to the metadata container
# placeholder default (RFC 5737 doc address) — set the real address in local.mk
ASU_UPSTREAM_CUSTOM ?= http://192.0.2.1:8000
ASU_META_DIR := $(ASU_DIR)/metadata
# merge official/third-party feed indexes into published metadata during
# asu.meta.publish (see scripts/asu-merge-feed-indexes.py); 0 = pure src.
# collisions always resolve to the highest version (opkg semantics), so the
# indexes show exactly what the imagebuilder will install
ASU_MERGE_INDEXES ?= 1

define Asu/Up
	@mkdir -p $(ASU_DIR)/public/store $(ASU_META_DIR)
	# --build: the worker image is ASU_IMAGE + a baked-in patch (asu.Dockerfile)
	ASU_BASE_CONTAINER=$(1) ASU_UPSTREAM_URL=$(2) $(ASU_COMPOSE) up -d --build
endef

define Asu/Push
	SH_IMG_TAG=$(CONFIG_TARGET)-$(CONFIG_SUBTARGET)-$(IMG_BUILDER_IMAGE_TAG)
	docker tag "$(IMG_SRC_BUILDER_IMAGE):$${SH_IMG_TAG}" "$(ASU_REGISTRY)/$(IMG_SRC_BUILDER_IMAGE):$${SH_IMG_TAG}"
	docker push "$(ASU_REGISTRY)/$(IMG_SRC_BUILDER_IMAGE):$${SH_IMG_TAG}"
endef

# shared tail of the asu.meta.publish* targets; expects SH_META_VERSION_DIR
# to be set by the caller (same .ONESHELL recipe)
define Asu/Meta/Finalize
	if [ -d "$${SH_META_VERSION_DIR}/packages" ]; then
		# owut and asu discover feeds via packages/<arch>/feeds.conf, which
		# buildbot generates but a plain build does not
		echo " - generating feeds.conf"
		for SH_ARCH_DIR in "$${SH_META_VERSION_DIR}"/packages/*/; do
			[ -d "$${SH_ARCH_DIR}" ] || continue
			SH_ARCH=$$(basename "$${SH_ARCH_DIR}")
			: >| "$${SH_ARCH_DIR}feeds.conf"
			# the feed name (2nd field) must equal the feed directory name,
			# asu resolves packages/<arch>/<name>/ from it
			for SH_FEED_DIR in "$${SH_ARCH_DIR}"*/; do
				SH_FEED=$$(basename "$${SH_FEED_DIR}")
				echo "src/gz $${SH_FEED} $(ASU_UPSTREAM_CUSTOM)/$(OWRT_DOWNLOAD_AREA_PATH)/packages/$${SH_ARCH}/$${SH_FEED}" \
				>> "$${SH_ARCH_DIR}feeds.conf"
			done
		done

		# routers also install packages from the official feeds via opkg,
		# so merge the official indexes in (highest version wins, matching
		# opkg) to keep owut/asu version checks complete; third-party repos
		# baked into the imagebuilder image get mirrored as extra feeds.
		# disable with ASU_MERGE_INDEXES=0 to publish pure src indexes
		if [ "$(ASU_MERGE_INDEXES)" = "1" ]; then
			echo " - merging official feed indexes"
			python3 scripts/asu-merge-feed-indexes.py "$${SH_META_VERSION_DIR}" \
				"$(OWRT_DOWNLOAD_AREA_URL)/$(OWRT_DOWNLOAD_AREA_PATH)" \
				$(wildcard $(IMG_DIR)/repositories-extra.conf) \
			$(wildcard $(IMG_DIR)/profiles/*/repositories-extra.conf) \
			$(wildcard $(IMG_DIR)/devices/*/repositories-extra.conf)
		fi
	fi

	echo " - generating .targets.json"
	cd "$${SH_META_VERSION_DIR}"
	SH_MAP='{}'
	for SH_PROFILES in targets/*/*/profiles.json; do
		SH_T=$${SH_PROFILES#targets/}
		SH_T=$${SH_T%/profiles.json}
		SH_ARCH=$$(jq -r '.arch_packages' "$${SH_PROFILES}")
		SH_MAP=$$(jq -c --arg t "$${SH_T}" --arg a "$${SH_ARCH}" '. + {($$t): $$a}' <<< "$${SH_MAP}")
	done
	jq . <<< "$${SH_MAP}" >| .targets.json
	jq -c . .targets.json

	if [ -n "$(OWRT_VERSION_PATCH)" ]; then
		echo " - generating .versions.json"
		cd - > /dev/null
		# asu needs versions_list; keep previously published versions
		SH_VERSIONS_FILE=$(ASU_META_DIR)/.versions.json
		SH_OLD_LIST=$$([ -f "$${SH_VERSIONS_FILE}" ] && jq -c '.versions_list // []' "$${SH_VERSIONS_FILE}" || echo '[]')
		jq -n --arg v "$(OWRT_VERSION)" --argjson old "$${SH_OLD_LIST}" \
			'{stable_version: $$v, oldstable_version: "", upcoming_version: "",
		  versions_list: (($$old + [$$v]) | unique)}' >| "$${SH_VERSIONS_FILE}"
	fi

	# the bind mount goes stale if $(ASU_META_DIR) was deleted/recreated while
	# the container ran (nginx serves 404 with the files on disk) — restart
	# remounts by path; ignore failure when the asu stack is not up
	cd "$(CURDIR)"
	$(ASU_COMPOSE) restart metadata 2>/dev/null || true
endef

.PHONY: asu.up
asu.up: ## Up ASU server with official imagebuilder
	$(call Asu/Up,$(ASU_BASE_CONTAINER_OFFICIAL),$(ASU_UPSTREAM_OFFICIAL))

.PHONY: asu.src.up
asu.src.up: ## Up ASU server with src imagebuilder (push images via asu.push.*)
	$(call Asu/Up,$(ASU_BASE_CONTAINER_SRC),$(ASU_UPSTREAM_OFFICIAL))

.PHONY: asu.custom.up
asu.custom.up: ## Up ASU server with src imagebuilder and own metadata (custom devices)
	$(call Asu/Up,$(ASU_BASE_CONTAINER_SRC),$(ASU_UPSTREAM_CUSTOM))

# the live openwrt/bin tree only holds the last built target; the src
# archives under artifacts/ persist one per target/version, so publish
# prefers the newest matching archive and falls back to the live tree
.PHONY: asu.meta.publish
asu.meta.publish: ## Publish src bin (profiles, packages) to ASU metadata server
	@SH_SRC_ROOT=$(OWRT_DIR)/bin
	SH_PUB_TMP=
	SH_ARCHIVE=$$(ls -t $(SRC_ARTIFACTS_DIR)/openwrt-$(OWRT_VERSION)-$(SRC_TARGET)-$(SRC_SUBTARGET)-*.tar.zst 2>/dev/null | head -1 || :)
	if [ -n "$${SH_ARCHIVE}" ]; then
		echo " - source archive: $${SH_ARCHIVE}"
		SH_PUB_TMP=$$(mktemp -d)
		trap 'rm -rf "$${SH_PUB_TMP}"' EXIT
		# asu/owut only need json metadata and package indexes; skip
		# firmware images and builder archives (leading * matches the
		# ./targets/... path prefix of the tar members)
		zstd -dc "$${SH_ARCHIVE}" | tar -x -C "$${SH_PUB_TMP}" \
			--exclude '*openwrt-imagebuilder-*' \
			--exclude '*openwrt-sdk-*' \
			--exclude '*openwrt-toolchain-*' \
			--exclude '*.bin' \
			--exclude '*.itb' \
			--exclude '*.img' \
			--exclude '*.img.gz' \
			--exclude '*.trx' \
			--exclude '*.chk' \
			--exclude '*.elf' \
			--exclude '*-initramfs*'
		SH_SRC_ROOT=$${SH_PUB_TMP}
	fi

	SH_SRC_TARGETS_DIR=$${SH_SRC_ROOT}/targets/$(SRC_TARGET)/$(SRC_SUBTARGET)
	if [ ! -f "$${SH_SRC_TARGETS_DIR}/profiles.json" ]; then
		echo " - profiles.json not found: $${SH_SRC_TARGETS_DIR}"
		echo "   (no archive in $(SRC_ARTIFACTS_DIR) and no live tree; run src build first)"
		exit 1
	fi

	SH_META_VERSION_DIR=$(ASU_META_DIR)/$(OWRT_DOWNLOAD_AREA_PATH)
	mkdir -p "$${SH_META_VERSION_DIR}/targets/$(SRC_TARGET)/$(SRC_SUBTARGET)" "$${SH_META_VERSION_DIR}/packages"

	echo " - publishing targets/$(SRC_TARGET)/$(SRC_SUBTARGET)"
	rsync -a --delete \
		--exclude 'openwrt-imagebuilder-*' \
		--exclude 'openwrt-sdk-*' \
		--exclude 'openwrt-toolchain-*' \
		--exclude '*.bin' \
		--exclude '*.itb' \
		--exclude '*.img' \
		--exclude '*.img.gz' \
		--exclude '*.trx' \
		--exclude '*.chk' \
		--exclude '*.elf' \
		--exclude '*-initramfs*' \
		"$${SH_SRC_TARGETS_DIR}/" "$${SH_META_VERSION_DIR}/targets/$(SRC_TARGET)/$(SRC_SUBTARGET)/"

	if [ -d "$${SH_SRC_ROOT}/packages" ]; then
		echo " - publishing packages feeds"
		rsync -a "$${SH_SRC_ROOT}/packages/" "$${SH_META_VERSION_DIR}/packages/"
	fi

	$(call Asu/Meta/Finalize)

# metadata for officially supported devices without a src build: mirror the
# official profiles.json / target package index and seed the arch feed dirs,
# then let the index merge fill them (official feeds + repositories-extra
# mirrors). owut's "missing to-version" for third-party packages blocks
# `owut upgrade`, so the served indexes must include them
.PHONY: asu.meta.publish.official
asu.meta.publish.official: ASU_MERGE_INDEXES := 1
asu.meta.publish.official: ## Publish official metadata + third-party feed indexes (no src build)
	@SH_META_VERSION_DIR=$(ASU_META_DIR)/$(OWRT_DOWNLOAD_AREA_PATH)
	SH_TARGET_DIR=$${SH_META_VERSION_DIR}/targets/$(SRC_TARGET)/$(SRC_SUBTARGET)
	mkdir -p "$${SH_TARGET_DIR}/packages"

	# download to a tmp name and mv into place: a mid-transfer failure must
	# not leave a truncated file where asu/owut expect valid json (curl -o
	# writes as data arrives)
	echo " - mirroring official targets/$(SRC_TARGET)/$(SRC_SUBTARGET) metadata"
	$(CURL) -o "$${SH_TARGET_DIR}/profiles.json.tmp" \
		"$(OWRT_TARGETS_URL)/$(SRC_TARGET)/$(SRC_SUBTARGET)/profiles.json"
	mv "$${SH_TARGET_DIR}/profiles.json.tmp" "$${SH_TARGET_DIR}/profiles.json"
	# core (openwrt_core) index: target packages, owut reads it through
	# asu's /json/v1/.../targets/<target>/index.json
	$(CURL) -o "$${SH_TARGET_DIR}/packages/index.json.tmp" \
		"$(OWRT_TARGETS_URL)/$(SRC_TARGET)/$(SRC_SUBTARGET)/packages/index.json"
	mv "$${SH_TARGET_DIR}/packages/index.json.tmp" "$${SH_TARGET_DIR}/packages/index.json"

	# release kmods live outside the target packages dir; asu merges
	# kmods/<kver>/ into its target index, without the mirror every kmod
	# shows as "missing to-version" in owut and blocks the upgrade
	SH_KVER=$$(jq -r '.linux_kernel | "\(.version)-\(.release)-\(.vermagic)"' "$${SH_TARGET_DIR}/profiles.json")
	if [ "$${SH_KVER}" != "null-null-null" ]; then
		SH_KMODS_DIR=$${SH_TARGET_DIR}/kmods/$${SH_KVER}
		mkdir -p "$${SH_KMODS_DIR}"
		if $(CURL) -o "$${SH_KMODS_DIR}/index.json.tmp" \
				"$(OWRT_TARGETS_URL)/$(SRC_TARGET)/$(SRC_SUBTARGET)/kmods/$${SH_KVER}/index.json"; then
			mv "$${SH_KMODS_DIR}/index.json.tmp" "$${SH_KMODS_DIR}/index.json"
		else
			rm -f "$${SH_KMODS_DIR}/index.json.tmp"
			echo " - kmods index not mirrored (fetch failed; keeping previous if any)"
		fi
	fi

	SH_ARCH=$$(jq -r '.arch_packages' "$${SH_TARGET_DIR}/profiles.json")
	echo " - seeding packages/$${SH_ARCH} feed dirs from the official feeds.conf"
	mkdir -p "$${SH_META_VERSION_DIR}/packages/$${SH_ARCH}"
	$(CURL) "$(OWRT_DOWNLOAD_AREA_URL)/$(OWRT_DOWNLOAD_AREA_PATH)/packages/$${SH_ARCH}/feeds.conf" \
	| while read -r SH_SRC SH_FEED SH_URL; do
		# 2nd field is the feed name; skip blanks and comment lines, a
		# "# comment" would otherwise seed a junk feed dir
		if [ -n "$${SH_FEED}" ] && [ "$${SH_SRC#\#}" = "$${SH_SRC}" ]; then
			mkdir -p "$${SH_META_VERSION_DIR}/packages/$${SH_ARCH}/$${SH_FEED}"
		fi
	done

	$(call Asu/Meta/Finalize)

.PHONY: asu.stop
asu.stop: ## Stop ASU server containers (keep them for restart)
	$(ASU_COMPOSE) stop

.PHONY: asu.restart
asu.restart: ## Restart ASU server containers
	$(ASU_COMPOSE) restart

.PHONY: asu.down
asu.down: ## Destroy ASU server
	$(ASU_COMPOSE) down

.PHONY: asu.destroy
asu.destroy: ## Destroy ASU server including volumes (registry, redis, podman storage)
	$(ASU_COMPOSE) down -v

.PHONY: asu.logs
asu.logs: ## Tail ASU server logs
	$(ASU_COMPOSE) logs -f --tail=100

asu.push.profile.%: ## Push src imagebuilder image for profile to ASU registry
	$(call Setup/Vars,$(IMG_DIR)/profiles/$*/config.mk)
	$(call Asu/Push)

asu.push.device.%: ## Push src imagebuilder image for device to ASU registry
	$(call Setup/Vars,$(IMG_DIR)/devices/$*/config.mk)
	$(call Asu/Push)

# publish for the profile/device's own target: the cycles are invoked with
# a profile name, but asu.meta.publish* resolve the target from
# SRC_TARGET/SRC_SUBTARGET (local.mk), which may point elsewhere — re-invoke
# them with the config's CONFIG_TARGET/CONFIG_SUBTARGET instead
_asu.publish.profile.%:
	$(call Setup/Vars,$(IMG_DIR)/profiles/$*/config.mk)
	@MAKEFLAGS= $(MAKE) asu.meta.publish SRC_TARGET=$(CONFIG_TARGET) SRC_SUBTARGET=$(CONFIG_SUBTARGET)

_asu.publish.device.%:
	$(call Setup/Vars,$(IMG_DIR)/devices/$*/config.mk)
	@MAKEFLAGS= $(MAKE) asu.meta.publish SRC_TARGET=$(CONFIG_TARGET) SRC_SUBTARGET=$(CONFIG_SUBTARGET)

# refuse BEFORE mirroring: publish.official overwrites the src-published
# profiles.json of the target, so running the official cycle for a device
# absent from the official release (almond etc.) would break its asu flow
define Asu/Official/ProfileGuard
	SH_TMP_PROFILES=$$(mktemp)
	trap 'rm -f "$${SH_TMP_PROFILES}"' EXIT
	$(CURL) -o "$${SH_TMP_PROFILES}" "$(OWRT_TARGETS_URL)/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)/profiles.json"
	if ! jq -e --arg p "$(CONFIG_PROFILE)" '.profiles[$$p]' "$${SH_TMP_PROFILES}" > /dev/null; then
		echo " - profile '$(CONFIG_PROFILE)' is not in the official $(CONFIG_TARGET)/$(CONFIG_SUBTARGET) $(OWRT_VERSION) release"
		echo "   official cycle would clobber src metadata — use asu.cycle.profile/device.* (src flow) instead"
		exit 1
	fi
endef

_asu.publish.official.profile.%:
	$(call Setup/Vars,$(IMG_DIR)/profiles/$*/config.mk)
	$(call Asu/Official/ProfileGuard)
	MAKEFLAGS= $(MAKE) asu.meta.publish.official SRC_TARGET=$(CONFIG_TARGET) SRC_SUBTARGET=$(CONFIG_SUBTARGET)

_asu.publish.official.device.%:
	$(call Setup/Vars,$(IMG_DIR)/devices/$*/config.mk)
	$(call Asu/Official/ProfileGuard)
	MAKEFLAGS= $(MAKE) asu.meta.publish.official SRC_TARGET=$(CONFIG_TARGET) SRC_SUBTARGET=$(CONFIG_SUBTARGET)

# order matters: metadata must be published and served before img.src.* —
# its opkg resolves the local_core repo from the metadata server, an empty
# one 404s and the image build dies on missing core packages if the official
# mirror flakes at the same time. sequenced via sub-makes in the recipe:
# make builds explicit-target prerequisites BEFORE pattern-derived ones,
# so a prerequisite list would run asu.custom.up first
asu.cycle.profile.%: ## Publish metadata, build and push src imagebuilder for profile (run src.all first)
	@MAKEFLAGS= $(MAKE) _asu.publish.profile.$*
	MAKEFLAGS= $(MAKE) asu.custom.up
	MAKEFLAGS= $(MAKE) img.src.profile.$*
	MAKEFLAGS= $(MAKE) asu.push.profile.$*
	@echo " - asu cycle done: $*"

asu.cycle.device.%: ## Publish metadata, build and push src imagebuilder for device (run src.all first)
	@MAKEFLAGS= $(MAKE) _asu.publish.device.$*
	MAKEFLAGS= $(MAKE) asu.custom.up
	MAKEFLAGS= $(MAKE) img.src.device.$*
	MAKEFLAGS= $(MAKE) asu.push.device.$*
	@echo " - asu cycle done: $*"

# official-device variant: no src build, official imagebuilder base with
# baked third-party repos, metadata mirrored from downloads.openwrt.org
asu.cycle.official.profile.%: ## Publish official metadata, build and push official-based imagebuilder for profile
	@MAKEFLAGS= $(MAKE) _asu.publish.official.profile.$*
	MAKEFLAGS= $(MAKE) asu.custom.up
	MAKEFLAGS= $(MAKE) img.official.profile.$*
	MAKEFLAGS= $(MAKE) asu.push.profile.$*
	@echo " - asu official cycle done: $*"

asu.cycle.official.device.%: ## Publish official metadata, build and push official-based imagebuilder for device
	@MAKEFLAGS= $(MAKE) _asu.publish.official.device.$*
	MAKEFLAGS= $(MAKE) asu.custom.up
	MAKEFLAGS= $(MAKE) img.official.device.$*
	MAKEFLAGS= $(MAKE) asu.push.device.$*
	@echo " - asu official cycle done: $*"


##@ Deploy Targets


# rsync destination (user@host:/path, no trailing slash), set in local.mk
DEPLOY_DEST ?=
# never sent to the host; under --delete (without --delete-excluded) these
# are also left alone on the receiver
# leading / anchors a pattern to the repo root (bare names match anywhere)
DEPLOY_EXCLUDES := .git .claude .idea /openwrt '/openwrt-*' /artifacts \
	.ccache asu/public asu/metadata .DS_Store __pycache__ \
	'/config.buildinfo*' '*.log' '*.rc'
# host-only state that must survive even an exclude-list mistake: rsync 'P'
# filters forbid deletion regardless of --delete and exclude typos.
# local.mk is deliberately NOT here: the laptop copy is the source of truth
# and overwrites the host one on deploy
DEPLOY_PROTECT := asu/metadata asu/public openwrt artifacts .ccache

DEPLOY_RSYNC = rsync -av --delete \
	$(foreach e,$(DEPLOY_EXCLUDES),--exclude=$(e)) \
	$(foreach p,$(DEPLOY_PROTECT),--filter='P /$(p)') \
	./ "$(DEPLOY_DEST)/"

define Deploy/Check
	@if [ -z "$(DEPLOY_DEST)" ]; then
		echo " - DEPLOY_DEST not set, add to local.mk:"
		echo "   DEPLOY_DEST := user@buildhost:/home/user/src/openwrt-buildroot"
		exit 1
	fi
endef

.PHONY: deploy.diff
deploy.diff: ## Preview deploy (rsync dry-run: what gets sent/deleted)
	$(call Deploy/Check)
	$(DEPLOY_RSYNC) --dry-run

.PHONY: deploy
deploy: ## Deploy repo to DEPLOY_DEST (host-only paths protected from --delete)
	$(call Deploy/Check)
	$(DEPLOY_RSYNC)

# pull the build output the DEPLOY_DEST host produced back here (images,
# imagebuilder/sdk archives, pkg ipks); the local artifacts dir mirrors the
# host's copy, --delete included — preview with fetch.diff first
FETCH_RSYNC = rsync -av --delete "$(DEPLOY_DEST)/$(ARTIFACTS_DIR)/" "./$(ARTIFACTS_DIR)/"

.PHONY: fetch.diff
fetch.diff: ## Preview artifacts fetch from the DEPLOY_DEST build host (rsync dry-run)
	$(call Deploy/Check)
	$(FETCH_RSYNC) --dry-run

.PHONY: fetch
fetch: ## Fetch artifacts/ from the DEPLOY_DEST build host
	$(call Deploy/Check)
	$(FETCH_RSYNC)


##@ Source Builder Docker Targets


.PHONY: src.docker.build
src.docker.build: ## Build src builder image
	docker compose build

.PHONY: src.docker.up
src.docker.up: ## Up src builder container
	docker compose up -d

.PHONY: src.docker.down
src.docker.down: ## Destroy src builder container
	docker compose down -v

.PHONY: src.docker.shell
src.docker.shell: ## Src builder container shell access
	docker compose exec -it srcbuilder /bin/fish


##@ Source Builder Targets


$(SRC_ARTIFACTS_DIR):
	@mkdir -p $@

.PHONY: src.clean.artifacts
src.clean.artifacts: ## Clean src artifacts
	@rm -rf "$(SRC_ARTIFACTS_DIR)"

.PHONY: src.clean.owrt
src.clean.owrt: ## Delete openwrt dir
	@rm -rf "$(OWRT_DIR)"

.PHONY: src.clone
src.clone: ## Src clone openwrt
	# full history but no old blobs: PKG_RELEASE of base-files (and other
	# COMMITCOUNT users) needs the commit count, a shallow clone yields "1"
	# and every such package looks older than the official builds
	@for SH_TRY in 1 2 3; do
		git clone --filter=blob:none --branch $(GIT_REF) $(SRC_OWRT_GIT) $(OWRT_DIR) && break
		# partial clone dir blocks the next attempt
		rm -rf "$(OWRT_DIR)"
		[ "$${SH_TRY}" -lt 3 ] || { echo " - clone failed after 3 tries"; exit 1; }
		echo " - clone failed, retrying ($${SH_TRY}/3)"
		sleep 5
	done

	# releases: pin REVISION via the version file to the official value —
	# the release tag commit itself yields a different r-number/hash, and
	# package version strings must match the official feeds byte for byte.
	# branches/snapshots need no file, the native getver.sh reads git live
	if [ -n "$(OWRT_VERSION_PATCH)" ]; then
		$(CURL) -o "$(OWRT_DIR)/version" "$(OWRT_TARGETS_URL)/$(SRC_TARGET)/$(SRC_SUBTARGET)/version.buildinfo"
		echo " - pinned REVISION: $$(cat $(OWRT_DIR)/version)"
	fi

.PHONY: src.pull
src.pull: ## Src pull
	@pushd $(OWRT_DIR)
	git pull
	# stale version file would override the native getver.sh git logic
	rm -f version
	popd

src.owrt.%: ## Src openwrt make custom command (target/linux/clean)
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) $*

.PHONY: src.check.umask
src.check.umask: ## Src check umask https://github.com/openwrt/openwrt/issues/9545
	@umask=$$(umask)
	if [ "$$umask" != "0002" ] && [ "$$umask" != "0022" ]; then
		echo " - invalid umask: $$umask"
		exit 1
	fi

.PHONY: src.install.feeds
src.install.feeds: ## Src install feeds
	@if [ -n "$(SRC_FEEDS_EXTRA)" ]; then
		echo " - custom feeds: $(SRC_FEEDS_EXTRA)"
		{
			echo "# generated by openwrt-buildroot from $(SRC_FEEDS_EXTRA), do not edit"
			cat "$(OWRT_DIR)/feeds.conf.default" "$(SRC_FEEDS_EXTRA)"
		} >| "$(OWRT_DIR)/feeds.conf"
	elif [ -f "$(OWRT_DIR)/feeds.conf" ] \
			&& head -1 "$(OWRT_DIR)/feeds.conf" | grep -qF 'generated by openwrt-buildroot'; then
		echo " - removing stale generated feeds.conf"
		rm "$(OWRT_DIR)/feeds.conf"
	fi

	cd $(OWRT_DIR)
	MAKEFLAGS= ./scripts/feeds update -a
	MAKEFLAGS= ./scripts/feeds install -a

.PHONY: src.patch
src.patch: ## Src apply patches
	@cd $(OWRT_DIR)
	QUILT_PATCHES=$(SRC_QUILT_PATCHES) quilt push -va && rc=0 || rc=$$?
	[ $$rc -eq 0 ] || [ $$rc -eq 2 ] || exit $$rc

.PHONY: src.patch.undo
src.patch.undo: ## Src patches undo
	@cd $(OWRT_DIR)
	QUILT_PATCHES=$(SRC_QUILT_PATCHES) quilt pop -va

src.quilt.%:
	@cd $(OWRT_DIR)
	QUILT_PATCHES=$(SRC_QUILT_PATCHES) quilt $* $(ARGS)

.PHONY: src.build.config
src.build.config: ## Src build config
	@$(call Setup/Vars,$(SRC_GENERIC_CONFIG))
	@$(call Setup/Vars,$(SRC_TARGETS_DIR)/$(SRC_TARGET)/$(SRC_SUBTARGET)/config.mk)

	@$(CURL) -o config.buildinfo "$(SRC_CONFIG_URL)"

	@echo " - generic line delete"
	@for line in $(GENERIC_SED_LINE_DELETE); do
		echo "   - processing $${line}"
		grep -Fv "$${line}" config.buildinfo >| config.buildinfo.tmp || :
		mv config.buildinfo.tmp config.buildinfo
	done

	@echo " - $(SRC_TARGET)/$(SRC_SUBTARGET) line delete"
	@for line in $(CONFIG_SED_LINE_DELETE); do
		echo "   - processing $${line}"
		grep -Fv "$${line}" config.buildinfo >| config.buildinfo.tmp || :
		mv config.buildinfo.tmp config.buildinfo
	done

	@echo " - generic line add"
	@for line in $(GENERIC_LINE_ADD); do
		echo "   - processing $${line}"
		if grep -Fxq "$${line}" config.buildinfo; then
			echo " - line already present in config.buildinfo: $${line}"
			exit 1
		fi
		echo "$${line}" >> config.buildinfo
	done

	@echo " - $(SRC_TARGET)/$(SRC_SUBTARGET) line add"
	@for line in $(CONFIG_LINE_ADD); do
		echo "   - processing $${line}"
		if grep -Fxq "$${line}" config.buildinfo; then
			echo " - line already present in config.buildinfo: $${line}"
			exit 1
		fi
		echo "$${line}" >> config.buildinfo
	done

	echo "CONFIG_KERNEL_VERMAGIC=\"$(CONFIG_KERNEL_VERMAGIC)\"" >> config.buildinfo

	cp config.buildinfo $(OWRT_DIR)/.config
	MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) defconfig

.PHONY: src.download.config
src.download.config: ## Src download config info
	$(CURL) $(OWRT_DOWNLOAD_AREA_URL)/$(OWRT_DOWNLOAD_AREA_PATH)/targets/$(SRC_TARGET)/$(SRC_SUBTARGET)/config.buildinfo

.PHONY: src.download.version
src.download.version: ## Src download version info
	$(CURL) $(OWRT_DOWNLOAD_AREA_URL)/$(OWRT_DOWNLOAD_AREA_PATH)/targets/$(SRC_TARGET)/$(SRC_SUBTARGET)/version.buildinfo

.PHONY: src.download.vermagic
src.download.vermagic: ## Src download vermagic info
	$(CURL) $(OWRT_TARGETS_URL)/$(SRC_TARGET)/$(SRC_SUBTARGET)/profiles.json | jq -r '.linux_kernel.vermagic'

.PHONY: src.validate.vermagic
src.validate.vermagic: ## Src validate vermagic
	@$(call Setup/Vars,$(SRC_TARGETS_DIR)/$(SRC_TARGET)/$(SRC_SUBTARGET)/config.mk)

	cat $(OWRT_DIR)/build_dir/target-*/linux-*/linux-*/.vermagic

	VERMAGIC=$$(grep -m1 -Eo '[0-9a-f]{32}' \
		"$(SRC_BINARY_TARGETS_DIR)/openwrt-$(addsuffix -,$(MANIFEST_VERSION))$(SRC_TARGET)-$(SRC_SUBTARGET).manifest" || :)
	@if [ "$(VALIDATE_VERMAGIC)" == "1" ] && [ "$$VERMAGIC" != "$(CONFIG_KERNEL_VERMAGIC)" ]; then
		echo " - vermagic mismatch: $$VERMAGIC expected $(CONFIG_KERNEL_VERMAGIC)"
		exit 1
	fi

	echo " - vermagic ok: $$VERMAGIC"

.PHONY: src.fast.vermagic
src.fast.vermagic:
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) target/linux/{clean,compile} || :
	@find build_dir/ -name .vermagic -exec cat {} \;

.PHONY: src.fast.dtb
src.fast.dtb:
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) target/linux/dtb/{clean,compile}

.PHONY: src.download
src.download: ## Src download
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) download -j$$(nproc)

.PHONY: src.tools.install
src.tools.install: ## Src tools install
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) tools/install -j$$(nproc)

.PHONY: src.toolchain.install
src.toolchain.install: ## Src toolchain install
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) toolchain/install -j$$(nproc)

.PHONY: src.build
src.build: ## Src build
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) -j$$(nproc)

.PHONY: src.debug
src.debug: ## Re-run failed step single-threaded verbose (resumes at failure point)
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) V=sc

.PHONY: src.archive
src.archive: $(SRC_ARTIFACTS_DIR) ## Src archive
	@if [ ! -d $(SRC_BINARY_TARGETS_DIR) ]; then
		echo " - dir not exists: $(SRC_BINARY_TARGETS_DIR)"
		exit 1
	fi

	if [ -z "$$(find "$(SRC_BINARY_TARGETS_DIR)/" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
		echo " - empty dir: $(SRC_BINARY_TARGETS_DIR)"
		exit 1
	fi

	MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) json_overview_image_info checksum

	@echo " - copying: $(SRC_IMG_BUILDER_FILE)"
	cp -f $(SRC_BINARY_TARGETS_DIR)/$(SRC_IMG_BUILDER_FILE) $(SRC_ARTIFACTS_DIR)/$(SRC_IMG_BUILDER_FILE)

	@echo " - copying sdk: $(SDK_FILE_PATTERN)"
	cp -f $(SRC_BINARY_TARGETS_DIR)/$(SDK_FILE_PATTERN) $(SRC_ARTIFACTS_DIR)/

	@echo " - archiving: $(SRC_ARTIFACTS_ARCHIVE_FILE)"

	tar -C $(OWRT_DIR)/bin -cf - . | zstd $(ARCHIVE_ZSTD_OPTS) -f -o $(SRC_ARTIFACTS_DIR)/$(SRC_ARTIFACTS_ARCHIVE_FILE)

	# per-profile distributable zips: images + profiles.json + manifest under
	# a same-named top dir
	@echo " - zipping profile images"
	SH_PROFILES_JSON=$(SRC_BINARY_TARGETS_DIR)/profiles.json
	SH_MANIFEST=$(SRC_BINARY_TARGETS_DIR)/openwrt-$(addsuffix -,$(MANIFEST_VERSION))$(SRC_TARGET)-$(SRC_SUBTARGET).manifest
	SH_ZIP_TMP=$(SRC_ARTIFACTS_DIR)/zip-tmp
	for SH_PROFILE in $$(jq -r '.profiles | keys[]' "$${SH_PROFILES_JSON}"); do
		SH_ZIP_BASE=openwrt-$(OWRT_VERSION)-$(SRC_TARGET)-$(SRC_SUBTARGET)-$${SH_PROFILE}
		SH_STAGE=$${SH_ZIP_TMP}/$${SH_ZIP_BASE}
		rm -rf "$${SH_ZIP_TMP}"
		mkdir -p "$${SH_STAGE}"
		for SH_IMG in $$(jq -r --arg p "$${SH_PROFILE}" '.profiles[$$p].images[].name' "$${SH_PROFILES_JSON}"); do
			if [ -f "$(SRC_BINARY_TARGETS_DIR)/$${SH_IMG}" ]; then
				cp -f "$(SRC_BINARY_TARGETS_DIR)/$${SH_IMG}" "$${SH_STAGE}/"
			else
				echo "   ! missing image: $${SH_IMG}"
			fi
		done
		cp -f "$${SH_PROFILES_JSON}" "$${SH_MANIFEST}" "$${SH_STAGE}/"
		(cd "$${SH_ZIP_TMP}" && zip -rq "$${SH_ZIP_BASE}.zip" "$${SH_ZIP_BASE}")
		mv -f "$${SH_ZIP_TMP}/$${SH_ZIP_BASE}.zip" "$(SRC_ARTIFACTS_DIR)/$${SH_ZIP_BASE}.zip"
		echo "   - $${SH_ZIP_BASE}.zip"
	done
	rm -rf "$${SH_ZIP_TMP}"

_src.all.base: src.patch src.build.config src.download src.tools.install src.toolchain.install \
	src.build src.validate.vermagic src.archive

.PHONY: src.all
src.all: src.check.umask src.install.feeds _src.all.base ## Src all

.PHONY: src.all.nofeeds
src.all.nofeeds: src.check.umask _src.all.base  ## Src all wo feeds
