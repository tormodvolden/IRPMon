
LDFLAGS += -shared -nostartfiles -nostdlib
LDLIBS += -lntoskrnl -lhal

OBJS = boot-log.o data-loggers.o devext-hooks.o driver-settings.o \
       hook.o hook-handlers.o kbase.o key-record.o pnp-driver-watch.o \
       process-events.o registry-callback.o regman.o req-queue.o \
       thread-context.o value-record.o

OBJS += ../km-shared/hash_table.o
OBJS += ../km-shared/handle-table.o
OBJS += ../km-shared/multistring.o
OBJS += ../km-shared/modules.o
OBJS += ../km-shared/utils.o
OBJS += ../km-shared/allocator.o
OBJS += ../km-shared/utils-dym-array.o
OBJS += ../km-shared/string-ref-table.o
OBJS += ../km-shared/fo-context-table.o
OBJS += ../km-shared/modules.o
OBJS += ../km-shared/string-hash-table.o
OBJS += ../km-shared/process-context-table.o

OBJS += request.o

# workaround for ntstrsafe.h multiple definitions
LDFLAGS += -Wl,-allow-multiple-definition
#CFLAGS += -D__CRT__NO_INLINE

EXE = kbase.dll
$(EXE): kbase.def
LDLIBS += kbase.def

include ../common-km.mk

key-record.o: PREINCLUDES = -I../mingw-headers

request.o: PREINCLUDES = -I../mingw-headers
request.o: ../shared/request.cpp
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $^

# this one must be grabbed from somewhere else
LDLIBS += -L. -l:../fltMgr.lib
