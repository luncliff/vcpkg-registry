if(VCPKG_TARGET_IS_IOS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/swift-crypto
    REF 2.5.0
    SHA512 4a259a1d5827467afbf0d8ba36b680748065f58bcaba8a03fe33fa729de58d36280aaf99d5c198207a310a7ad4edd836061f8a9ebdab0622ba3a128076b90576
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
