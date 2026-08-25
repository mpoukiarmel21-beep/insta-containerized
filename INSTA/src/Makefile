# Makefile — Theos build (optionnel, pour build local).
# Sur GitHub, le workflow utilise clang directement (voir workflow/build-ipa.yml).
#
# Requiert Theos installé et $THEOS défini.

TARGET := iphone:clang:16.0
ARCHS := arm64
TWEAK_NAME := Containerizer
Containerizer_FILES := Tweak.m ContainerManager.m DeviceProfile.m LocationSpoofer.m FloatingButton.m TweakLogger.m
Containerizer_FRAMEWORKS := UIKit CoreLocation MapKit
Containerizer_PRIVATE_FRAMEWORKS :=
Containerizer_LIBRARIES :=
Containerizer_CFLAGS := -fobjc-arc

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/tweak.mk

after-install::
	install.exec "killall -9 Instagram" || true
