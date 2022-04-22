if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/XNNPACK
    REF 50c2d55a379b37ed815accaa565f9e687e2e3f00 # 2022-04-08
    SHA512 b35c2afe4611d1b768f592fd5dec39f238b312ef6a73dfac611b83230e700d77144ac6d7c281f19b7365679525c34d295f39500513daeb25a06fb4a2389c823c
    HEAD_REF master
    PATCHES
        change-allowed-systems.patch
        use-packages.patch
        support-package.patch
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/xnnpack-config.cmake.in" DESTINATION "${SOURCE_PATH}/cmake")

if(VCPKG_TARGET_IS_IOS)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        set(IOS_ARCH "armv7")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(IOS_ARCH "arm64")
    endif()
    list(APPEND PLATFORM_OPTIONS -DIOS_ARCH=${IOS_ARCH})
endif()

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        -DXNNPACK_USE_SYSTEM_LIBS=ON
        -DXNNPACK_ENABLE_ASSEMBLY=ON
        -DXNNPACK_ENABLE_MEMOPT=ON
        -DXNNPACK_ENABLE_SPARSE=ON
        -DXNNPACK_BUILD_TESTS=OFF
        -DXNNPACK_BUILD_BENCHMARKS=OFF
        ${PLATFORM_OPTIONS}
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share)

file(INSTALL ${SOURCE_PATH}/LICENSE
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright
)
file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include
                    ${CURRENT_PACKAGES_DIR}/debug/bin
                    ${CURRENT_PACKAGES_DIR}/debug/share
)
