if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/nsync
    REF "${VERSION}"
    SHA512 2706501a45396172b5b39716ba29ea3ef3d8f5fdd9b0e0b22e6217d93ed64eb3cce4e5610818867ae43ce5fc677581932e67507425299e8b6a8353369eb79ecf
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
