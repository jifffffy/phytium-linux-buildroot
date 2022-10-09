################################################################################
#
# rootfs-chown
#
################################################################################

ROOTFS_CHOWN_VERSION = 0.1
ROOTFS_CHOWN_SITE = package/rootfs-chown/src
ROOTFS_CHOWN_SITE_METHOD = local
ROOTFS_CHOWN_INSTALL_TARGET_CMDS = YES

define ROOTFS_CHOWN_INSTALL_INIT_SYSV
	$(INSTALL) -m 755 -D $(@D)/S60rootfs-chown $(TARGET_DIR)/etc/init.d/
endef

define ROOTFS_CHOWN_INSTALL_TARGET_CMDS
	$(INSTALL) -m 755 -D $(@D)/S60rootfs-chown $(TARGET_DIR)/etc/init.d/
	$(INSTALL) -m 644 -D $(@D)/systemd-rootfs-chown.service $(TARGET_DIR)/lib/systemd/system/
endef

$(eval $(generic-package))
