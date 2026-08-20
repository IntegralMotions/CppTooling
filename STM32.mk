# Shared Integral Motions STM32 build tooling

PROJECT_DIR ?= $(CURDIR)
BUILD_DIR ?= $(PROJECT_DIR)/build
CMAKE ?= cube-cmake
GENERATOR ?= Ninja
TOOLCHAIN_FILE ?= $(PROJECT_DIR)/cmake/gcc-arm-none-eabi.cmake
BUILD_TYPE ?= Debug
CLANGD_FILE ?= $(PROJECT_DIR)/.clangd
CLANGD_IGNORE_HEADERS ?= stm32h7xx_hal[.]h main[.]h

ACTIVE_BUILD_DIR = $(BUILD_DIR)/$(BUILD_TYPE)

.PHONY: all configure build debug release \
        update-clangd update-clangd-debug update-clangd-release \
        clean clean-debug clean-release rebuild format tidy update help

all: debug

configure:
	$(CMAKE) \
		-DCMAKE_BUILD_TYPE="$(BUILD_TYPE)" \
		-DCMAKE_TOOLCHAIN_FILE="$(TOOLCHAIN_FILE)" \
		-DCMAKE_COMMAND="$(CMAKE)" \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
		-S "$(PROJECT_DIR)" \
		-B "$(ACTIVE_BUILD_DIR)" \
		-G "$(GENERATOR)"

build: configure update-clangd
	$(CMAKE) --build "$(ACTIVE_BUILD_DIR)" --parallel

debug:
	$(MAKE) BUILD_TYPE=Debug build

release:
	$(MAKE) BUILD_TYPE=Release build

update-clangd:
	@set -eu; \
	{ \
		printf '%s\n' \
			'CompileFlags:' \
			'  CompilationDatabase: "$(ACTIVE_BUILD_DIR)"' \
			'' \
			'Diagnostics:' \
			'  Includes:' \
			'    IgnoreHeader:'; \
		for header in $(CLANGD_IGNORE_HEADERS); do \
			printf '      - "%s"\n' "$$header"; \
		done; \
		printf '\n'; \
	} > "$(CLANGD_FILE)"
	@echo "Updated $(CLANGD_FILE) for $(BUILD_TYPE)"

update-clangd-debug:
	$(MAKE) BUILD_TYPE=Debug update-clangd

update-clangd-release:
	$(MAKE) BUILD_TYPE=Release update-clangd

clean:
	$(CMAKE) -E remove_directory "$(BUILD_DIR)"

clean-debug:
	$(CMAKE) -E remove_directory "$(BUILD_DIR)/Debug"

clean-release:
	$(CMAKE) -E remove_directory "$(BUILD_DIR)/Release"

rebuild: clean debug

format:
	@command -v clang-format >/dev/null 2>&1 || { \
		echo "Error: clang-format is not installed."; \
		exit 1; \
	}
	find "$(PROJECT_DIR)" \
		\( -path "$(BUILD_DIR)" -o -path "$(BUILD_DIR)/*" \) -prune \
		-o -type f \
		\( \
			-name '*.c' \
			-o -name '*.cc' \
			-o -name '*.cpp' \
			-o -name '*.cxx' \
			-o -name '*.h' \
			-o -name '*.hh' \
			-o -name '*.hpp' \
			-o -name '*.hxx' \
		\) \
		-exec clang-format -i {} +

tidy: configure
	@command -v run-clang-tidy >/dev/null 2>&1 || { \
		echo "Error: run-clang-tidy is not installed."; \
		exit 1; \
	}
	run-clang-tidy -p "$(ACTIVE_BUILD_DIR)"

update:
	@set -eu; \
	temp_dir=$$(mktemp -d); \
	trap 'rm -rf "$$temp_dir"' EXIT; \
	echo "Downloading STM32 tooling from $(TOOLING_REPOSITORY)@$(TOOLING_VERSION)..."; \
	curl -fsSL \
		"$(TOOLING_URL)/STM32.mk" \
		-o "$$temp_dir/STM32.mk"; \
	curl -fsSL \
		"$(TOOLING_URL)/.clang-format" \
		-o "$$temp_dir/.clang-format"; \
	curl -fsSL \
		"$(TOOLING_URL)/.clang-tidy" \
		-o "$$temp_dir/.clang-tidy"; \
	install -m 644 "$$temp_dir/STM32.mk" STM32.mk; \
	install -m 644 "$$temp_dir/.clang-format" .clang-format; \
	install -m 644 "$$temp_dir/.clang-tidy" .clang-tidy; \
	echo "STM32 tooling updated successfully."; \
	echo "Review the changes with: git diff"

help:
	@echo "Available targets:"
	@echo "  make                Build Debug and update .clangd"
	@echo "  make debug          Configure and build Debug"
	@echo "  make release        Configure and build Release"
	@echo "  make tidy           Run clang-tidy for BUILD_TYPE (default: Debug)"
	@echo "  make format         Format project C and C++ files"
	@echo "  make update-clangd  Update .clangd for BUILD_TYPE"
	@echo "  make clean          Remove all build folders"
	@echo "  make clean-debug    Remove the Debug build folder"
	@echo "  make clean-release  Remove the Release build folder"
	@echo "  make rebuild        Clean and rebuild Debug"
	@echo "  make update         Update STM32.mk and Clang configuration"
