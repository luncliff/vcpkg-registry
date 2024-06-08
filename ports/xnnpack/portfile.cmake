if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

# for onnxruntime, using just before https://github.com/google/XNNPACK/commit/142aceb06d509b57d02ddc2a9558ab35eacbb6fb

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/XNNPACK
    REF bed314a60a3b0cd7ea3dd0838bea4aaa2a38884e # 2024-06-08
    SHA512 27f5d8a4b5053c18b6bf75dffb4c7f8bc59a71dbbd7d0860201279d6de99b0d60595471c691ba7085354a9d202280d6f42e8262f9135f4af894c66f5288a5883
    HEAD_REF master
    PATCHES
        fix-cmake.patch
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/xnnpack-config.template.cmake" DESTINATION "${SOURCE_PATH}/cmake")

if(VCPKG_TARGET_IS_WINDOWS)
    # see https://docs.microsoft.com/en-us/cpp/intrinsics/arm64-intrinsics?view=msvc-170
    # see https://github.com/google/XNNPACK/blob/master/scripts/build-windows-arm64.cmd
    if(VCPKG_TARGET_ARCHITECTURE MATCHES "arm")
        list(APPEND PLATFORM_OPTIONS
            -DXNNPACK_ENABLE_ARM_FP16_SCALAR=OFF
            -DXNNPACK_ENABLE_ARM_BF16=OFF # `bfloat16_t` type is missing
            -DXNNPACK_ENABLE_ARM_FP16_VECTOR=ON # `__fp16` type is missing
        )
    endif()
elseif(VCPKG_TARGET_IS_ANDROID)
    # see https://github.com/google/XNNPACK/blob/master/scripts/build-android-armv7.sh
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        list(APPEND PLATFORM_OPTIONS -DXNNPACK_ENABLE_ARM_BF16=OFF)
    endif()
elseif(VCPKG_TARGET_IS_IOS)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        set(IOS_ARCH "armv7")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(IOS_ARCH "arm64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(IOS_ARCH "x86_64")
    else()
        message(FATAL_ERROR "Unexpected VCPKG_TARGET_ARCHITECTURE")
    endif()
    list(APPEND PLATFORM_OPTIONS -DIOS_ARCH=${IOS_ARCH})
endif()

set(USE_ASSEMBLY true)
if(VCPKG_TARGET_IS_WINDOWS AND (VCPKG_TARGET_ARCHITECTURE MATCHES "arm"))
    set(USE_ASSEMBLY false)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    WINDOWS_USE_MSBUILD
    OPTIONS
        ${FEATURE_OPTIONS}
        ${PLATFORM_OPTIONS}
        -DXNNPACK_USE_SYSTEM_LIBS=ON
        -DXNNPACK_ENABLE_ASSEMBLY=${USE_ASSEMBLY}
        -DXNNPACK_ENABLE_MEMOPT=ON
        -DXNNPACK_ENABLE_SPARSE=ON
        -DXNNPACK_BUILD_TESTS=OFF
        -DXNNPACK_BUILD_BENCHMARKS=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share PACKAGE_NAME xnnpack)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
file(INSTALL "${SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
