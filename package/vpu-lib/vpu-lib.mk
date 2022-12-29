################################################################################
#
# vpu lib
#
################################################################################

VPU_LIB_VERSION = a3109a35b230a57d860bce66d4369a74c56f12a8
VPU_LIB_SITE = https://gitee.com/phytium_embedded/vpu-lib.git
VPU_LIB_INSTALL_IMAGES = YES
VPU_LIB_SITE_METHOD = git
VPU_LIB_DEPENDENCIES = linux

define VPU_LIB_INSTALL_TARGET_CMDS
        $(TARGET_MAKE_ENV) $(MAKE) -C $(@D) install DESTDIR=$(TARGET_DIR) CPU_MODEL=$(BR2_PACKAGE_VPU_LIB_CPU_MODEL)
endef

$(eval $(generic-package))
