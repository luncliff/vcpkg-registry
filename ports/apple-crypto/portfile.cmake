vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/swift-crypto
    REF 3.0.0
    SHA512 2d79147d32bfb8449726c73c8b267262cf1ddc7c18637f4168e3fd848ba71c0719b23b5683ca513260cbc537fc439e38488ae16010717303625bceb7d5edd36f
    HEAD_REF main
    PATCHES
        fix-cmake.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    GENERATOR Xcode
)
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/lib/swift_static"
    "${CURRENT_PACKAGES_DIR}/debug/lib/swift"
    "${CURRENT_PACKAGES_DIR}/lib/swift_static"
    "${CURRENT_PACKAGES_DIR}/lib/swift"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
