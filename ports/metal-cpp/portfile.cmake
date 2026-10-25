# see https://github.com/bkaradzic/metal-cpp
vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/apple/metal-cpp/archive/refs/tags/release%2Fmetal-cpp_${VERSION}.tar.gz"
    FILENAME metal-cpp_${VERSION}.tar.gz
    SHA512 377432024c4a1aabbcff85da95e260ee30a7efd6d3130b2518c329817ae2fb192885b92c700974e7761dce2658e8b8974abe9f45e684fee1f9330f15db6cb5da
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
