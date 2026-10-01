.PHONY: all app settings engine-smoke verify probe test install install-trial activate uninstall clean

BUILD_DIR ?= $(CURDIR)/build
APP_BUNDLE := $(BUILD_DIR)/Jitouch Modern.app

all: app

app settings:
	@BUILD_DIR="$(BUILD_DIR)" ./scripts/build-clt.sh app
	@test -d "$(APP_BUNDLE)"

# This proves that the unchanged gesture engine still compiles and links on arm64.
# Its legacy main requires a compiled MainMenu.nib, which Command Line Tools cannot
# produce; use it as a porting diagnostic, not as the installed application.
engine-smoke:
	@BUILD_DIR="$(BUILD_DIR)" ./scripts/build-clt.sh engine-smoke

verify:
	@BUILD_DIR="$(BUILD_DIR)" ./scripts/build-clt.sh verify

install: all verify
	@BUILD_DIR="$(BUILD_DIR)" ./scripts/install-personal.sh

install-trial: all verify
	@AUTO_START=0 BUILD_DIR="$(BUILD_DIR)" ./scripts/install-personal.sh

activate:
	@./scripts/activate-personal.sh

uninstall:
	@./scripts/uninstall-personal.sh

probe:
	@BUILD_DIR="$(BUILD_DIR)" ./scripts/build-clt.sh probe

test:
	@./scripts/test-settings-store.sh
	@./scripts/test-shortcut-recorder.sh
	@./scripts/test-engine-settings.sh
	@./scripts/test-close-strategy.sh
	@./scripts/test-three-finger-drag-policy.sh
	@./scripts/test-three-finger-gesture-safety.sh
	@./scripts/test-edge-volume-scrub-policy.sh
	@./scripts/test-volume-step-accumulator.sh
	@./scripts/test-command-dispatch-policy.sh
	@./scripts/test-keyboard-event.sh
	@./scripts/test-shortcut-dispatch-policy.sh
	@./scripts/test-previous-window-policy.sh
	@./scripts/test-one-fix-tap-classifier.sh
	@./scripts/test-one-fix-tap-click-suppression.sh

clean:
	@BUILD_DIR="$(BUILD_DIR)" ./scripts/build-clt.sh clean
