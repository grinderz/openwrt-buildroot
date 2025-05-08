MAKEFLAGS += --warn-undefined-variables

.ONESHELL:
.SHELLFLAGS := -o errtrace -o pipefail -o noclobber -o errexit -o nounset -c
SHELL := bash


OWRT_VERSION ?= 24.10.1
OWRT_DOWNLOAD_AREA_URL ?= https://downloads.openwrt.org
OWRT_TARGETS_URL := $(OWRT_DOWNLOAD_AREA_URL)/releases/$(OWRT_VERSION)/targets
ARTIFACTS_DIR := artifacts

SRC_OWRT_GIT ?= https://git.openwrt.org/openwrt/openwrt.git
SRC_TARGET ?= x86
SRC_SUBTARGET ?= 64

SRC_DIR := srcbuilder
SRC_TARGETS_DIR := $(SRC_DIR)/targets
SRC_CONFIG_URL := $(OWRT_TARGETS_URL)/$(SRC_TARGET)/$(SRC_SUBTARGET)/config.buildinfo
SRC_QUILT_PATCHES := ../$(SRC_DIR)/patches

SRC_ARTIFACTS_DIR := $(ARTIFACTS_DIR)/src
SRC_OWRT_DIR := openwrt
SRC_ARTIFACTS_ARCHIVE_FILE := openwrt-$(OWRT_VERSION)-$(SRC_TARGET)-$(SRC_SUBTARGET)-$$(date +%F).7z
SRC_BINARY_TARGETS_DIR := $(SRC_OWRT_DIR)/bin/targets/$(SRC_TARGET)/$(SRC_SUBTARGET)
SRC_IMG_BUILDER_FILE := openwrt-imagebuilder-$(OWRT_VERSION)-$(SRC_TARGET)-$(SRC_SUBTARGET).Linux-x86_64.tar.zst


IMG_BUILDER_IMAGE ?= quay.io/openwrt/imagebuilder

IMG_DIR := imagebuilder
IMG_ARTIFACTS_DIR := $(ARTIFACTS_DIR)/img
IMG_TMP_DIR := $(IMG_ARTIFACTS_DIR)/tmp
IMG_FILES_DIR_NAME := files
IMG_GENERIC_FILES_DIR := $(IMG_DIR)/$(IMG_FILES_DIR_NAME)

IMG_SRC_BUILDER_IMAGE ?= varch/openwrt-imgbuilder

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


##@ Image Builder Targets

define Img/Make
    @echo " - docker make image"
	docker run --rm -v "./$(IMG_TMP_DIR)/":/builder/bin -it $(CONFIG_DOCKER_IMAGE):$(CONFIG_TARGET)-$(CONFIG_SUBTARGET)-$(OWRT_VERSION) \
		make image \
			PROFILE=$(CONFIG_PROFILE) \
			PACKAGES="$(CONFIG_BASE_PKGS) $(CONFIG_CUSTOM_PKGS)" \
			FILES="bin/$(IMG_FILES_DIR_NAME)" \
			$(if $(CONFIG_ROOTFS_PARTSIZE),ROOTFS_PARTSIZE=$(CONFIG_ROOTFS_PARTSIZE))
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

	SH_ARCHIVE_NAME=openwrt-$(OWRT_VERSION)-$(CONFIG_TARGET)-$(CONFIG_SUBTARGET)-$(CONFIG_PROFILE)$(if $(CONFIG_DEVICE),-$(CONFIG_DEVICE))-$$(date +%F).7z
	@echo " - archiving: $${SH_ARCHIVE_NAME}"

	(
		cd $(IMG_TMP_DIR)
		7z a -mx=9 $${SH_ARCHIVE_NAME} .
	)

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
	docker buildx build -t $(CONFIG_DOCKER_IMAGE):$(CONFIG_TARGET)-$(CONFIG_SUBTARGET)-$(OWRT_VERSION) -f imgbuilder.Dockerfile \
		--build-arg SRC_ARTIFACTS_DIR=$(SRC_ARTIFACTS_DIR) \
		--build-arg SRC_IMG_BUILDER_FILE=openwrt-imagebuilder-$(OWRT_VERSION)-$(CONFIG_TARGET)-$(CONFIG_SUBTARGET).Linux-x86_64.tar.zst \
		.
endef

define Img/Info
	echo " - src target default pakages"
	grep DEFAULT_PACKAGES openwrt/target/linux/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)/target.mk || :

	SH_JQ_RULES='.default_packages,.profiles."$(CONFIG_PROFILE)".device_packages,.profiles."$(CONFIG_PROFILE)".images'
	SH_SRC_PROFILE_FILE=$(SRC_OWRT_DIR)/bin/targets/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)/profiles.json
	if [ -f "$${SH_SRC_PROFILE_FILE}" ]; then
		echo " - src profile: default-packages, device-packages, images"
		jq $${SH_JQ_RULES} "$${SH_SRC_PROFILE_FILE}"
	fi

	echo " - download area profile: default-packages, device-packages, images"
	curl -s $(OWRT_TARGETS_URL)/$(CONFIG_TARGET)/$(CONFIG_SUBTARGET)/profiles.json | jq $${SH_JQ_RULES}
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

_img.info:
	if [ -z "$(CONFIG_TARGET)" ] || [ -z "$(CONFIG_SUBTARGET)" ]; then 
		$(call Setup/Vars,$(IMG_DIR)/profiles/$(CONFIG_PROFILE)/config.mk)
	fi
	$(call Img/Info)

_img.profile: $(IMG_ARTIFACTS_DIR) img.recreate.tmp
	$(call Setup/Vars,$(IMG_DIR)/profiles/$(CONFIG_PROFILE)/config.mk)
	$(call Img/Files)
	$(call Img/Make)
	$(call Img/Archive)

_img.device: $(IMG_ARTIFACTS_DIR) img.recreate.tmp
	$(call Setup/Vars,$(IMG_DIR)/devices/$(CONFIG_DEVICE)/config.mk)
	$(call Img/Files)
	$(call Img/Make)
	$(call Img/Archive)

_img.src.build.profile:
	$(call Setup/Vars,$(IMG_DIR)/profiles/$(CONFIG_PROFILE)/config.mk)
	$(call Img/Builder/Docker/Build)

_img.src.build.device:
	$(call Setup/Vars,$(IMG_DIR)/devices/$(CONFIG_DEVICE)/config.mk)
	$(call Img/Builder/Docker/Build)

.PHONY: img.netgear_wnr3500l-v1-na
img.netgear_wnr3500l-v1-na: CONFIG_PROFILE := netgear_wnr3500l-v1-na
img.netgear_wnr3500l-v1-na: CONFIG_DOCKER_IMAGE := $(IMG_BUILDER_IMAGE)
img.netgear_wnr3500l-v1-na: _img.profile ## Build image netgear_wnr3500l-v1-na

.PHONY: img.src.netgear_wnr3500l-v1-na
img.src.netgear_wnr3500l-v1-na: CONFIG_PROFILE := netgear_wnr3500l-v1-na
img.src.netgear_wnr3500l-v1-na: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.src.netgear_wnr3500l-v1-na: _img.src.build.profile _img.profile ## Build image netgear_wnr3500l-v1-na from src imagebuilder

.PHONY: img.info.netgear_wnr3500l-v1-na
img.info.netgear_wnr3500l-v1-na: CONFIG_PROFILE := netgear_wnr3500l-v1-na
img.info.netgear_wnr3500l-v1-na: _img.info ## Show info from profile dnetgear_wnr3500l-v1-na

.PHONY: img.asus_rt-n56u-b1
img.asus_rt-n56u-b1: CONFIG_PROFILE := asus_rt-n56u-b1
img.asus_rt-n56u-b1: CONFIG_DOCKER_IMAGE := $(IMG_BUILDER_IMAGE)
img.asus_rt-n56u-b1: _img.profile ## Build image asus_rt-n56u-b1

.PHONY: img.src.asus_rt-n56u-b1
img.src.asus_rt-n56u-b1: CONFIG_PROFILE := asus_rt-n56u-b1
img.src.asus_rt-n56u-b1: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.src.asus_rt-n56u-b1: _img.src.build.profile _img.profile ## Build image asus_rt-n56u-b1 from src imagebuilder

.PHONY: img.info.asus_rt-n56u-b1
img.info.asus_rt-n56u-b1: CONFIG_PROFILE := asus_rt-n56u-b1
img.info.asus_rt-n56u-b1: _img.info ## Show info from profile asus_rt-n56u-b1

.PHONY: img.cudy_tr3000-v1
img.cudy_tr3000-v1: CONFIG_PROFILE := cudy_tr3000-v1
img.cudy_tr3000-v1: CONFIG_DOCKER_IMAGE := $(IMG_BUILDER_IMAGE)
img.cudy_tr3000-v1: _img.profile ## Build image cudy_tr3000-v1

.PHONY: img.src.cudy_tr3000-v1
img.src.cudy_tr3000-v1: CONFIG_PROFILE := cudy_tr3000-v1
img.src.cudy_tr3000-v1: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.src.cudy_tr3000-v1: _img.src.build.profile _img.profile ## Build image cudy_tr3000-v1 from src imagebuilder

.PHONY: img.info.cudy_tr3000-v1
img.info.cudy_tr3000-v1: CONFIG_PROFILE := cudy_tr3000-v1
img.info.cudy_tr3000-v1: _img.info ## Show info from profile cudy_tr3000-v1

.PHONY: img.glinet_gl-mt6000
img.glinet_gl-mt6000: CONFIG_PROFILE := glinet_gl-mt6000
img.glinet_gl-mt6000: CONFIG_DOCKER_IMAGE := $(IMG_BUILDER_IMAGE)
img.glinet_gl-mt6000: _img.profile  ## Build image glinet_gl-mt6000

.PHONY: img.src.glinet_gl-mt6000
img.src.glinet_gl-mt6000: CONFIG_PROFILE := glinet_gl-mt6000
img.src.glinet_gl-mt6000: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.src.glinet_gl-mt6000: _img.src.build.profile _img.profile  ## Build image glinet_gl-mt6000 from src imagebuilder

.PHONY: img.info.glinet_gl-mt6000
img.info.glinet_gl-mt6000: CONFIG_PROFILE := glinet_gl-mt6000
img.info.glinet_gl-mt6000: _img.info ## Show info from profile glinet_gl-mt6000

.PHONY: img.xiaomi_mi-router-ax3000t-ubootmod
img.xiaomi_mi-router-ax3000t-ubootmod: CONFIG_PROFILE := xiaomi_mi-router-ax3000t-ubootmod
img.xiaomi_mi-router-ax3000t-ubootmod: CONFIG_DOCKER_IMAGE := $(IMG_BUILDER_IMAGE)
img.xiaomi_mi-router-ax3000t-ubootmod: _img.profile ## Build image xiaomi_mi-router-ax3000t-ubootmod

.PHONY: img.src.xiaomi_mi-router-ax3000t-ubootmod
img.src.xiaomi_mi-router-ax3000t-ubootmod: CONFIG_PROFILE := xiaomi_mi-router-ax3000t-ubootmod
img.src.xiaomi_mi-router-ax3000t-ubootmod: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.src.xiaomi_mi-router-ax3000t-ubootmod: _img.src.build.profile _img.profile ## Build image xiaomi_mi-router-ax3000t-ubootmod from src imagebuilder

.PHONY: img.info.xiaomi_mi-router-ax3000t-ubootmod
img.info.xiaomi_mi-router-ax3000t-ubootmod: CONFIG_PROFILE := xiaomi_mi-router-ax3000t-ubootmod
img.info.xiaomi_mi-router-ax3000t-ubootmod: _img.info ## Show info from profile xiaomi_mi-router-ax3000t-ubootmod

.PHONY: img.rpi-3
img.rpi-3: CONFIG_PROFILE := rpi-3
img.rpi-3: CONFIG_DOCKER_IMAGE := $(IMG_BUILDER_IMAGE)
img.rpi-3: _img.profile ## Build image rpi-3

.PHONY: img.src.rpi-3
img.src.rpi-3: CONFIG_PROFILE := rpi-3
img.src.rpi-3: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.src.rpi-3: _img.src.build.profile _img.profile ## Build image rpi-3 from src imagebuilder

.PHONY: img.rpi-3-nut
img.rpi-3-nut: CONFIG_PROFILE := rpi-3
img.rpi-3-nut: CONFIG_DEVICE := rpi-3-nut
img.rpi-3-nut: CONFIG_DOCKER_IMAGE := $(IMG_BUILDER_IMAGE)
img.rpi-3-nut: _img.device ## Build image rpi-3-nut device

.PHONY: img.src.rpi-3-nut
img.src.rpi-3-nut: CONFIG_PROFILE := rpi-3
img.src.rpi-3-nut: CONFIG_DEVICE := rpi-3-nut
img.src.rpi-3-nut: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.src.rpi-3-nut: _img.src.build.device _img.device ## Build image rpi-3-nut device from src imagebuilder

.PHONY: img.info.rpi-3
img.info.rpi-3: CONFIG_PROFILE := rpi-3
img.info.rpi-3: _img.info ## Show info from profile rpi-3

.PHONY: img.generic-x86-64-lec-7233
img.generic-x86-64-lec-7233: CONFIG_PROFILE := generic
img.generic-x86-64-lec-7233: CONFIG_DEVICE := generic-x86-64-lec-7233
img.generic-x86-64-lec-7233: CONFIG_DOCKER_IMAGE := $(IMG_BUILDER_IMAGE)
img.generic-x86-64-lec-7233: _img.device ## Build image generic-x86-64-lec-7233 device

.PHONY: img.src.generic-x86-64-lec-7233
img.src.generic-x86-64-lec-7233: CONFIG_PROFILE := generic
img.src.generic-x86-64-lec-7233: CONFIG_DEVICE := generic-x86-64-lec-7233
img.src.generic-x86-64-lec-7233: CONFIG_DOCKER_IMAGE := $(IMG_SRC_BUILDER_IMAGE)
img.src.generic-x86-64-lec-7233: _img.src.build.device _img.device ## Build image generic-x86-64-lec-7233 device from src imagebuilder

.PHONY: img.info.generic-x86-64
img.info.generic-x86-64: CONFIG_PROFILE := generic
img.info.generic-x86-64: CONFIG_TARGET := x86
img.info.generic-x86-64: CONFIG_SUBTARGET := 64
img.info.generic-x86-64: _img.info ## Show info from profile generic-x86-64


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
	docker compose exec -it srcbuilder /bin/bash


##@ Source Builder Targets

$(SRC_ARTIFACTS_DIR):
	@mkdir -p $@

.PHONY: src.clean.artifacts
src.clean.artifacts: ## Clean src artifacts
	@rm -rf "$(SRC_ARTIFACTS_DIR)"

.PHONY: src.clean.owrt
src.clean.owrt: ## Delete openwrt dir
	@rm -rf "$(SRC_OWRT_DIR)"

.PHONY: src.clone
src.clone: ## Src clone openwrt
	git clone --depth 1 --branch v$(OWRT_VERSION) $(SRC_OWRT_GIT)

.PHONY: src.owrt.%
src.owrt.%: ## Src openwrt make command
	@MAKEFLAGS= $(MAKE) -C $(SRC_OWRT_DIR) $*

.PHONY: src.check.umask
src.check.umask: ## Src check umask https://github.com/openwrt/openwrt/issues/9545
		@umask=$$(umask)
		if [ $$umask -ne "0002" ] && [ $$umask -ne "0022" ]; then
			echo " - invalid umask: $$umask"
			exit 1
		fi

.PHONY: src.install.feeds
src.install.feeds: ## Src install feeds
	@cd $(SRC_OWRT_DIR)
	@MAKEFLAGS= ./scripts/feeds update -a
	@MAKEFLAGS= ./scripts/feeds install -a

.PHONY: src.patches
src.patches: ## Src apply patches
	@cd $(SRC_OWRT_DIR)
	@QUILT_PATCHES=$(SRC_QUILT_PATCHES) quilt push -a || [ "$$?" -eq "2" ] || :

.PHONY: src.patches.undo
src.patches.undo: ## Src patches undo
	@cd $(SRC_OWRT_DIR)
	@QUILT_PATCHES=$(SRC_QUILT_PATCHES) quilt pop -vaf

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

	mv config.buildinfo $(SRC_OWRT_DIR)/.config
	MAKEFLAGS= $(MAKE) -C $(SRC_OWRT_DIR) defconfig

.PHONY: src.validate.vermagic
src.validate.vermagic: ## Src validate vermagic
	@$(call Setup/Vars,$(SRC_TARGETS_DIR)/$(SRC_TARGET)/$(SRC_SUBTARGET)/config.mk)

	VERMAGIC=$(shell grep -Eo '([0-9a-f]{32})' $(SRC_BINARY_TARGETS_DIR)/openwrt-$(OWRT_VERSION)-$(SRC_TARGET)-$(SRC_SUBTARGET).manifest)
	if [ "$$VERMAGIC" != "$(CONFIG_KERNEL_VERMAGIC)" ]; then
		echo " - vermagic mismatch: $$VERMAGIC expected $(CONFIG_KERNEL_VERMAGIC)"
		exit 1
	fi

	echo " - vermagic ok: $$VERMAGIC"

.PHONY: src.fast.vermagic
src.fast.vermagic:
	@MAKEFLAGS= $(MAKE) -C $(SRC_OWRT_DIR) target/linux/{clean,compile} || :
	@find build_dir/ -name .vermagic -exec cat {} \;

.PHONY: src.download
src.download: ## Src download
	@MAKEFLAGS= $(MAKE) -C $(SRC_OWRT_DIR) download -j$$(nproc) || \
		exit 1

.PHONY: src.tools.install
src.tools.install: ## Src tools install
	@MAKEFLAGS= $(MAKE) -C $(SRC_OWRT_DIR) tools/install -j$$(nproc) || \
		MAKEFLAGS= $(MAKE) -C $(SRC_OWRT_DIR) tools/install V=sc

.PHONY: src.toolchain.install
src.toolchain.install: ## Src toolchain install
	@MAKEFLAGS= $(MAKE) -C $(SRC_OWRT_DIR) toolchain/install -j$$(nproc) || \
		MAKEFLAGS= $(MAKE) -C $(SRC_OWRT_DIR) toolchain/install V=sc

.PHONY: src.build
src.build: ## Src build
	@MAKEFLAGS= $(MAKE) -C $(SRC_OWRT_DIR) -j$$(nproc) || \
		MAKEFLAGS= $(MAKE) -C $(SRC_OWRT_DIR) V=sc

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

	MAKEFLAGS= $(MAKE) -C $(SRC_OWRT_DIR) json_overview_image_info checksum

	@echo " - copying: $(SRC_IMG_BUILDER_FILE)"
	cp -f $(SRC_BINARY_TARGETS_DIR)/$(SRC_IMG_BUILDER_FILE) $(SRC_ARTIFACTS_DIR)/$(SRC_IMG_BUILDER_FILE)

	@echo " - archiving: $(SRC_ARTIFACTS_ARCHIVE_FILE)"
	(
		cd $(SRC_OWRT_DIR)/bin
		7z a -mx=9 $(SRC_ARTIFACTS_ARCHIVE_FILE) .
	)

	mv -f $(SRC_OWRT_DIR)/bin/$(SRC_ARTIFACTS_ARCHIVE_FILE) $(SRC_ARTIFACTS_DIR)/

_src.all.base: src.patches src.build.config src.download src.tools.install src.toolchain.install src.build src.validate.vermagic src.archive

.PHONY: src.all
src.all: src.check.umask src.install.feeds _src.all.base ## Src all

.PHONY: src.all.nofeeds
src.all.nofeeds: src.check.umask _src.all.base  ## Src all wo feeds
