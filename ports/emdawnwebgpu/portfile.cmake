# This port provides Emdawnwebgpu - Dawn's implementation of webgpu.h for Emscripten
# It supports wasm32-emscripten target only

# Check that we're building for Emscripten
if(NOT VCPKG_TARGET_IS_EMSCRIPTEN)
    message(FATAL_ERROR "emdawnwebgpu is only supported on wasm32-emscripten triplet")
endif()

# No build step required
set(VCPKG_BUILD_TYPE release)

# Download the emdawnwebgpu package from GitHub releases
vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/google/dawn/releases/download/v${VERSION}/emdawnwebgpu_pkg-v${VERSION}.zip"
    FILENAME "emdawnwebgpu_pkg-v${VERSION}.zip"
    SHA512 fc8ce33f1253032b9ba8e6998ca07760d87ef3f943dff40a7dffe5809d8bde4a1d32f0d982c3092122bcaf15e466437cbccb1a3b4ee1d5b3ed6ae2eff3140f12
)
vcpkg_extract_source_archive_ex(
    OUT_SOURCE_PATH SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    PATCHES
        fix-pkg-path.patch # adjust to use share/${PORT}/src, not share/dawn/src.
)

# Install the headers
file(INSTALL "${SOURCE_PATH}/webgpu/include/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
    FILES_MATCHING PATTERN "*.h"
)

file(INSTALL "${SOURCE_PATH}/webgpu_cpp/include/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
    FILES_MATCHING PATTERN "*.h"
)

# Install README
file(INSTALL "${SOURCE_PATH}/README.md"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

# Install version info
file(INSTALL "${SOURCE_PATH}/VERSION.txt"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

# Here, Use "Dawn" instead of "emdawnwebgpu" to match vcpkg upstream 'dawn' port
# Install the source files (JavaScript and C++ implementation)
file(INSTALL "${SOURCE_PATH}/webgpu/src/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/Dawn/src"
)

# Install the port file for Emscripten integration
# Install DawnConfig.cmake like vcpkg upstream
file(INSTALL "${SOURCE_PATH}/emdawnwebgpu.port.py"
             "${CMAKE_CURRENT_LIST_DIR}/DawnConfig.cmake"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/Dawn"
)

# Install the license files
# The package includes two licenses:
# - webgpu/src/LICENSE: MIT/NCSA (from Emscripten project)
# - webgpu_cpp/LICENSE: Apache-2.0 (from Dawn project)
vcpkg_install_copyright(
    FILE_LIST 
        "${SOURCE_PATH}/webgpu/src/LICENSE"
        "${SOURCE_PATH}/webgpu_cpp/LICENSE"
)
