if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/pthreadpool
    REF 0e6ca13779b57d397a5ba6bfdcaa8a275bc8ea2e
    SHA512 08ed5b56474c8dd507045dbc9e0139adcbcdd782a4e4948443995fe2d4e0421a1943ed578a1de7d39c958fa87d5d1a2b064a6a0c03a73f50a2401395a2eb9a20
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
