vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO Maratyszcza/fp16
    REF 3d2de1816307bac63c16a297e8c4dc501b4076df
    SHA512 90e748696091d44ef18c39b238850c614284799ef8f8e734d6e553112c60840110e14e5058d60804fab45edf75fab91d0a36fcc4fb7ec1a9ddb9dfd2be2135c2
    PATCHES
        fix-bitcast.patch
)

file(INSTALL "${SOURCE_PATH}/include/fp16.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

# https://learn.microsoft.com/en-us/cpp/intrinsics/
file(GLOB HEADERS "${SOURCE_PATH}/include/fp16/*.h")
file(INSTALL ${HEADERS} DESTINATION "${CURRENT_PACKAGES_DIR}/include/fp16")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
