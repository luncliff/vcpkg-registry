# This port provides Emdawnwebgpu - Dawn's implementation of webgpu.h for Emscripten
# It supports wasm32-emscripten target only

# Check that we're building for Emscripten
if(NOT VCPKG_TARGET_IS_EMSCRIPTEN)
    message(FATAL_ERROR "emdawnwebgpu is only supported on wasm32-emscripten triplet")
endif()

# Download the emdawnwebgpu package from GitHub releases
vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/google/dawn/releases/download/v${VERSION}/emdawnwebgpu_pkg-v${VERSION}.zip"
    FILENAME "emdawnwebgpu_pkg-v${VERSION}.zip"
    SHA512 ffc9b905082fb5f7da18665b4596a94623489dff283a35b2a672912ff68418e51209ade07c65f6c946e63e9dad543428848b471148893b3d096706db9272549c
)

# Extract the archive
vcpkg_extract_source_archive_ex(
    OUT_SOURCE_PATH SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    NO_REMOVE_ONE_LEVEL
)

# Install the headers
file(INSTALL "${SOURCE_PATH}/emdawnwebgpu_pkg/webgpu/include/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
    FILES_MATCHING PATTERN "*.h"
)

file(INSTALL "${SOURCE_PATH}/emdawnwebgpu_pkg/webgpu_cpp/include/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
    FILES_MATCHING PATTERN "*.h"
)

# Install the source files (JavaScript and C++ implementation)
file(INSTALL "${SOURCE_PATH}/emdawnwebgpu_pkg/webgpu/src/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/src"
)

# Install the port file for Emscripten integration
file(INSTALL "${SOURCE_PATH}/emdawnwebgpu_pkg/emdawnwebgpu.port.py"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

# Install README
file(INSTALL "${SOURCE_PATH}/emdawnwebgpu_pkg/README.md"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

# Install version info
file(INSTALL "${SOURCE_PATH}/emdawnwebgpu_pkg/VERSION.txt"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

# Install the license files
# The package includes two licenses:
# - webgpu/src/LICENSE: MIT/NCSA (from Emscripten project)
# - webgpu_cpp/LICENSE: Apache-2.0 (from Dawn project)
vcpkg_install_copyright(
    FILE_LIST 
        "${SOURCE_PATH}/emdawnwebgpu_pkg/webgpu/src/LICENSE"
        "${SOURCE_PATH}/emdawnwebgpu_pkg/webgpu_cpp/LICENSE"
)
