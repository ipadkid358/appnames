include $(THEOS)/makefiles/common.mk

TOOL_NAME = appnames
appnames_FILES = main.m
appnames_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tool.mk
