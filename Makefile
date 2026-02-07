MAKEFLAGS += --warn-undefined-variables

.ONESHELL:
.SHELLFLAGS := -o errtrace -o pipefail -o noclobber -o errexit -o nounset -c
SHELL := bash

UID := $(shell id -u)
export UID
GID := $(shell id -g)
export GID


# release tag 24.10.5
#OWRT_VERSION_MAJOR_MINOR := 24.10
#OWRT_VERSION_PATCH := 5
#OWRT_BRANCH :=
#OWRT_DIR := openwrt
#SRC_OWRT_GIT := https://git.openwrt.org/openwrt/openwrt.git

# release branch 25.12
OWRT_VERSION_MAJOR_MINOR := 25.12
OWRT_VERSION_PATCH :=
OWRT_BRANCH :=
OWRT_DIR := openwrt-25.12
SRC_OWRT_GIT := https://git.openwrt.org/openwrt/openwrt.git

# master
#OWRT_VERSION_MAJOR_MINOR := master
#OWRT_VERSION_PATCH :=
#OWRT_BRANCH :=
#OWRT_DIR := openwrt-master
#SRC_OWRT_GIT := https://github.com/openwrt/openwrt.git

# master custom branch
#OWRT_VERSION_MAJOR_MINOR := master
#OWRT_VERSION_PATCH :=
#OWRT_BRANCH := cudy-ap3000-motorcomm
#OWRT_DIR := openwrt-cudy-ap3000-motorcomm
#SRC_OWRT_GIT := https://github.com/grinderz/openwrt.git

# orangepi-zero3
#SRC_TARGET := sunxi
#SRC_SUBTARGET := cortexa53

SRC_TARGET := mediatek
SRC_SUBTARGET := filogic

OWRT_GET_VER_SCRIPT := scripts/getver.sh
OWRT_GIT_VERSION_FILE := version
OWRT_GIT_VERSION := $(shell cat $(OWRT_DIR)/$(OWRT_GIT_VERSION_FILE) 2>/dev/null || echo unknown)

ifeq ($(OWRT_VERSION_MAJOR_MINOR), master)
	OWRT_DOWNLOAD_AREA_PATH := snapshots
	MANIFEST_VERSION :=
	IMG_BUILDER_FILE_VERSION :=
	CONFIG_DIR_VERSION := $(OWRT_VERSION_MAJOR_MINOR)
	VALIDATE_VERMAGIC := 0

	ifeq ($(OWRT_BRANCH),)
		GIT_REF := $(OWRT_VERSION_MAJOR_MINOR)
		IMG_BUILDER_IMAGE_TAG := $(OWRT_VERSION_MAJOR_MINOR)
		OWRT_VERSION := $(OWRT_VERSION_MAJOR_MINOR)-$(OWRT_GIT_VERSION)
	else
		GIT_REF := $(OWRT_BRANCH)
		IMG_BUILDER_IMAGE_TAG := $(OWRT_BRANCH)
		OWRT_VERSION := $(OWRT_BRANCH)-$(OWRT_GIT_VERSION)
	endif
else
	ifeq ($(OWRT_VERSION_PATCH),)
		OWRT_DOWNLOAD_AREA_PATH := releases/$(OWRT_VERSION_MAJOR_MINOR)-SNAPSHOT
		GIT_REF := openwrt-$(OWRT_VERSION_MAJOR_MINOR)
		MANIFEST_VERSION := $(OWRT_VERSION_MAJOR_MINOR)-snapshot-$(OWRT_GIT_VERSION)
		IMG_BUILDER_IMAGE_TAG := $(GIT_REF)
		IMG_BUILDER_FILE_VERSION := $(OWRT_VERSION_MAJOR_MINOR)-SNAPSHOT
		OWRT_VERSION := $(OWRT_VERSION_MAJOR_MINOR)-$(OWRT_GIT_VERSION)
		CONFIG_DIR_VERSION := $(OWRT_VERSION_MAJOR_MINOR)
		VALIDATE_VERMAGIC := 0
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

SRC_DIR := srcbuilder/$(CONFIG_DIR_VERSION)
SRC_TARGETS_DIR := $(SRC_DIR)/targets
SRC_CONFIG_URL := $(OWRT_TARGETS_URL)/$(SRC_TARGET)/$(SRC_SUBTARGET)/config.buildinfo
SRC_QUILT_PATCHES := ../$(SRC_DIR)/patches

SRC_ARTIFACTS_DIR := $(ARTIFACTS_DIR)/src/$(CONFIG_DIR_VERSION)
SRC_ARTIFACTS_ARCHIVE_FILE := openwrt-$(OWRT_VERSION)-$(SRC_TARGET)-$(SRC_SUBTARGET)-$$(date +%F).7z
SRC_BINARY_TARGETS_DIR := $(OWRT_DIR)/bin/targets/$(SRC_TARGET)/$(SRC_SUBTARGET)
SRC_IMG_BUILDER_FILE := openwrt-imagebuilder-$(addsuffix -,$(IMG_BUILDER_FILE_VERSION))$(SRC_TARGET)-$(SRC_SUBTARGET).Linux-x86_64.tar.zst

IMG_BUILDER_IMAGE := quay.io/openwrt/imagebuilder

IMG_DIR := imagebuilder/$(CONFIG_DIR_VERSION)
IMG_ARTIFACTS_DIR := $(ARTIFACTS_DIR)/img/$(CONFIG_DIR_VERSION)
IMG_TMP_DIR := $(IMG_ARTIFACTS_DIR)/tmp/$(CONFIG_DIR_VERSION)
IMG_FILES_DIR_NAME := files
IMG_GENERIC_FILES_DIR := $(IMG_DIR)/$(IMG_FILES_DIR_NAME)

IMG_SRC_BUILDER_IMAGE ?= varch/openwrt-imagebuilder

ARGS ?=


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

DEFAULT_GOAL := help
.PHONY: help
help: ## Display this help screen
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9\-\\.%]+:.*?##/ { printf "  \033[36m%-29s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

define Setup/Vars
	@[ -f "${1}" ] || exit 1
	@echo " - setup vars $(1)"
	$(eval include $(1))
endef


##@ Info Targets


.PHONE: info
info:
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
	docker run --rm --user root -v "./$(IMG_TMP_DIR)/":/builder/bin -i $(CONFIG_DOCKER_IMAGE):$(CONFIG_TARGET)-$(CONFIG_SUBTARGET)-$(IMG_BUILDER_IMAGE_TAG) /bin/bash << EOT
	set -o errtrace -o pipefail -o noclobber -o errexit -o nounset
	cleanup() {
  		chown -R $(UID):$(GID) /builder/bin
	}

	trap cleanup EXIT

	make image \
		PROFILE=$(CONFIG_PROFILE) \
		PACKAGES="$(CONFIG_BASE_PKGS) $(CONFIG_CUSTOM_PKGS)" \
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

	if [ -z $$(find "$${SH_IMG_TARGETS_DIR}/" -mindepth 1 -maxdepth 1 -print -quit) ]; then
		echo " - empty dir: $${SH_IMG_TARGETS_DIR}"
		exit 1
	fi

	SH_ARCHIVE_NAME=openwrt-$(OWRT_VERSION)-$(CONFIG_TARGET)-$(CONFIG_SUBTARGET)-$(CONFIG_PROFILE)$(if $(CONFIG_DEVICE),-$(CONFIG_DEVICE))-$(CONFIG_BUILDER_TYPE)-$$(date +%F).7z
	@echo " - archiving: $${SH_ARCHIVE_NAME}"

	pushd $(IMG_TMP_DIR)
	7z a -mx=9 $${SH_ARCHIVE_NAME} .
	popd

	mv -f $(IMG_TMP_DIR)/$${SH_ARCHIVE_NAME} $(IMG_ARTIFACTS_DIR)/
endef

define Img/Files/Copy
	@[ -d "${1}" ] || exit 1
	if [ -d "${1}" ] && [ -n $$(find "${1}/" -mindepth 1 -maxdepth 1 -print) ]; then
		echo " - setup files: ${1}"
		mkdir -p "$(IMG_TMP_DIR)/$(IMG_FILES_DIR_NAME)"
		cp -rf ${1}/* $(IMG_TMP_DIR)/$(IMG_FILES_DIR_NAME)/
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

define Img/Builder/Docker/Build
    @echo " - imagebuilder docker build"
	docker buildx build -t $(CONFIG_DOCKER_IMAGE):$(CONFIG_TARGET)-$(CONFIG_SUBTARGET)-$(IMG_BUILDER_IMAGE_TAG) -f imgbuilder.Dockerfile \
		--build-arg SRC_ARTIFACTS_DIR=$(SRC_ARTIFACTS_DIR) \
		--build-arg SRC_IMG_BUILDER_FILE=openwrt-imagebuilder-$(addsuffix -,$(IMG_BUILDER_FILE_VERSION))$(CONFIG_TARGET)-$(CONFIG_SUBTARGET).Linux-x86_64.tar.zst \
		.
endef

define Img/Info
	echo " - src target default pakages"
	grep -s DEFAULT_PACKAGES $(OWRT_DIR)/target/linux/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)/target.mk || :

	SH_JQ_RULES='.linux_kernel.vermagic,.default_packages,.profiles."$(CONFIG_PROFILE)".device_packages,.profiles."$(CONFIG_PROFILE)".images'
	SH_SRC_PROFILE_FILE=$(OWRT_DIR)/bin/targets/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)/profiles.json
	if [ -f "$${SH_SRC_PROFILE_FILE}" ]; then
		echo " - src profile: vermagic, default-packages, device-packages, images"
		jq $${SH_JQ_RULES} "$${SH_SRC_PROFILE_FILE}"
	fi

	echo " - download area profile: vermagic, default-packages, device-packages, images"
	curl -s $(OWRT_TARGETS_URL)/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)/profiles.json | jq $${SH_JQ_RULES}
endef

define Img/Download/Pkgs
	echo " - download area profile: default-packages, device-packages"
	curl -s $(OWRT_DOWNLOAD_AREA_URL)/$(OWRT_DOWNLOAD_AREA_PATH)/targets/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)/profiles.json | jq -r '.default_packages + .profiles."$(CONFIG_PROFILE)".device_packages | join(" ")'
endef

$(IMG_ARTIFACTS_DIR):
	@mkdir -p $@

.PHONY: img.clean.tmp
img.clean.tmp: ## Clean tmp dir
	@rm -rf $(IMG_TMP_DIR)

.PHONY: img.recreate.tmp
img.recreate.tmp: img.clean.tmp ## Recreate tmp dir
	@mkdir -p $(IMG_TMP_DIR)

.PHONY: img.clean.artifacts
img.clean.artifacts: ## Clean image artifacts
	@rm -rf "$(IMG_ARTIFACTS_DIR)"

_img.info.%:
	$(call Setup/Vars,$(IMG_DIR)/profiles/$*/config.mk)

	$(call Img/Info)

_img.profile.%: $(IMG_ARTIFACTS_DIR) img.recreate.tmp
	$(call Setup/Vars,$(IMG_DIR)/profiles/$*/config.mk)
	$(call Img/Files)
	$(call Img/Make)
	$(call Img/Archive)

_img.device.%: $(IMG_ARTIFACTS_DIR) img.recreate.tmp
	$(call Setup/Vars,$(IMG_DIR)/devices/$*/config.mk)
	$(call Img/Files)
	$(call Img/Make)
	$(call Img/Archive)

_img.src.build.profile.%:
	$(call Setup/Vars,$(IMG_DIR)/profiles/$*/config.mk)
	$(call Img/Builder/Docker/Build)

_img.src.build.device.%:
	$(call Setup/Vars,$(IMG_DIR)/devices/$*/config.mk)
	$(call Img/Builder/Docker/Build)

.PHONY: img.download.pkgs.profile.%
img.download.pkgs.profile.%:
	$(call Setup/Vars,$(IMG_DIR)/profiles/$*/config.mk)
	$(call Img/Download/Pkgs)

.PHONY: img.download.pkgs.device.%
img.download.pkgs.device.%:
	$(call Setup/Vars,$(IMG_DIR)/devices/$*/config.mk)
	$(call Img/Download/Pkgs)

.PHONY: img.profile.%
img.profile.%: CONFIG_DOCKER_IMAGE := $(IMG_BUILDER_IMAGE)
img.profile.%: CONFIG_BUILDER_TYPE := b
img.profile.%: _img.profile.% ## Build image by profile
	@echo

.PHONY: img.src.profile.%
img.src.profile.%: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.src.profile.%: CONFIG_BUILDER_TYPE := s
img.src.profile.%: _img.src.build.profile.% _img.profile.% ## Build image by profile from src image builder
	@echo

.PHONY: img.info.profile.%
img.info.profile.%: _img.info.% ## Show info from profile
	@echo

.PHONY: img.device.%
img.device.%: CONFIG_DOCKER_IMAGE := $(IMG_BUILDER_IMAGE)
img.device.%: CONFIG_BUILDER_TYPE := b
img.device.%: _img.device.% ## Build image by device
	@echo

.PHONY: img.src.device.%
img.src.device.%: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.src.device.%: CONFIG_BUILDER_TYPE := s
img.src.device.%: _img.src.build.device.% _img.device.% ## Build image by device from src image builder
	@echo


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


define Src/Version
    @echo " - src version update"
	@if [ ! -e "$(OWRT_DIR)/$(OWRT_GIT_VERSION_FILE)" ]; then
		pushd "$(OWRT_DIR)"
		../"$(OWRT_GET_VER_SCRIPT)" > "$(OWRT_GIT_VERSION_FILE)"
		popd

		echo " - version file generated: $(OWRT_DIR)/$(OWRT_GIT_VERSION_FILE) - $$(cat $(OWRT_DIR)/$(OWRT_GIT_VERSION_FILE))"
	fi
endef

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
	git clone --depth 1 --branch $(GIT_REF) $(SRC_OWRT_GIT) $(OWRT_DIR)

	$(call Src/Version)

.PHONY: src.pull
src.pull: ## Src pull
	pushd $(OWRT_DIR)
	git pull
	popd

	rm "$(OWRT_DIR)/$(OWRT_GIT_VERSION_FILE)"

	$(call Src/Version)

.PHONY: src.owrt.%
src.owrt.%: ## Src openwrt make custom command (target/linux/clean)
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) $*

.PHONY: src.check.umask
src.check.umask: ## Src check umask https://github.com/openwrt/openwrt/issues/9545
	@umask=$$(umask)
	if [ $$umask -ne "0002" ] && [ $$umask -ne "0022" ]; then
		echo " - invalid umask: $$umask"
		exit 1
	fi

.PHONY: src.install.feeds
src.install.feeds: ## Src install feeds
	@cd $(OWRT_DIR)
	@MAKEFLAGS= ./scripts/feeds update -a
	@MAKEFLAGS= ./scripts/feeds install -a

.PHONY: src.patch
src.patch: ## Src apply patches
	@cd $(OWRT_DIR)
	QUILT_PATCHES=$(SRC_QUILT_PATCHES) quilt push -va || [ "$$?" -eq "2" ] || :

.PHONY: src.patch.undo
src.patch.undo: ## Src patches undo
	@cd $(OWRT_DIR)
	QUILT_PATCHES=$(SRC_QUILT_PATCHES) quilt pop -va

.PHONY: src.quilt.%
src.quilt.%:
	@cd $(OWRT_DIR)
	QUILT_PATCHES=$(SRC_QUILT_PATCHES) quilt $* $(ARGS)

.PHONY: src.build.config
src.build.config: ## Src build config
	@$(call Setup/Vars,$(SRC_TARGETS_DIR)/generic/config.mk)
	@$(call Setup/Vars,$(SRC_TARGETS_DIR)/$(SRC_TARGET)/$(SRC_SUBTARGET)/config.mk)

	@wget "$(SRC_CONFIG_URL)" -O config.buildinfo

	@echo " - generic sed line delete"
	@for line in $(GENERIC_SED_LINE_DELETE); do
		echo "   - processing $${line}"
		grep -Fxq "$${line}" config.buildinfo
		sed -i "/$${line}/d" config.buildinfo
	done

	@echo " - $(SRC_TARGET)/$(SRC_SUBTARGET) sed line delete"
	@for line in $(CONFIG_SED_LINE_DELETE); do
		echo "   - processing $${line}"
		grep -Fq "$${line}" config.buildinfo
		sed -i "/$${line}/d" config.buildinfo
	done

	@echo " - generic line add"
	@for line in $(GENERIC_LINE_ADD); do
		echo "   - processing $${line}"
		grep -Fxq "$${line}" config.buildinfo && exit 1
		echo "$${line}" >> config.buildinfo
	done

	@echo " - $(SRC_TARGET)/$(SRC_SUBTARGET) line add"
	@for line in $(CONFIG_LINE_ADD); do
		echo "   - processing $${line}"
		grep -Fxq "$${line}" config.buildinfo && exit 1
		echo "$${line}" >> config.buildinfo
	done

	echo "CONFIG_KERNEL_VERMAGIC=\"$(CONFIG_KERNEL_VERMAGIC)\"" >> config.buildinfo

	cp config.buildinfo $(OWRT_DIR)/.config
	MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) defconfig

.PHONY: src.download.vermagic
src.download.vermagic: ## Src download vermagic info
	curl -s $(OWRT_DOWNLOAD_AREA_URL)/$(OWRT_DOWNLOAD_AREA_PATH)/targets/$(SRC_TARGET)/$(SRC_SUBTARGET)/profiles.json | jq -r '.linux_kernel.vermagic'

.PHONY: src.validate.vermagic
src.validate.vermagic: ## Src validate vermagic
	@$(call Setup/Vars,$(SRC_TARGETS_DIR)/$(SRC_TARGET)/$(SRC_SUBTARGET)/config.mk)

	VERMAGIC=$(shell grep -Eo '([0-9a-f]{32})' $(SRC_BINARY_TARGETS_DIR)/openwrt-$(addsuffix -,$(MANIFEST_VERSION))$(SRC_TARGET)-$(SRC_SUBTARGET).manifest)
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
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) download -j$$(nproc) || \
		MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) download V=sc

.PHONY: src.tools.install
src.tools.install: ## Src tools install
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) tools/install -j$$(nproc) || \
		MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) tools/install V=sc

.PHONY: src.toolchain.install
src.toolchain.install: ## Src toolchain install
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) toolchain/install -j$$(nproc) || \
		MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) toolchain/install V=sc

.PHONY: src.build
src.build: ## Src build
	@MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) -j$$(nproc) || \
		MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) V=sc

.PHONY: src.archive
src.archive: $(SRC_ARTIFACTS_DIR) ## Src archive
	@if [ ! -d $(SRC_BINARY_TARGETS_DIR) ]; then
		echo " - dir not exists: $(SRC_BINARY_TARGETS_DIR)"
		exit 1
	fi

	if [ -z $$(find "$(SRC_BINARY_TARGETS_DIR)/" -mindepth 1 -maxdepth 1 -print -quit) ]; then
		echo " - empty dir: $(SRC_BINARY_TARGETS_DIR)"
		exit 1
	fi

	MAKEFLAGS= $(MAKE) -C $(OWRT_DIR) json_overview_image_info checksum

	@echo " - copying: $(SRC_IMG_BUILDER_FILE)"
	cp -f $(SRC_BINARY_TARGETS_DIR)/$(SRC_IMG_BUILDER_FILE) $(SRC_ARTIFACTS_DIR)/$(SRC_IMG_BUILDER_FILE)

	@echo " - archiving: $(SRC_ARTIFACTS_ARCHIVE_FILE)"

	pushd $(OWRT_DIR)/bin
	7z a -mx=9 $(SRC_ARTIFACTS_ARCHIVE_FILE) .
	popd

	mv -f $(OWRT_DIR)/bin/$(SRC_ARTIFACTS_ARCHIVE_FILE) $(SRC_ARTIFACTS_DIR)/

_src.all.base: src.patch src.build.config src.download src.tools.install src.toolchain.install src.build src.validate.vermagic src.archive

.PHONY: src.all
src.all: src.check.umask src.install.feeds _src.all.base ## Src all

.PHONY: src.all.nofeeds
src.all.nofeeds: src.check.umask _src.all.base  ## Src all wo feeds

# validae regdb
