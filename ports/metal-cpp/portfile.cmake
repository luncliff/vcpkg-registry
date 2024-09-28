# see https://github.com/bkaradzic/metal-cpp
vcpkg_download_distfile(ARCHIVE
    URLS "https://developer.apple.com/metal/cpp/files/metal-cpp_macOS15_iOS18-beta.zip"
    FILENAME metal-cpp_macOS15_iOS18-beta.zip
    SHA512 401a38c9268a772c2586da9269e9eab42f8d5643d36b7bce07fe815c1efc56ae1fd1742513e2c5126487dd5326e25e6a503830347de17cc0c563e493dff709a4
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
