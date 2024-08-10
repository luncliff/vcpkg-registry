# see https://github.com/bkaradzic/metal-cpp
vcpkg_download_distfile(ARCHIVE
    URLS "https://developer.apple.com/metal/cpp/files/metal-cpp_macOS14.2_iOS17.2.zip"
    FILENAME metal-cpp_macOS14.2_iOS17.2.zip
    SHA512 5d1152cda3a3b1284854f352b0e56c27c19491aa614de28db385d69e99d8b88a0186d31b373ef6db74d06dbabecf2ef8ce83a8e2d99f4bcb846ff7d58698629c
)

vcpkg_extract_source_archive_ex(
    OUT_SOURCE_PATH SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
)

file(INSTALL "${SOURCE_PATH}/Metal"
             "${SOURCE_PATH}/MetalFX"
             "${SOURCE_PATH}/Foundation"
             "${SOURCE_PATH}/QuartzCore"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include"
)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" "${SOURCE_PATH}/README.md"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
