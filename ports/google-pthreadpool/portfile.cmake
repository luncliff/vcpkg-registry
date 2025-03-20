if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/pthreadpool
    REF b92447772365661680f486e39a91dfe6675adafc
    SHA512 d586602f46c4fe1a6fa886846f6a1683570d9d9c0f98f83ee587ec9b03168ae299e7bb80b87e5f91aeed2ee6563649a2054c5e94c2701a607eb43b887465b1c6
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
