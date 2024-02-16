
LDFLAGS += -shared -nostartfiles -nostdlib
LDLIBS += -lntoskrnl -lhal

OBJS = allocator.o fo-context-table.o handle-table.o hash_table.o modules.o \
       multistring.o process-context-table.o string-hash-table.o \
       string-ref-table.o utils.o utils-dym-array.o

OBJS += request.o
OBJS += thread-context.o

EXE = km-shared.dll

include ../common-km.mk

request.o: PREINCLUDES = -I../mingw-headers
request.o: ../shared/request.cpp
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $^

thread-context.o: ../kbase/thread-context.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c -o $@ $^
