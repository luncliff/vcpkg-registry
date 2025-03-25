# see https://github.com/bkaradzic/metal-cpp
vcpkg_download_distfile(ARCHIVE
    URLS "https://developer.apple.com/metal/cpp/files/metal-cpp_${VERSION}.zip"
    FILENAME metal-cpp_${VERSION}.zip
    SHA512 6a539e7bff5eb6d16176e3565f07f18f157eb69ca7c478a5ee9b0400aed84672632dc7e8b6d8d452d49c434bbe6a04bb1579756bf3564ee6163c67b87d967513
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
