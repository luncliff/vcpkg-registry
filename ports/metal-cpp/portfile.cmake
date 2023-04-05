vcpkg_download_distfile(ARCHIVE
    URLS "https://developer.apple.com/metal/cpp/files/metal-cpp_macOS13.3_iOS16.4.zip"
    FILENAME metal-cpp_macOS13.3_iOS16.4.zip
    SHA512 27da1cb31407bb6dae25d78dcbe1480e408968eb53983b1e616f9d609f22bfe4f91020c2968f855f55a414086b264259b7454cad33a239b946749afbcf3d770a
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
