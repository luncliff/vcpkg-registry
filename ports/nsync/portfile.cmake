if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/nsync
    REF "${VERSION}"
    SHA512 af463d768c9e4bacc5796410c6d368b8ad0cc0fcbae28ec35fbe7937e7939de1ccad97f51b4940e384b677bb8fbc9963a438f7687e002613f1669ab93e459f60
    HEAD_REF master
    PATCHES
        fix-cmake.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DNSYNC_ENABLE_TESTS=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME nsync CONFIG_PATH lib/cmake/nsync DO_NOT_DELETE_PARENT_CONFIG_PATH)
vcpkg_cmake_config_fixup(PACKAGE_NAME nsync_cpp CONFIG_PATH lib/cmake/nsync_cpp)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
