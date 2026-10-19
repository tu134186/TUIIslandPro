TARGET := iphone:clang:latest:16.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME := rootless
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IslandPro
IslandPro_FILES = Tweak.xm
IslandPro_CFLAGS = -fobjc-arc
IslandPro_FRAMEWORKS = UIKit Foundation QuartzCore
include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += islandproprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
