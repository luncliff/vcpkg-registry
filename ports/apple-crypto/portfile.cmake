if(VCPKG_TARGET_IS_IOS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/swift-crypto
    REF 2.2.4
    SHA512 9b9e5e2bd038cbe8064bcbc56089219c2241bff2555abda09bc713741576e54d591a442fc6063abe2d0f78529054a7857b24179f6159b25a2447d36293951241
    HEAD_REF main
    PATCHES
        fix-cmake.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    GENERATOR Xcode
    OPTIONS
        -DBUILD_SHARED_LIBS=ON
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON
)
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/lib/swift_static"
    "${CURRENT_PACKAGES_DIR}/debug/lib/swift"
    "${CURRENT_PACKAGES_DIR}/lib/swift_static"
    "${CURRENT_PACKAGES_DIR}/lib/swift"
)

file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
