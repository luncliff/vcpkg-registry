vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/jni-bind
    REF "Release-${VERSION}"
    SHA512 1c5ad5c2731a54164debe973cbcc5265185dfbe7a9217193a7869268c1384b316dc79c95918e9acc27c872de63879d686a8378ae7a7bd394795d9ce861c63a1d
    HEAD_REF main
)

file(INSTALL "${SOURCE_PATH}/jni_bind_release.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
