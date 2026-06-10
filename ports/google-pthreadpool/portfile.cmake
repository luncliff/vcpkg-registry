if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/pthreadpool
    REF b8279c3e0c38b8be5377129e5aa449feaad47742
    SHA512 00e071a149a6a0d0dba1f1a05165c1eda9f876f2f8afd1e1b39dfa7104c360a3966fd31f1c718ca56b7e7a71ce4e59d7250da01b4ec4e62734a11725ed6a6ba9
    PATCHES
        fix-cmake.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DPTHREADPOOL_ALLOW_DEPRECATED_API=OFF
        -DPTHREADPOOL_BUILD_TESTS=OFF
        -DPTHREADPOOL_BUILD_BENCHMARKS=OFF
)
vcpkg_cmake_install()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
