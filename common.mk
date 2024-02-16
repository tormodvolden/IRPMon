
# for cross-building with MinGW
CROSS = x86_64-w64-mingw32-
MINGW_INCLUDE = /usr/share/mingw-w64/include

INCLUDES += -I../include -I../shared -I$(MINGW_INCLUDE)
CPPFLAGS += $(PREINCLUDES) $(INCLUDES) -O2

CC = $(CROSS)gcc
LD = $(CROSS)ld
CXX = $(CROSS)g++

all: $(EXE)

$(EXE): $(OBJS)
	$(CXX) -o $@ $(LDFLAGS) $^ $(LDLIBS)

clean:
	rm -f $(EXE) $(OBJS) $(DELOBJS)
