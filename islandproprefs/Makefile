TARGET := iphone:clang:16.5:16.0
include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = IslandProPrefs
IslandProPrefs_FILES = IPRootListController.m
IslandProPrefs_BUNDLE_RESOURCE_DIRS = Resources
IslandProPrefs_FRAMEWORKS = UIKit Foundation UniformTypeIdentifiers ImageIO CoreFoundation
IslandProPrefs_PRIVATE_FRAMEWORKS = Preferences
IslandProPrefs_INSTALL_PATH = /Library/PreferenceBundles
IslandProPrefs_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/bundle.mk
