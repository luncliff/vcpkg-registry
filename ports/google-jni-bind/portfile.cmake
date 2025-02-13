vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/jni-bind
    REF Release-1.2.0
    SHA512 ef1274b649d3cc46346a71cdf1269f5022983633feea2ec85200ea5dc7cc7fab8cac987aa3ca7514c1b8a3dcd7deea6f152b432d9d16ab230bf20bb16ff14a56
    HEAD_REF main
)

file(INSTALL "${SOURCE_PATH}/jni_bind_release.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
