# see https://github.com/bkaradzic/metal-cpp
vcpkg_download_distfile(ARCHIVE
    URLS "https://developer.apple.com/metal/cpp/files/metal-cpp_${VERSION}.zip"
    FILENAME metal-cpp_${VERSION}.zip
    SHA512 5b24953eb70f128062faca8f0a0130fcb6e0b837427c75d32930f6a4146b87413b5c4195cffbbbf13024f878ea2883817113df54550885daa90238ab372ffe4c
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

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage"
             "${SOURCE_PATH}/README.md"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
