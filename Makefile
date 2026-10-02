SDK_ROOT      := $(HOME)/Library/Application Support/Garmin/ConnectIQ
SDK_HOME      ?= $(shell cat "$(SDK_ROOT)/current-sdk.cfg")
DEVELOPER_KEY ?= $(HOME)/.config/garmin-connectiq/developer_key.der
DEVICE        ?= fr165

APP := StarterFace
PRG := bin/$(APP).prg
IQ  := bin/$(APP).iq
DEVICE_PRG := bin/device/$(APP).prg
PUSH := bin/garmin_push
SRC := manifest.xml monkey.jungle $(shell find source resources -type f)

.PHONY: build sim run install release clean

# Debug build for one device (make build DEVICE=fr165m)
build: $(PRG)

$(PRG): $(SRC)
	"$(SDK_HOME)/bin/monkeyc" -f monkey.jungle -d $(DEVICE) -o $(PRG) -y "$(DEVELOPER_KEY)" -w -l 2

# Start the Connect IQ simulator
sim:
	"$(SDK_HOME)/bin/connectiq"

# Build and load the watch face into the running simulator
run: build
	"$(SDK_HOME)/bin/monkeydo" $(PRG) $(DEVICE)

# Copy a release build onto a watch connected over USB (needs: brew install libmtp)
install: $(DEVICE_PRG) $(PUSH)
	$(PUSH) $(DEVICE_PRG)

$(DEVICE_PRG): $(SRC)
	"$(SDK_HOME)/bin/monkeyc" -f monkey.jungle -d $(DEVICE) -r -o $(DEVICE_PRG) -y "$(DEVELOPER_KEY)" -w -l 2

$(PUSH): tools/garmin_push.c
	mkdir -p bin
	$(CC) $< -o $@ $(shell pkg-config --cflags --libs libmtp)

# Store package (.iq) for all devices in manifest.xml
release:
	"$(SDK_HOME)/bin/monkeyc" -f monkey.jungle -e -r -o $(IQ) -y "$(DEVELOPER_KEY)" -w -l 2

clean:
	rm -rf bin
