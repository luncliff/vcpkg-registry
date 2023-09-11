if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO Maratyszcza/pthreadpool
    REF 4fe0e1e183925bf8cfa6aae24237e724a96479b8
    SHA512 764d81219f2bf1f056983b5c2576f377aeef37f0f2282e74f81bfe1eac5353e175603f80a6647c96165b24ebdcb7bc2189a376e8577ce4319d82679c33750451
    PATCHES fix-cmake-uwp.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DPTHREADPOOL_BUILD_TESTS=OFF
        -DPTHREADPOOL_BUILD_BENCHMARKS=OFF
)
vcpkg_cmake_install()

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
