if(NOT VCPKG_TARGET_IS_EMSCRIPTEN)
    message(FATAL_ERROR "${PORT} is only supported on wasm32-emscripten triplet")
endif()

# The package is text-only (headers, C++/JS sources and an Emscripten port file)
set(VCPKG_BUILD_TYPE release)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/google/dawn/releases/download/v${VERSION}/emdawnwebgpu_pkg-v${VERSION}.zip"
    FILENAME "emdawnwebgpu_pkg-v${VERSION}.zip"
    SHA512 fc8ce33f1253032b9ba8e6998ca07760d87ef3f943dff40a7dffe5809d8bde4a1d32f0d982c3092122bcaf15e466437cbccb1a3b4ee1d5b3ed6ae2eff3140f12
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

# Keep the package layout as-is, so it can be used with `--use-port=share/emdawnwebgpu/emdawnwebgpu.port.py`.
# See the README.md in the package.
file(COPY "${SOURCE_PATH}/" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

# find_package(Dawn) like the upstream 'dawn' port
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/DawnConfig.cmake" DESTINATION "${CURRENT_PACKAGES_DIR}/share/Dawn")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(
    FILE_LIST
        "${SOURCE_PATH}/webgpu/src/LICENSE"
        "${SOURCE_PATH}/webgpu_cpp/LICENSE"
)
