# master custom branch: cudy m3000 reset bugfix
OWRT_VERSION_MAJOR_MINOR := master
OWRT_VERSION_PATCH :=
OWRT_BRANCH := bugfix/cudy-m3000-just-reset
OWRT_DIR := openwrt-cudy-m3000-just-reset
SRC_OWRT_GIT := https://github.com/JakubVanek/openwrt.git

# cudy m3000 is filogic; override from CLI still wins
SRC_TARGET ?= mediatek
SRC_SUBTARGET ?= filogic
