
# multi-character character constant - check libusb0.sys for similar issue

OBJS = driver.o fs-watch.o image-load.o pnp-class-watch.o um-services.o

LDFLAGS += -shared -nostartfiles -nostdlib
LDLIBS += -lntoskrnl -lhal

LDLIBS += -L../kbase -l:kbase.dll

EXE = irpmndrv.sys

include ../common-km.mk

# this one must be grabbed from somewhere else
LDLIBS += -l:../fltMgr.lib
