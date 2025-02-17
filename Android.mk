# Copyright (C) 2017 MediaTek Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See http://www.gnu.org/licenses/gpl-2.0.html for more details.

LOCAL_PATH := $(call my-dir)

ifeq ($(notdir $(LOCAL_PATH)),$(strip $(LINUX_KERNEL_VERSION)))
ifneq ($(strip $(TARGET_NO_KERNEL)),true)
include $(LOCAL_PATH)/kenv.mk

#ifdef OPLUS_ARCH_INJECT
my_feature_file := $(LOCAL_PATH)/oplus_native_features.sh

$(shell echo "#!/bin/bash" > $(my_feature_file))
$(shell echo 'export OPLUS_NATIVE_FEATURE_SET="$(strip $(SOONG_CONFIG_oplusNativeFeaturePlugin))"' >> $(my_feature_file))
$(foreach key,$(SOONG_CONFIG_oplusNativeFeaturePlugin), \
  $(shell echo 'export $(key)=$(SOONG_CONFIG_oplusNativeFeaturePlugin_$(key))' >> $(my_feature_file))\
)
#endif /* OPLUS_ARCH_INJECT */
ifeq ($(wildcard $(TARGET_PREBUILT_KERNEL)),)
KERNEL_MAKE_DEPENDENCIES := $(shell find $(KERNEL_DIR) -name .git -prune -o -type f | sort)
KERNEL_MAKE_DEPENDENCIES := $(filter-out %/.git %/.gitignore %/.gitattributes,$(KERNEL_MAKE_DEPENDENCIES))

$(TARGET_KERNEL_CONFIG): PRIVATE_DIR := $(KERNEL_DIR)
$(TARGET_KERNEL_CONFIG): $(KERNEL_CONFIG_FILE) $(LOCAL_PATH)/Android.mk
$(TARGET_KERNEL_CONFIG): $(KERNEL_MAKE_DEPENDENCIES)
	#ifdef OPLUS_FEATURE_FORCE_SELINUX
	OBSOLETE_KEEP_ADB_SECURE=$(OBSOLETE_KEEP_ADB_SECURE) \
	TARGET_MEMLEAK_DETECT_TEST=$(TARGET_MEMLEAK_DETECT_TEST) \
	$(KERNEL_DIR)/tools/changeConfig.sh $(KERNEL_CONFIG_FILE)
	#endif OPLUS_FEATURE_FORCE_SELINUX
	$(hide) mkdir -p $(dir $@)
#ifdef OPLUS_ARCH_INJECT
	source kernel-4.14/oplus_native_features.sh ; \
	$(PREBUILT_MAKE_PREFIX)$(MAKE) -C $(PRIVATE_DIR) $(KERNEL_MAKE_OPTION) $(KERNEL_DEFCONFIG)
#endif /* OPLUS_ARCH_INJECT */
$(BUILT_DTB_OVERLAY_TARGET): $(KERNEL_ZIMAGE_OUT)

.KATI_RESTAT: $(KERNEL_ZIMAGE_OUT)
$(KERNEL_ZIMAGE_OUT): PRIVATE_DIR := $(KERNEL_DIR)
$(KERNEL_ZIMAGE_OUT): $(TARGET_KERNEL_CONFIG) $(KERNEL_MAKE_DEPENDENCIES)
	$(hide) mkdir -p $(dir $@)
#ifdef OPLUS_ARCH_INJECT
	source kernel-4.14/oplus_native_features.sh ; \
	$(PREBUILT_MAKE_PREFIX)$(MAKE) -C $(PRIVATE_DIR) $(KERNEL_MAKE_OPTION)
#endif /* OPLUS_ARCH_INJECT */
	$(hide) $(call fixup-kernel-cmd-file,$(KERNEL_OUT)/arch/$(KERNEL_TARGET_ARCH)/boot/compressed/.piggy.xzkern.cmd)
	# check the kernel image size
	python device/mediatek/build/build/tools/check_kernel_size.py $(KERNEL_OUT) $(KERNEL_DIR) $(PROJECT_DTB_NAMES)

ifeq ($(strip $(MTK_HEADER_SUPPORT)), yes)
$(BUILT_KERNEL_TARGET): $(KERNEL_ZIMAGE_OUT) $(TARGET_KERNEL_CONFIG) $(LOCAL_PATH)/Android.mk | $(HOST_OUT_EXECUTABLES)/mkimage$(HOST_EXECUTABLE_SUFFIX)
	$(hide) $(HOST_OUT_EXECUTABLES)/mkimage$(HOST_EXECUTABLE_SUFFIX) $< KERNEL 0xffffffff > $@
else
$(BUILT_KERNEL_TARGET): $(KERNEL_ZIMAGE_OUT) $(TARGET_KERNEL_CONFIG) $(LOCAL_PATH)/Android.mk | $(ACP)
	$(copy-file-to-target)
endif

$(TARGET_PREBUILT_KERNEL): $(BUILT_KERNEL_TARGET) $(LOCAL_PATH)/Android.mk | $(ACP)
	$(copy-file-to-new-target)

endif#TARGET_PREBUILT_KERNEL is empty

$(INSTALLED_KERNEL_TARGET): $(BUILT_KERNEL_TARGET) $(LOCAL_PATH)/Android.mk | $(ACP)
	$(copy-file-to-target)

.PHONY: kernel save-kernel kernel-savedefconfig kernel-menuconfig menuconfig-kernel savedefconfig-kernel clean-kernel
kernel: $(INSTALLED_KERNEL_TARGET)
save-kernel: $(TARGET_PREBUILT_KERNEL)

kernel-savedefconfig: $(TARGET_KERNEL_CONFIG)
	cp $(TARGET_KERNEL_CONFIG) $(KERNEL_CONFIG_FILE)

kernel-menuconfig:
	$(hide) mkdir -p $(KERNEL_OUT)
#ifdef OPLUS_ARCH_INJECT
	source kernel-4.14/oplus_native_features.sh ; \
	$(MAKE) -C $(KERNEL_DIR) $(KERNEL_MAKE_OPTION) menuconfig
#endif /* OPLUS_ARCH_INJECT */

menuconfig-kernel savedefconfig-kernel:
	$(hide) mkdir -p $(KERNEL_OUT)
#ifdef OPLUS_ARCH_INJECT
	source kernel-4.14/oplus_native_features.sh ; \
	$(MAKE) -C $(KERNEL_DIR) $(KERNEL_MAKE_OPTION) $(patsubst %config-kernel,%config,$@)
#endif /* OPLUS_ARCH_INJECT */

clean-kernel:
	$(hide) rm -rf $(KERNEL_OUT) $(KERNEL_MODULES_OUT) $(INSTALLED_KERNEL_TARGET)
	$(hide) rm -f $(INSTALLED_DTB_OVERLAY_TARGET)

### DTB build template
CUSTOMER_DTB_PLATFORM := $(subst $\",,$(shell grep DTB_IMAGE_NAMES $(KERNEL_CONFIG_FILE) | sed 's/.*=//' ))
MTK_DTBIMAGE_DTS:= $(addsuffix .dts,$(addprefix $(KERNEL_DIR)/arch/$(KERNEL_TARGET_ARCH)/boot/dts/,$(CUSTOMER_DTB_PLATFORM)))

include device/mediatek/build/core/build_dtbimage.mk

CUSTOMER_DTBO_PROJECT := $(subst $\",,$(shell grep DTB_OVERLAY_IMAGE_NAMES $(KERNEL_CONFIG_FILE) | sed 's/.*=//' ))
MTK_DTBOIMAGE_DTS := $(addsuffix .dts,$(addprefix $(KERNEL_DIR)/arch/$(KERNEL_TARGET_ARCH)/boot/dts/,$(CUSTOMER_DTBO_PROJECT)))

include device/mediatek/build/core/build_dtboimage.mk

endif#TARGET_NO_KERNEL
endif#LINUX_KERNEL_VERSION
