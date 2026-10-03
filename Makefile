ARCHS = arm64e
TARGET = iphone:clang:16.5:15.0
THEOS_PACKAGE_SCHEME = roothide
FINALPACKAGE = 1
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LockColorSwitch

LockColorSwitch_FILES = Tweak.x
LockColorSwitch_CFLAGS = -fobjc-arc
LockColorSwitch_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
