################################################################################
#
# XORG-firmware
#
################################################################################

XORG_ROGUE_UMLIBS_VERSION = 213244f08503ce002cd816abbdc3e353f34e9a1b
XORG_ROGUE_UMLIBS_CUSTOM_REPO_URL = https://gitee.com/phytium_embedded/phytium-rogue-umlibs.git
XORG_ROGUE_UMLIBS_SITE = $(call qstrip,$(XORG_ROGUE_UMLIBS_CUSTOM_REPO_URL))
XORG_ROGUE_UMLIBS_INSTALL_IMAGES = YES
XORG_ROGUE_UMLIBS_SITE_METHOD = git
XORG_ROGUE_UMLIBS_BUILD_CMDS = YES
XORG_ROGUE_UMLIBS_INSTALL_TARGET_CMDS = YES

define XORG_ROGUE_UMLIBS_BUILD_CMDS
        $(TARGET_MAKE_ENV) $(MAKE) -C $(@D) all
endef

define XORG_ROGUE_UMLIBS_INSTALL_TARGET_CMDS
        $(TARGET_MAKE_ENV) $(MAKE) -C $(@D) install DESTDIR=$(TARGET_DIR) WINDOW_SYSTEM=xorg
endef

$(eval $(generic-package))
