
CFLAGS += -DNTDDI_VERSION=NTDDI_WIN7
CFLAGS += -D_KERNEL_MODE

INCLUDES +=  -I../km-shared -I../include -I../shared -I$(MINGW_INCLUDE)/ddk -I$(MINGW_INCLUDE)
PREINCLUDES = -I../mingw-headers

module: $(EXE)

include ../common.mk

$(EXE): $(OBJS)
	$(CC) -o $@ $(LDFLAGS) $^ $(LDLIBS)
