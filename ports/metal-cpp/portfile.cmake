vcpkg_download_distfile(ARCHIVE
    URLS "https://developer.apple.com/metal/cpp/files/metal-cpp_macOS13_iOS16.zip"
    FILENAME metal-cpp_macOS13_iOS16.zip
    SHA512 d35133f2b8829a28129a1662f8bf0f81df9a7937cd943abc948329fcade35b5258892cdf8b134cec0d9828cb0db67a708922eab0c2f64a8367c9bbf0382e043e
)

vcpkg_extract_source_archive_ex(
    OUT_SOURCE_PATH SOURCE_PATH
    ARCHIVE ${ARCHIVE}
)

file(INSTALL ${SOURCE_PATH}/Metal       DESTINATION ${CURRENT_PACKAGES_DIR}/include)
file(INSTALL ${SOURCE_PATH}/Foundation  DESTINATION ${CURRENT_PACKAGES_DIR}/include)
file(INSTALL ${SOURCE_PATH}/QuartzCore  DESTINATION ${CURRENT_PACKAGES_DIR}/include)

file(INSTALL ${SOURCE_PATH}/LICENSE.txt DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright)
file(INSTALL ${SOURCE_PATH}/README.md   DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT})
file(INSTALL ${CURRENT_PORT_DIR}/usage  DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT})

file(INSTALL ${CURRENT_PORT_DIR}/MetalCppConfig.cmake DESTINATION ${CURRENT_PACKAGES_DIR}/share/MetalCpp)
